package de.nglab.sentinel.navi

import android.location.Location
import com.stadiamaps.ferrostar.core.FerrostarCore
import com.stadiamaps.ferrostar.core.NavigationState
import com.stadiamaps.ferrostar.core.http.HttpClientProvider
import com.stadiamaps.ferrostar.core.http.IResponse
import com.stadiamaps.ferrostar.core.http.OkHttpClientProvider.Companion.toOkhttp3Request
import com.stadiamaps.ferrostar.core.location.NavigationLocationProviding
import com.stadiamaps.ferrostar.core.location.toUserLocation
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.navi.Anfrageoptionen
import de.nglab.sentinel.kern.navi.Fahrspur
import de.nglab.sentinel.kern.navi.Fortschritt
import de.nglab.sentinel.kern.navi.Nachfuehrung
import de.nglab.sentinel.kern.navi.Naviziel
import de.nglab.sentinel.kern.navi.Navizielaufloesung
import de.nglab.sentinel.kern.navi.Routenanfrage
import de.nglab.sentinel.kern.navi.Routeninfo
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import uniffi.ferrostar.CourseFiltering
import uniffi.ferrostar.GeographicCoordinate
import uniffi.ferrostar.NavigationControllerConfig
import uniffi.ferrostar.RouteDeviationTracking
import uniffi.ferrostar.RouteRequest
import uniffi.ferrostar.TripState
import uniffi.ferrostar.Waypoint
import uniffi.ferrostar.WaypointAdvanceMode
import uniffi.ferrostar.WaypointKind
import uniffi.ferrostar.WellKnownRouteProvider
import uniffi.ferrostar.stepAdvanceDistanceEntryAndExit
import uniffi.ferrostar.stepAdvanceDistanceToEndOfStep
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.time.Duration.Companion.seconds

/** Zustand der Navigation für die Oberfläche (gleich aufgebaut wie auf iOS). */
data class Navistand(
    val ziel: Naviziel,
    val titel: String = "",
    val fortschritt: Fortschritt? = null,
    val route: List<GeoPunkt> = emptyList(),
    /** Eigener Standort, auf die Route gelegt (ohne GPS-Zittern neben der Straße). */
    val aufRoute: Location? = null,
    val info: Routeninfo = Routeninfo(),
    val rechnet: Boolean = false,
    val fehler: String? = null,
    /** Tempolimit an der eigenen Position (km/h), falls bekannt. */
    val tempolimit: Int? = null,
)

/**
 * Navigation mit dem Ferrostar-Kern: Er legt den Standort auf die Route, erkennt Abweichungen, berechnet neu und schaltet
 * die Hinweise weiter. Routen kommen vom eigenen Server; Zielauflösung, Anfrage und Anzeige stehen im gemeinsamen Kern.
 * Sprachansagen sind bewusst stumm.
 */
