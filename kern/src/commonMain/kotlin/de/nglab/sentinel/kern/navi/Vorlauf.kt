package de.nglab.sentinel.kern.navi

import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.netz.Api
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.PI

/** Parallel-Modus: Position und Fahrtrichtung des Ziels; der Server meidet seine Straße auf `meter` voraus. */
data class Parallelhinweis(val punkt: GeoPunkt, val kurs: Double, val meter: Double)

/**
 * Vorlauf zu einem fahrenden Ziel: bestimmt aus den letzten Positionen seine Fahrtrichtung, über das Straßenverzeichnis
 * des Servers seine Straße, lädt deren Querstraßen und wählt die nächste Kreuzung vor ihm. Ist das Ziel an ihr vorbei,
 * gilt die nächste. Annahme: Das Ziel fährt auf seiner Straße geradeaus weiter.
 */
class Vorlaufplaner {
    private data class Spur(
        val punkte: MutableList<Pair<GeoPunkt, Long>> = mutableListOf(),
        var strasse: String? = null,
        var strasseAbgefragtBei: GeoPunkt? = null,
        var kreuzungen: List<Pair<String, List<GeoPunkt>>> = emptyList(),
        var kreuzungenFuer: String? = null,
    )

    private val spuren = HashMap<String, Spur>()

    /** Ziel an `punkt` (Schlüssel z. B. „ziel:abc“): nächste Kreuzung voraus oder `null`, solange Angaben fehlen. */
    suspend fun kreuzung(schluessel: String, punkt: GeoPunkt, jetztMs: Long, api: Api?): Pair<GeoPunkt, String>? {
        val s = spuren.getOrPut(schluessel) { Spur() }
        if (s.punkte.lastOrNull()?.first?.let { it.distanz(punkt) > 3 } != false) s.punkte += punkt to jetztMs
        s.punkte.removeAll { jetztMs - it.second > 120_000 }
        val kurs = kurs(s.punkte.map { it.first })
        if (api != null && (s.strasseAbgefragtBei?.let { it.distanz(punkt) > 60 } != false)) {
            s.strasseAbgefragtBei = punkt
            runCatching { api.strasse(punkt, kurs) }.getOrNull()?.let { s.strasse = it }
        }
        val strasse = s.strasse
        if (api != null && strasse != null && s.kreuzungenFuer != strasse) {
            runCatching { api.kreuzungStrassen(strasse, punkt) }.onSuccess {
                s.kreuzungen = it
                s.kreuzungenFuer = strasse
            }
        }
        return naechste(s.kreuzungen, strasse, punkt, kurs ?: return null)
    }

    /** Parallel-Modus: Strecke bis zur Kreuzung (mindestens 300 m, damit auch ohne Kreuzung etwas gemieden wird). */
    fun parallelhinweis(schluessel: String, kreuzung: GeoPunkt?): Parallelhinweis? {
        val s = spuren[schluessel] ?: return null
        val letzter = s.punkte.lastOrNull()?.first ?: return null
        val k = kurs(s.punkte.map { it.first }) ?: return null
        val meter = ((kreuzung?.let { letzter.distanz(it) } ?: 300.0) - 30).coerceIn(300.0, 1500.0)
        return Parallelhinweis(letzter, k, meter)
    }

    fun zuruecksetzen() = spuren.clear()

    companion object {
        /** Nächste Kreuzung voraus: 40 m bis 1,5 km entfernt, höchstens 50° neben der Fahrtrichtung. */
        fun naechste(kreuzungen: List<Pair<String, List<GeoPunkt>>>, strasse: String?, von: GeoPunkt, kurs: Double): Pair<GeoPunkt, String>? {
            var beste: Triple<GeoPunkt, String, Double>? = null
            for ((name, punkte) in kreuzungen) {
                if (name == strasse) continue
                for (k in punkte) {
                    val d = von.distanz(k)
                    if (d <= 40 || d >= 1500) continue
                    var ab = abs(richtung(von, k) - kurs) % 360
                    if (ab > 180) ab = 360 - ab
                    if (ab >= 50) continue
                    if (beste == null || d < beste.third) beste = Triple(k, name, d)
                }
            }
            return beste?.let { it.first to it.second }
        }

        /** Fahrtrichtung aus der Bewegung der letzten mindestens 30 m. */
        fun kurs(punkte: List<GeoPunkt>): Double? {
            val letzter = punkte.lastOrNull() ?: return null
            val von = punkte.lastOrNull { it.distanz(letzter) >= 30 } ?: return null
            return richtung(von, letzter)
        }

        fun richtung(a: GeoPunkt, b: GeoPunkt): Double {
            val r = PI / 180
            val y = sin((b.lon - a.lon) * r) * cos(b.lat * r)
            val x = cos(a.lat * r) * sin(b.lat * r) - sin(a.lat * r) * cos(b.lat * r) * cos((b.lon - a.lon) * r)
            return (atan2(y, x) / r + 360) % 360
        }
    }
}

/** Tempolimit während der Navigation: höchstens alle 20 s bzw. nach 150 m neu abfragen (Straßenverzeichnis). */
class Tempolimitabfrage {
    private var zuletztBei: GeoPunkt? = null
    private var zuletztMs = 0L
    var kmh: Int? = null
        private set

    suspend fun aktualisieren(api: Api, ort: GeoPunkt, jetztMs: Long): Boolean {
        val weit = zuletztBei?.let { it.distanz(ort) > 150 } ?: true
        if (!weit && jetztMs - zuletztMs < 20_000) return false
        zuletztBei = ort
        zuletztMs = jetztMs
        val neu = runCatching { api.tempolimit(ort) }.getOrNull()
        val anders = neu != kmh
        kmh = neu
        return anders
    }

    fun zuruecksetzen() {
        zuletztBei = null; zuletztMs = 0; kmh = null
    }
}
