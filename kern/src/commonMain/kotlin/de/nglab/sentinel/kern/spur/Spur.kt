package de.nglab.sentinel.kern.spur

import de.nglab.sentinel.kern.modell.GeoPunkt
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.math.abs

/** Woher ein Punkt der Spur kam, mit Farbe des Abschnitts auf der Karte. */
enum class SpurQuelle(val schluessel: String, val titel: String, val farbe: String) {
    Gps("gps", "GPS des Telefons", "#0A84FF"),
    Tracker("tracker", "Tracker", "#FF9F0A"),
    A("a", "A-Position", "#FF453A"),
    Oepnv("oepnv", "ÖPNV-Fahrt", "#30D158"),
    Hand("hand", "Von Hand gesetzt", "#8E8E93"),
    Besatzung("besatzung", "Standort der Besatzung", "#5E5CE6"),
    Abgestellt("abgestellt", "Abgestellt", "#8E8E93");

    /** Meldet sich die Quelle laufend? Dann ist eine lange Pause eine Datenlücke, keine Standzeit. */
    val laufend: Boolean get() = this != Hand && this != Abgestellt

    companion object {
        fun von(s: String): SpurQuelle? = entries.firstOrNull { it.schluessel == s }
    }
}

data class SpurPunkt(val punkt: GeoPunkt, val zeitMs: Long, val tempo: Double?, val quelle: SpurQuelle, val info: String? = null)

data class Standzeit(val punkt: GeoPunkt, val vonMs: Long, val bisMs: Long) {
    val dauerMs: Long get() = bisMs - vonMs
}

/** Eine Spur (Fahnder, Ziel, Fahrzeug, Tracker) im gewählten Zeitraum. */
class Spur(val art: String, val id: String, val punkte: List<SpurPunkt>) {
    companion object {
        const val LUECKE_MS = 10 * 60_000L
        const val LUECKE_M = 250.0
        const val STAND_RADIUS = 40.0
        const val STAND_MS = 3 * 60_000L

        /** Antwort von `GET /api/v1/spur`: `punkte` als [lat, lon, ts, tempo, quelle, info?]. */
        fun ausAntwort(art: String, id: String, antwort: JsonElement): Spur {
            val zeilen = antwort.jsonObject["punkte"]?.jsonArray ?: JsonArray(emptyList())
            val punkte = zeilen.mapNotNull { z ->
                val a = z.jsonArray
                if (a.size < 5) return@mapNotNull null
                val lat = a[0].jsonPrimitive.doubleOrNull ?: return@mapNotNull null
                val lon = a[1].jsonPrimitive.doubleOrNull ?: return@mapNotNull null
                val ts = a[2].jsonPrimitive.doubleOrNull ?: return@mapNotNull null
                val quelle = SpurQuelle.von(a[4].jsonPrimitive.content) ?: return@mapNotNull null
                SpurPunkt(GeoPunkt(lat, lon), ts.toLong(), a[3].jsonPrimitive.doubleOrNull, quelle, a.getOrNull(5)?.jsonPrimitive?.content?.takeIf { it != "null" })
            }
            return Spur(art, id, punkte)
        }
    }

    /** Liegt zwischen Punkt `i` und dem nächsten eine Lücke (lange ohne Daten und weit bewegt)? */
    fun luecke(i: Int): Boolean {
        if (i + 1 >= punkte.size) return true
        val a = punkte[i]
        val b = punkte[i + 1]
        return b.zeitMs - a.zeitMs > LUECKE_MS && a.punkt.distanz(b.punkt) > LUECKE_M
    }

    data class Abschnitt(val quelle: SpurQuelle, val punkte: List<GeoPunkt>, val luecke: Boolean)

    /** Abschnitte nach Quelle; Lücken als eigene Abschnitte (gestrichelt gezeichnet). */
    val abschnitte: List<Abschnitt> by lazy {
        val ergebnis = ArrayList<Abschnitt>()
        if (punkte.isEmpty()) return@lazy ergebnis
        var aktuell = mutableListOf(punkte[0].punkt)
        var quelle = punkte[0].quelle
        fun abschliessen() {
            if (aktuell.size >= 2) ergebnis += Abschnitt(quelle, aktuell, false)
        }
        for (i in 1 until punkte.size) {
            val p = punkte[i]
            if (luecke(i - 1)) {
                abschliessen()
                ergebnis += Abschnitt(p.quelle, listOf(punkte[i - 1].punkt, p.punkt), true)
                aktuell = mutableListOf(p.punkt)
                quelle = p.quelle
            } else if (p.quelle != quelle) {
                aktuell += p.punkt
                abschliessen()
                aktuell = mutableListOf(p.punkt)
                quelle = p.quelle
            } else {
                aktuell += p.punkt
            }
        }
        abschliessen()
        ergebnis
    }

