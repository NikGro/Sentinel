package de.nglab.sentinel.karte

import android.graphics.RectF
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.nglab.sentinel.AppModell
import de.nglab.sentinel.kern.karte.KartenObjekt
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

/** Antippbare Ebenen des gemeinsamen Stils, die oberste zuerst. */
private val ANTIPPBAR = arrayOf(
    "lage-cluster", "lage-symbole", "lage-symbole-zeichen", "lage-oepnv-fahrzeuge", "lage-halte",
    "lage-linien", "lage-oepnv-kante", "lage-spuren", "lage-standortspur", "lage-flaechen",
)

/** Steuerung der Karte von außen (Kamera, Verkehrslage); gefüllt, sobald die Karte bereit ist. */
class KartenSteuerung {
    internal var karte: MapLibreMap? = null

    fun zeigen(p: GeoPunkt, zoom: Double = 16.0) {
        karte?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(p.lat, p.lon), zoom), 600)
    }

    fun verkehr(an: Boolean) {
        val style = karte?.style ?: return
        for (id in listOf("verkehr-fluss", "verkehr-sperrung", "verkehr-meldung-punkt")) {
            style.getLayer(id)?.setProperties(org.maplibre.android.style.layers.PropertyFactory.visibility(if (an) "visible" else "none"))
        }
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
    beiAuswahl: (KartenObjekt) -> Unit,
) {
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
                karte.addOnMapClickListener { lage ->
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
                            KartenObjekt.von(erster.getStringProperty("id"))?.let(beiAuswahl)
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

    // ÖPNV-Fahrzeuge flüssig (zehnmal je Sekunde), nur diese Quelle.
    LaunchedEffect(style, stand) {
        val s = style ?: return@LaunchedEffect
        while (isActive) {
            s.getSourceAs<GeoJsonSource>(Quellen.OEPNV_FAHRZEUGE)?.setGeoJson(szene.oepnvFahrzeuge(stand, System.currentTimeMillis()))
            delay(100)
        }
    }

    // Eigener Standort
    LaunchedEffect(style, ort, stand.haeltA) {
        val s = style ?: return@LaunchedEffect
        val o = ort
        s.getSourceAs<GeoJsonSource>(Quellen.ICH)?.setGeoJson(szene.ich(o?.let { GeoPunkt(it.lat, it.lon) }, o?.richtung, "punkt", stand.haeltA))
    }

    AndroidView(factory = { ansicht }, modifier = modifier)
}

