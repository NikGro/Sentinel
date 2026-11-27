package de.nglab.sentinel.kern.karte

import de.nglab.sentinel.kern.modell.GeoPunkt
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.sin

/** Wie die Karte am eigenen Standort hängt; `Frei` = so, wie man sie hinschiebt und dreht. */
enum class Anheftung { Frei, Richtung, Norden, Navigation }

/** Kamera als Zielwert für die Engine (Mitte, Zoom, Drehung, Neigung). */
data class Kamera(val mitte: GeoPunkt, val zoom: Double, val richtung: Double, val neigung: Double)

/**
 * Kameraführung (eine Stelle, die die Kamera bewegt), aus den Erfahrungen der bisherigen App:
 * - Anheften: in Fahrt- bzw. Blickrichtung (550 m, 40° geneigt), Norden oben (1500 m, von oben), Navigation (eigene Werte).
 * - Angeheftet ändern Zoomen und Kippen des Nutzers nur Sollabstand und Sollwinkel – sie lösen nie.
 * - Seitliches Verschieben (> 30 pt) oder Herausdrehen (> 10°) löst die Kopplung.
 * - Folgen mit Vorausrechnung nach Tempo und Kurs; kurze Kamerafahrten (eine Geste bricht sie in der Engine ab).
 * Die Plattform meldet Standort und Gesten und führt die zurückgegebene Kamera aus.
 */
class Kamerafuehrung {
    var anheftung: Anheftung = Anheftung.Frei
        private set
    private var sollZoom = 16.0
    private var sollNeigung = 0.0
    private var letzteRichtung = 0.0

    companion object {
        const val LOESEN_PUNKTE = 30.0
        const val LOESEN_GRAD = 10.0
        const val FAHRT_MS = 900L

        /** Zoomstufe für einen Abstand der Kamera in Metern (Breitengrad, Bildschirmhöhe in Punkten). */
        fun zoomFuer(abstandMeter: Double, lat: Double, hoehePunkte: Double = 800.0): Double {
            val meterJePunkt = abstandMeter / hoehePunkte
            return ln(156_543.03 * cos(lat * PI / 180) / meterJePunkt) / ln(2.0) - 1
        }
    }

    /** Anheften: Startwerte je Art (Abstand wie bisher, in Zoomstufen umgerechnet). */
    fun anheften(art: Anheftung, lat: Double) {
        anheftung = art
        when (art) {
            Anheftung.Richtung -> { sollZoom = zoomFuer(550.0, lat); sollNeigung = 40.0 }
            Anheftung.Norden -> { sollZoom = zoomFuer(1500.0, lat); sollNeigung = 0.0 }
            Anheftung.Navigation -> { sollZoom = zoomFuer(700.0, lat); sollNeigung = 50.0 }
            Anheftung.Frei -> Unit
        }
    }

    fun loesen() {
        anheftung = Anheftung.Frei
    }

    /** Zoomen oder Kippen durch den Nutzer: neue Sollwerte, angeheftet bleibt es. */
    fun nutzerZoom(zoom: Double, neigung: Double) {
        sollZoom = zoom
        sollNeigung = neigung
    }

    /** Verschieben mit einem Finger (Strecke in Punkten seit Beginn) bzw. Drehen (Grad seit Beginn). */
    fun geste(verschobenPunkte: Double, gedrehtGrad: Double): Boolean {
        if (anheftung == Anheftung.Frei) return false
        val loest = verschobenPunkte > LOESEN_PUNKTE || (anheftung == Anheftung.Richtung && abs(gedrehtGrad) > LOESEN_GRAD)
        if (loest) anheftung = Anheftung.Frei
        return loest
    }

    /**
     * Zielkamera für einen neuen Standort; `null`, wenn nicht angeheftet. Vorausrechnung um die Dauer der Kamerafahrt,
     * damit die Kamera nicht hinter dem Punkt herläuft. Im Stand gilt die Kompassrichtung des Geräts.
     */
    fun ziel(ort: GeoPunkt, tempo: Double?, kurs: Double?, kompass: Double?): Kamera? {
        if (anheftung == Anheftung.Frei) return null
        val faehrt = (tempo ?: 0.0) > 1.5 && kurs != null
        val richtung = when {
            faehrt -> kurs!!
            kompass != null -> kompass
            else -> letzteRichtung
        }.also { letzteRichtung = it }
        val voraus = if (faehrt) (tempo!! * FAHRT_MS / 1000.0) else 0.0
        val mitte = if (voraus > 0) versetzt(ort, voraus, kurs!!) else ort
        return when (anheftung) {
            Anheftung.Norden -> Kamera(mitte, sollZoom, 0.0, sollNeigung)
            else -> Kamera(mitte, sollZoom, richtung, sollNeigung)
        }
    }

    private fun versetzt(p: GeoPunkt, meter: Double, richtungGrad: Double): GeoPunkt {
        val w = richtungGrad * PI / 180
        return GeoPunkt(p.lat + meter * cos(w) / 110_540, p.lon + meter * sin(w) / (111_320 * cos(p.lat * PI / 180)))
    }
}
