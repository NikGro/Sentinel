package de.nglab.sentinel.karte

import android.graphics.RectF
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.kern.karte.Anheftung
import de.nglab.sentinel.kern.karte.Kamerafuehrung
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Platzierung
import de.nglab.sentinel.kern.navi.Routenrest
import de.nglab.sentinel.kern.karte.Quellen
import de.nglab.sentinel.kern.karte.Szene
import de.nglab.sentinel.kern.modell.GeoPunkt
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.sources.GeoJsonSource

private const val LEER = """{"type":"FeatureCollection","features":[]}"""

/** Antippbare Ebenen des gemeinsamen Stils, die oberste zuerst. */
private val ANTIPPBAR = arrayOf(
    "lage-cluster", "lage-symbole", "lage-symbole-zeichen", "lage-oepnv-fahrzeuge", "lage-halte",
    "lage-linien", "lage-oepnv-kante", "lage-spuren", "lage-standortspur", "lage-flaechen",
)

/** Steuerung der Karte von außen (Kamera, Verkehrslage); gefüllt, sobald die Karte bereit ist. */
class KartenSteuerung {
    internal var karte: MapLibreMap? = null
    val fuehrung = Kamerafuehrung()
    /** Angeheftet (für den Standort-/Kompassknopf). */
    var anheftung by mutableStateOf(Anheftung.Frei)
        internal set
    internal var gesteAktiv = false

    /** Navigation: nah, gekippt, in Fahrtrichtung; `null` löst die Kopplung wieder (Ende der Navigation). */
    fun navigation(ort: GeoPunkt?) {
        if (ort == null) {
            fuehrung.loesen()
            anheftung = fuehrung.anheftung
            return
        }
        fuehrung.anheften(Anheftung.Navigation, ort.lat)
        anheftung = fuehrung.anheftung
        folgen(ort, null, null, null, sofort = true)
    }

    /** Standort-/Kompassknopf: heftet an (Fahrtrichtung), erneut getippt Norden oben, dann wieder Fahrtrichtung. */
    fun anheftenUmschalten(ort: GeoPunkt?) {
        val naechste = if (fuehrung.anheftung == Anheftung.Richtung) Anheftung.Norden else Anheftung.Richtung
        fuehrung.anheften(naechste, ort?.lat ?: 53.5)
        anheftung = fuehrung.anheftung
        if (ort != null) folgen(ort, null, null, null, sofort = true)
    }

    internal fun folgen(ort: GeoPunkt, tempo: Double?, kurs: Double?, kompass: Double?, sofort: Boolean = false) {
        val k = karte ?: return
        if (gesteAktiv) return
        val ziel = fuehrung.ziel(ort, tempo, kurs, kompass) ?: return
        val position = CameraPosition.Builder().target(LatLng(ziel.mitte.lat, ziel.mitte.lon)).zoom(ziel.zoom).bearing(ziel.richtung).tilt(ziel.neigung).build()
        k.easeCamera(CameraUpdateFactory.newCameraPosition(position), if (sofort) 600 else Kamerafuehrung.FAHRT_MS.toInt(), false)
    }

    fun zeigen(p: GeoPunkt, zoom: Double = 16.0) {
        karte?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(p.lat, p.lon), zoom), 600)
    }

    fun verkehr(an: Boolean) {
        val style = karte?.style ?: return
        for (id in listOf("verkehr-fluss", "verkehr-sperrung", "verkehr-meldung-punkt")) {
            style.getLayer(id)?.setProperties(org.maplibre.android.style.layers.PropertyFactory.visibility(if (an) "visible" else "none"))
        }
    }

    /** Hebt einen Ort hervor (Suchtreffer, gedrückter Ort); `null` entfernt die Markierung. */
    fun markieren(p: GeoPunkt?) {
        val quelle = karte?.style?.getSourceAs<GeoJsonSource>(Quellen.AUSWAHL) ?: return
        quelle.setGeoJson(if (p == null) LEER else
            """{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[${p.lon},${p.lat}]},"properties":{}}]}""")
    }

    fun norden() {
        karte?.animateCamera(CameraUpdateFactory.bearingTo(0.0), 400)
    }
}

/**
 * Lagekarte mit der eigenen Karten-Engine (MapLibre) und dem gemeinsamen Stil des Servers. Die Daten kommen aus der
 * Karten-Szene des Kerns; Antippen fragt die Engine, welches Objekt dort gezeichnet ist (eine Stelle für alles).
 */