    /** Standzeiten: mindestens drei Minuten innerhalb von 40 m. */
    val standzeiten: List<Standzeit> by lazy {
        val ergebnis = ArrayList<Standzeit>()
        var start = 0
        while (start < punkte.size) {
            var ende = start
            while (ende + 1 < punkte.size && punkte[ende + 1].punkt.distanz(punkte[start].punkt) <= STAND_RADIUS) ende++
            val von = punkte[start].zeitMs
            val bis = if (ende + 1 < punkte.size) punkte[ende + 1].zeitMs else punkte[ende].zeitMs
            if (bis - von >= STAND_MS && (ende > start || ende + 1 < punkte.size)) ergebnis += Standzeit(punkte[start].punkt, von, bis)
            start = ende + 1
        }
        ergebnis
    }

    /** Tempo an einem Punkt: gemeldet, sonst aus den Nachbarpunkten geschätzt (zweiter Wert: geschätzt). */
    fun tempo(i: Int): Pair<Double, Boolean>? {
        punkte[i].tempo?.let { return it to false }
        val schaetzungen = listOf(i - 1, i + 1).filter { it in punkte.indices }.mapNotNull { j ->
            val s = abs(punkte[j].zeitMs - punkte[i].zeitMs) / 1000.0
            if (s <= 0 || s * 1000 >= LUECKE_MS) null else punkte[j].punkt.distanz(punkte[i].punkt) / s
        }
        return if (schaetzungen.isEmpty()) null else schaetzungen.average() to true
    }

    /** Wo das Ding zu einem Zeitpunkt war (linear zwischen zwei Punkten, in Lücken keine erfundene Position). */
    fun ort(zeitMs: Long): GeoPunkt? {
        if (punkte.isEmpty() || zeitMs < punkte.first().zeitMs || zeitMs > punkte.last().zeitMs) return null
        val n = punkte.indexOfFirst { it.zeitMs >= zeitMs }
        if (n <= 0) return punkte.first().punkt
        val a = punkte[n - 1]
        val b = punkte[n]
        if (luecke(n - 1)) return null
        val f = if (b.zeitMs > a.zeitMs) (zeitMs - a.zeitMs).toDouble() / (b.zeitMs - a.zeitMs) else 0.0
        return GeoPunkt(a.punkt.lat + (b.punkt.lat - a.punkt.lat) * f, a.punkt.lon + (b.punkt.lon - a.punkt.lon) * f)
    }
}

/**
 * Spuren als Merkmale der Quelle `s-spuren`: Abschnitte nach Quelle gefärbt, Lücken gestrichelt; Standortspur als
 * eine Linie mit Farbverlauf (Stil: `line-gradient`) bzw. nach Häufigkeit in kurzen Stücken.
 */
object Spurszene {
    private fun linie(punkte: List<GeoPunkt>): JsonObject = buildJsonObject {
        put("type", "LineString")
        putJsonArray("coordinates") { punkte.forEach { p -> add(buildJsonArray { add(JsonPrimitive(p.lon)); add(JsonPrimitive(p.lat)) }) } }
    }

    private fun merkmal(punkte: List<GeoPunkt>, eigenschaften: JsonObject) = buildJsonObject {
        put("type", "Feature")
        put("geometry", linie(punkte))
        put("properties", eigenschaften)
    }

    fun merkmale(spur: Spur, kennung: String, standortspur: Boolean = false, haeufigkeit: Map<String, Int>? = null): List<JsonObject> {
        if (standortspur && haeufigkeit == null) {
            // Eine Linie je zusammenhängendem Stück (Verlauf alt → neu), Lücken gestrichelt.
            return spur.abschnitte.map { a ->
                merkmal(a.punkte, buildJsonObject { put("id", "spur:$kennung"); put("art", "spur"); put("standortspur", !a.luecke); put("luecke", a.luecke) })
            }
        }
        if (standortspur && haeufigkeit != null) {
            val werte = Haeufigkeit.geglaettet(spur.punkte.map { it.punkt }, haeufigkeit)
            return Haeufigkeit.stuecke(spur, werte).map { (punkte, wert, luecke) ->
                merkmal(punkte, buildJsonObject {
                    put("id", "spur:$kennung"); put("art", "spur"); put("standortspur", !luecke); put("haeufigkeit", !luecke); put("luecke", luecke)
                    put("farbe", Haeufigkeit.farbe((wert - 1) / 4))
                })
            }
        }
        return spur.abschnitte.map { a ->
            merkmal(a.punkte, buildJsonObject { put("id", "spur:$kennung"); put("art", "spur"); put("farbe", a.quelle.farbe); put("luecke", a.luecke) })
        }
    }