class Navigator(
    private val server: () -> String?,
    private val token: () -> String?,
    private val standorte: SharedFlow<Location>,
) {
    private val _stand = MutableStateFlow<Navistand?>(null)
    val stand: StateFlow<Navistand?> = _stand.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val http = OkHttpClient.Builder().callTimeout(20, TimeUnit.SECONDS).build()
    private val nachfuehrung = Nachfuehrung()
    private val vorlauf = de.nglab.sentinel.kern.navi.Vorlaufplaner()
    private val tempolimit = de.nglab.sentinel.kern.navi.Tempolimitabfrage()
    /** Serverzugriff für Straßenverzeichnis (Vorlauf, Tempolimit). */
    var api: () -> de.nglab.sentinel.kern.netz.Api? = { null }
    private var schleife: Job? = null
    private var beobachter: Job? = null
    private var kern: FerrostarCore? = null
    @Volatile private var optionen = Anfrageoptionen(sonderrechte = false, zuFuss = false)
    @Volatile private var info = Routeninfo()

    /** Gleiche Einstellungen wie auf iOS. */
    private val konfiguration
        get() = NavigationControllerConfig(
            WaypointAdvanceMode.WaypointWithinRange(30.0),
            stepAdvanceDistanceEntryAndExit(25u, 5u, 32u),
            stepAdvanceDistanceToEndOfStep(20u, 32u),
            // Ab 30 m neben der Route gilt man als abgewichen; geprüft bis zu einer GPS-Ungenauigkeit von 50 m.
            RouteDeviationTracking.StaticThreshold(50u, 30.0),
            CourseFiltering.SNAP_TO_ROUTE,
        )

    private val ortsquelle = object : NavigationLocationProviding {
        override suspend fun lastLocation(): Location? = standorte.replayCache.lastOrNull()
        override fun locationUpdates(intervalMillis: Long): Flow<Location> = standorte
    }

    /** Leitet die Anfrage an den eigenen Server, ergänzt um Sonderrechte usw., und merkt sich dessen Rückmeldung. */
    private val netz = object : HttpClientProvider {
        override suspend fun call(request: RouteRequest): IResponse {
            var anfrage = request.toOkhttp3Request()
            if (request is RouteRequest.HttpPost) {
                val body = Routenanfrage.anpassen(request.body.decodeToString(), optionen)
                anfrage = anfrage.newBuilder().post(body.toRequestBody()).header("content-type", "application/json").build()
            }
            token()?.let { anfrage = anfrage.newBuilder().header("Authorization", "Bearer $it").build() }
            val antwort = http.newCall(anfrage).warten()
            info = Routeninfo.ausKopfzeilen { antwort.header(it) }
            val bytes = antwort.body.bytes()
            val ok = antwort.isSuccessful
            val code = antwort.code
            antwort.close()
            return object : IResponse {
                override val isSuccessful = ok
                override val code = code
                override fun bodyBytes() = bytes
            }
        }
    }

    private fun kernHolen(): FerrostarCore? {
        kern?.let { return it }
        val s = server() ?: return null
        val k = FerrostarCore(
            WellKnownRouteProvider.Valhalla(Routenanfrage.adresse(s), "auto", null),
            netz, ortsquelle, konfiguration,
        )
        // Kurz nach dem Start schwankt der Standort noch; nicht bei jedem Ausreißer neu rechnen.
        k.minimumTimeBeforeRecalculation = 8.seconds
        k.minimumMovementBeforeRecalculation = 30.0
        kern = k
        beobachter = scope.launch { k.state.collect { uebernehmen(it) } }
        return k
    }

    /** Navigation starten; `stand` liefert jeweils den aktuellen Lagestand (bewegte Ziele werden nachgeführt). */
    fun starten(ziel: Naviziel, sonderrechte: Boolean, zuFuss: Boolean, stand: () -> LageStand) {
        stoppen()
        _stand.value = Navistand(ziel)
        nachfuehrung.zuruecksetzen()
        vorlauf.zuruecksetzen()
        tempolimit.zuruecksetzen()
        schleife = scope.launch {
            while (isActive) {
                nachfuehren(ziel, sonderrechte, zuFuss, stand())
                delay(Nachfuehrung.TAKT_MS)
            }
        }
    }

    fun stoppen() {
        schleife?.cancel()
        schleife = null
        kern?.stopNavigation()
        _stand.value = null
    }

    private suspend fun nachfuehren(ziel: Naviziel, sonderrechte: Boolean, zuFuss: Boolean, lage: LageStand) {
        val jetzt = System.currentTimeMillis()
        // Tempolimit an der eigenen Position (nicht zu Fuß)
        if (!zuFuss) standorte.replayCache.lastOrNull()?.let { l ->
            api()?.let { a -> if (tempolimit.aktualisieren(a, GeoPunkt(l.latitude, l.longitude), jetzt)) _stand.value = _stand.value?.copy(tempolimit = tempolimit.kmh) }
        }
        val aufgeloest = Navizielaufloesung.aufloesenMitVorlauf(ziel, lage, jetzt, vorlauf, api())
        val ort = aufgeloest?.first
        if (ort == null) {
            _stand.value = _stand.value?.copy(fehler = Navizielaufloesung.fehlertext(ziel))
            return
        }
        _stand.value = _stand.value?.copy(titel = ort.titel)
        if (_stand.value?.rechnet == true || !nachfuehrung.faellig(ort.punkt, jetzt)) return
        val k = kernHolen() ?: run {
            _stand.value = _stand.value?.copy(fehler = "Navigation ist ohne Serververbindung nicht verfügbar.")
            return
        }
        val start = standorte.replayCache.lastOrNull() ?: run {
            _stand.value = _stand.value?.copy(fehler = "Eigener Standort unbekannt.")
            return
        }
        optionen = Anfrageoptionen(sonderrechte = sonderrechte, zuFuss = zuFuss, zielstrasse = ort.strasse, parallel = aufgeloest.second)
        nachfuehrung.gerechnet(ort.punkt, jetzt)
        _stand.value = _stand.value?.copy(rechnet = true)
        try {
            val routen = k.getRoutes(start.toUserLocation(), listOf(Waypoint(GeographicCoordinate(ort.punkt.lat, ort.punkt.lon), WaypointKind.BREAK, null)))
            if (_stand.value?.ziel != ziel) return
            val erste = routen.firstOrNull() ?: throw IllegalStateException("Keine Route")
            k.startNavigation(erste, konfiguration)
            _stand.value = _stand.value?.copy(fehler = null, info = info, route = erste.geometry.map { GeoPunkt(it.lat, it.lng) })
        } catch (e: Exception) {
            nachfuehrung.fehlgeschlagen()
            _stand.value = _stand.value?.copy(fehler = if (sonderrechte) "Keine Route mit Sonderrechten verfügbar." else "Route konnte nicht berechnet werden.")
        } finally {
            _stand.value = _stand.value?.copy(rechnet = false)
        }
    }

    private fun uebernehmen(n: NavigationState) {
        val aktuell = _stand.value ?: return
        val route = n.routeGeometry.map { GeoPunkt(it.lat, it.lng) }.ifEmpty { aktuell.route }
        when (val t = n.tripState) {
            is TripState.Navigating -> {
                val primaer = t.visualInstruction?.primaryContent
                val naechster = t.remainingSteps.drop(1).firstOrNull()
                val naechsteAnzeige = naechster?.visualInstructions?.firstOrNull()?.primaryContent
                _stand.value = aktuell.copy(
                    route = route,
                    aufRoute = t.snappedUserLocation.let { u ->
                        Location("ferrostar").apply {
                            latitude = u.coordinates.lat
                            longitude = u.coordinates.lng
                            u.courseOverGround?.let { bearing = it.degrees.toFloat() }
                            u.speed?.let { speed = it.value.toFloat() }
                        }
                    },
                    info = info,
                    fortschritt = Fortschritt.aus(
                        anweisung = primaer?.text ?: t.remainingSteps.firstOrNull()?.instruction,
                        art = primaer?.maneuverType?.name, richtung = primaer?.maneuverModifier?.name,
                        bisManoever = t.progress.distanceToNextManeuver,
                        danach = naechsteAnzeige?.text ?: naechster?.instruction,
                        danachArt = naechsteAnzeige?.maneuverType?.name, danachRichtung = naechsteAnzeige?.maneuverModifier?.name,
                        restMeter = t.progress.distanceRemaining, restSekunden = t.progress.durationRemaining,
                        faktor = info.verkehrsfaktor,
                        spuren = primaer?.laneInfo.orEmpty().map { Fahrspur(it.directions, it.active) },
                    ),
                    rechnet = n.isCalculatingNewRoute || aktuell.rechnet,
                )
            }
            is TripState.Complete -> _stand.value = aktuell.copy(route = route, fortschritt = Fortschritt.angekommenStand)
            is TripState.Idle -> Unit
        }
    }
}

/** OkHttp-Aufruf als unterbrechbare Funktion. */
private suspend fun Call.warten(): Response = suspendCancellableCoroutine { f ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) = f.resume(response)
        override fun onFailure(call: Call, e: java.io.IOException) = f.resumeWithException(e)
    })
    f.invokeOnCancellation { cancel() }
}