@Composable
fun LageKarte(
    modell: AppModell,
    steuerung: KartenSteuerung,
    modifier: Modifier = Modifier,
    platzierung: Platzierung? = null,
    entwurfRadius: Double? = null,
    beiTipp: (GeoPunkt) -> Unit = {},
    beiAuswahl: (KartenObjekt) -> Unit,
) {
    // Aktuelle Werte für die einmal angelegten Listener der Karte.
    val platziert by rememberUpdatedState(platzierung != null)
    val tipp by rememberUpdatedState(beiTipp)
    val auswahl by rememberUpdatedState(beiAuswahl)
    val kontext = LocalContext.current
    val lebenszyklus = LocalLifecycleOwner.current.lifecycle
    val dunkel = isSystemInDarkTheme()
    val stand by modell.lage.stand.collectAsStateWithLifecycle()
    val ort by modell.ort.collectAsStateWithLifecycle()
    val server = modell.zugang.value?.server ?: return
    var style by remember { mutableStateOf<Style?>(null) }
    var zoom by remember { mutableStateOf(14.0) }
    val szene = remember { Szene() }

    val ansicht = remember {
        MapView(kontext).apply {
            onCreate(null)
            getMapAsync { karte ->
                steuerung.karte = karte
                karte.uiSettings.apply {
                    isCompassEnabled = false
                    isLogoEnabled = false
                    isAttributionEnabled = true
                    isTiltGesturesEnabled = true
                }
                val start = modell.ort.value?.let { LatLng(it.lat, it.lon) } ?: LatLng(53.5511, 9.9937)
                karte.cameraPosition = CameraPosition.Builder().target(start).zoom(14.5).tilt(0.0).build()
                karte.setStyle(Style.Builder().fromUri("$server/karte/stil/${if (dunkel) "dunkel" else "hell"}.json")) { s -> style = s }
                addOnStyleImageMissingListener { name -> karte.style?.let { Kartenbilder.anlegen(it, name) } }
                karte.addOnCameraIdleListener { zoom = karte.cameraPosition.zoom }
                // Gesten: Verschieben bzw. Herausdrehen löst die Kopplung, Zoomen und Kippen setzen nur Sollwerte.
                // Während einer Geste setzt die Führung die Kamera nie (sonst würde die Geste abgebrochen).
                var startMitte: LatLng? = null
                var startRichtung = 0.0
                karte.addOnMoveListener(object : MapLibreMap.OnMoveListener {
                    override fun onMoveBegin(detector: org.maplibre.android.gestures.MoveGestureDetector) {
                        steuerung.gesteAktiv = true
                        startMitte = karte.cameraPosition.target
                    }
                    override fun onMove(detector: org.maplibre.android.gestures.MoveGestureDetector) {
                        val start = startMitte ?: return
                        val p = karte.projection.toScreenLocation(start)
                        val mitte = android.graphics.PointF(width / 2f, height / 2f)
                        val strecke = kotlin.math.hypot((p.x - mitte.x).toDouble(), (p.y - mitte.y).toDouble()) / resources.displayMetrics.density
                        if (steuerung.fuehrung.geste(strecke, 0.0)) steuerung.anheftung = Anheftung.Frei
                    }
                    override fun onMoveEnd(detector: org.maplibre.android.gestures.MoveGestureDetector) {
                        steuerung.gesteAktiv = false
                    }
                })
                karte.addOnRotateListener(object : MapLibreMap.OnRotateListener {
                    override fun onRotateBegin(detector: org.maplibre.android.gestures.RotateGestureDetector) {
                        steuerung.gesteAktiv = true
                        startRichtung = karte.cameraPosition.bearing
                    }
                    override fun onRotate(detector: org.maplibre.android.gestures.RotateGestureDetector) {
                        if (steuerung.fuehrung.geste(0.0, karte.cameraPosition.bearing - startRichtung)) steuerung.anheftung = Anheftung.Frei
                    }
                    override fun onRotateEnd(detector: org.maplibre.android.gestures.RotateGestureDetector) {
                        steuerung.gesteAktiv = false
                    }
                })
                karte.addOnScaleListener(object : MapLibreMap.OnScaleListener {
                    override fun onScaleBegin(detector: org.maplibre.android.gestures.StandardScaleGestureDetector) { steuerung.gesteAktiv = true }
                    override fun onScale(detector: org.maplibre.android.gestures.StandardScaleGestureDetector) {}
                    override fun onScaleEnd(detector: org.maplibre.android.gestures.StandardScaleGestureDetector) {
                        steuerung.gesteAktiv = false
                        steuerung.fuehrung.nutzerZoom(karte.cameraPosition.zoom, karte.cameraPosition.tilt)
                    }
                })
                karte.addOnShoveListener(object : MapLibreMap.OnShoveListener {
                    override fun onShoveBegin(detector: org.maplibre.android.gestures.ShoveGestureDetector) { steuerung.gesteAktiv = true }
                    override fun onShove(detector: org.maplibre.android.gestures.ShoveGestureDetector) {}
                    override fun onShoveEnd(detector: org.maplibre.android.gestures.ShoveGestureDetector) {
                        steuerung.gesteAktiv = false
                        steuerung.fuehrung.nutzerZoom(karte.cameraPosition.zoom, karte.cameraPosition.tilt)
                    }
                })
                karte.addOnMapClickListener { lage ->
                    // Platzierungsmodus: jeder Tipp setzt einen Punkt, nichts wird ausgewählt.
                    if (platziert) {
                        tipp(GeoPunkt(lage.latitude, lage.longitude))
                        return@addOnMapClickListener true
                    }
                    val p = karte.projection.toScreenLocation(lage)
                    val r = 24f * resources.displayMetrics.density
                    val treffer = karte.queryRenderedFeatures(RectF(p.x - r, p.y - r, p.x + r, p.y + r), *ANTIPPBAR)
                    val erster = treffer.firstOrNull { it.hasProperty("id") || it.hasProperty("point_count") }
                    when {
                        erster == null -> false
                        erster.hasProperty("point_count") -> {
                            karte.animateCamera(CameraUpdateFactory.newLatLngZoom(lage, karte.cameraPosition.zoom + 2), 500)
                            true
                        }
                        else -> {
                            KartenObjekt.von(erster.getStringProperty("id"))?.let(auswahl)
                            true
                        }
                    }
                }
            }
        }
    }

    // Lebenszyklus der Kartenansicht an die Aktivität koppeln.
    DisposableEffect(lebenszyklus) {
        val beobachter = LifecycleEventObserver { _, e ->
            when (e) {
                Lifecycle.Event.ON_START -> ansicht.onStart()
                Lifecycle.Event.ON_RESUME -> ansicht.onResume()
                Lifecycle.Event.ON_PAUSE -> ansicht.onPause()
                Lifecycle.Event.ON_STOP -> ansicht.onStop()
                else -> Unit
            }
        }
        lebenszyklus.addObserver(beobachter)
        onDispose {
            lebenszyklus.removeObserver(beobachter)
            steuerung.karte = null
            ansicht.onDestroy()
        }
    }

    // Lage → Datenquellen (bei jeder Änderung des Stands und beim Zoomen für das Auffächern).
    LaunchedEffect(style, stand, zoom) {
        val s = style ?: return@LaunchedEffect
        val jetzt = System.currentTimeMillis()
        for ((id, json) in szene.aufbauen(stand, jetzt, zoom = zoom)) s.getSourceAs<GeoJsonSource>(id)?.setGeoJson(json)
    }

    // Entwurf im Platzierungsmodus (gelbe Vorschau)
    LaunchedEffect(style, platzierung, entwurfRadius) {
        val s = style ?: return@LaunchedEffect
        s.getSourceAs<GeoJsonSource>(Quellen.ENTWURF)?.setGeoJson(platzierung?.vorschau(entwurfRadius) ?: LEER)
    }

    // ÖPNV-Fahrzeuge flüssig (zehnmal je Sekunde), nur diese Quelle.
    LaunchedEffect(style, stand) {
        val s = style ?: return@LaunchedEffect
        while (isActive) {
            s.getSourceAs<GeoJsonSource>(Quellen.OEPNV_FAHRZEUGE)?.setGeoJson(szene.oepnvFahrzeuge(stand, System.currentTimeMillis()))
            delay(100)
        }
    }

    // Eigener Standort; in der Navigation auf die Route gelegt und als Navi-Pfeil, die Route beginnt dort.
    val navi by modell.navigator.stand.collectAsStateWithLifecycle()
    val rest = remember { Routenrest() }
    LaunchedEffect(style, ort, stand.haeltA, navi) {
        val s = style ?: return@LaunchedEffect
        val o = ort
        val n = navi
        val aufRoute = n?.aufRoute
        val punkt = aufRoute?.let { GeoPunkt(it.latitude, it.longitude) } ?: o?.let { GeoPunkt(it.lat, it.lon) }
        val richtung = aufRoute?.takeIf { it.hasBearing() }?.bearing?.toDouble() ?: o?.richtung
        s.getSourceAs<GeoJsonSource>(Quellen.ICH)?.setGeoJson(szene.ich(punkt, richtung, if (n != null) "pfeil" else "punkt", stand.haeltA))
        s.getSourceAs<GeoJsonSource>(Quellen.ROUTE)?.setGeoJson(szene.route(if (n != null) rest.rest(n.route, punkt) else emptyList(), n?.info?.sonderrechte == true))
        // Angeheftet: Kamera folgt dem Standort.
        if (punkt != null) steuerung.folgen(punkt, o?.tempo, richtung, null)
    }

    AndroidView(factory = { ansicht }, modifier = modifier)
}