    fun sammlung(merkmale: List<JsonObject>): String = buildJsonObject {
        put("type", "FeatureCollection")
        put("features", JsonArray(merkmale))
    }.toString()
}

/** Häufigkeit der Standortspur: Durchfahrten je Feld (etwa 25 m), geglättet entlang der Spur, Farbe Blau → Rot. */
object Haeufigkeit {
    fun feld(p: GeoPunkt): String {
        val latSchritt = 25.0 / 110_540
        val lonSchritt = 25.0 / (111_320 * kotlin.math.cos(53.5 * kotlin.math.PI / 180))
        return "${kotlin.math.round(p.lat / latSchritt).toLong()}|${kotlin.math.round(p.lon / lonSchritt).toLong()}"
    }

    /** Durchfahrten je Feld: jede neue Einfahrt in ein Feld zählt einmal. */
    fun durchfahrten(punkte: List<GeoPunkt>): Map<String, Int> {
        val zahl = HashMap<String, Int>()
        var vorher: String? = null
        for (p in punkte) {
            val f = feld(p)
            if (f != vorher) zahl[f] = (zahl[f] ?: 0) + 1
            vorher = f
        }
        return zahl
    }

    /** Häufigkeit je Punkt (1 bis 5) als gleitender Mittelwert über etwa 70 m entlang der Spur. */
    fun geglaettet(punkte: List<GeoPunkt>, zahl: Map<String, Int>, fenster: Double = 70.0): List<Double> {
        if (punkte.isEmpty()) return emptyList()
        val roh = punkte.map { (zahl[feld(it)] ?: 1).coerceIn(1, 5).toDouble() }
        val entlang = DoubleArray(punkte.size)
        for (i in 1 until punkte.size) entlang[i] = entlang[i - 1] + punkte[i - 1].distanz(punkte[i])
        val ergebnis = DoubleArray(punkte.size)
        var lo = 0
        var hi = 0
        var summe = 0.0
        for (i in punkte.indices) {
            while (hi < punkte.size && entlang[hi] - entlang[i] <= fenster / 2) { summe += roh[hi]; hi++ }
            while (entlang[i] - entlang[lo] > fenster / 2) { summe -= roh[lo]; lo++ }
            ergebnis[i] = summe / (hi - lo)
        }
        return ergebnis.toList()
    }

    /** Stücke, die enden, sobald die Farbe merklich wechselt (gut 3 % der Skala); Lücken als eigene Stücke. */
    fun stuecke(spur: Spur, werte: List<Double>): List<Triple<List<GeoPunkt>, Double, Boolean>> {
        val p = spur.punkte
        val ergebnis = ArrayList<Triple<List<GeoPunkt>, Double, Boolean>>()
        var a = 0
        while (a < p.size - 1) {
            if (spur.luecke(a)) {
                ergebnis += Triple(listOf(p[a].punkt, p[a + 1].punkt), 1.0, true)
                a++
                continue
            }
            var b = a + 1
            while (b < p.size - 1 && !spur.luecke(b - 1) && abs((werte[b] - werte[a]) / 4) < 0.035) b++
            ergebnis += Triple(p.subList(a, b + 1).map { it.punkt }, werte[(a + b) / 2], false)
            a = b
        }
        return ergebnis
    }

    /** Farbskala von Blau über Grün und Gelb bis Rot, `t` von 0 bis 1 (HSV, Farbton 0,62 → 0). */
    fun farbe(t: Double): String {
        val h = 0.62 * (1 - t.coerceIn(0.0, 1.0)) * 6
        val s = 0.9
        val v = 0.95
        val i = h.toInt()
        val f = h - i
        val p = v * (1 - s)
        val q = v * (1 - s * f)
        val u = v * (1 - s * (1 - f))
        val (r, g, b) = when (i % 6) {
            0 -> Triple(v, u, p)
            1 -> Triple(q, v, p)
            2 -> Triple(p, v, u)
            3 -> Triple(p, q, v)
            4 -> Triple(u, p, v)
            else -> Triple(v, p, q)
        }
        fun hex(x: Double) = (x * 255).toInt().coerceIn(0, 255).toString(16).padStart(2, '0').uppercase()
        return "#${hex(r)}${hex(g)}${hex(b)}"
    }
}
