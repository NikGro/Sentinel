package de.nglab.sentinel.kern.oepnv

import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Wo ein ÖPNV-Fahrzeug gerade ist, nach einem Fahrmodell wie bei einem echten Fahrzeug (`Fahrmodell`): abgerundeter
 * Fahrweg, Höchsttempo je Verkehrsart, langsamer in Kurven, weiches Bremsen und Anfahren, Halt an jeder Haltestelle.
 * Mit Fahrplan (Echtzeit) wird das Profil an die Zeiten angepasst. Übertragen aus der bisherigen App (TransitSimulation).
 */
object OepnvSimulation {
    /** So lange vor der Abfahrt am ersten Halt und nach der Ankunft am letzten ist ein Fahrzeug schon bzw. noch da (s). */
    const val STEHEN = 300.0

    data class Zustand(
        val punkt: GeoPunkt,
        /** Nächster (oder gerade bedienter) Halt. */
        val naechsterHalt: Int,
        val amHalt: Boolean,
        val meter: Double,
        val tempo: Double,
    )

    /** Schnelle Entfernung in Metern (flache Näherung, auf Stadtgröße genau genug). */
    fun meter(a: GeoPunkt, b: GeoPunkt): Double {
        val x = (b.lon - a.lon) * 111_320 * cos((a.lat + b.lat) * PI / 360)
        val y = (b.lat - a.lat) * 110_540
        return sqrt(x * x + y * y)
    }

    /** Index des nächsten Wegpunkts je Halt, aufsteigend; `null`, wenn ein Halt weit (> 250 m) neben dem Weg liegt. */
    fun haltIndizes(halte: List<GeoPunkt>, weg: List<GeoPunkt>): List<Int>? {
        if (weg.size < 2) return null
        val ergebnis = ArrayList<Int>(halte.size)
        var ab = 0
        for (halt in halte) {
            var beste = ab
            var besteD = Double.MAX_VALUE
            for (i in ab until weg.size) {
                val d = meter(weg[i], halt)
                if (d < besteD) { besteD = d; beste = i }
            }
            if (besteD >= 250) return null
            ergebnis += beste
            ab = beste
        }
        return ergebnis
    }

    /** Position nach echten Zeiten (ms je Halt); `null` vor der ersten Abfahrt und eine halbe Minute nach der Ankunft. */
    fun zustand(halte: List<GeoPunkt>, weg: List<GeoPunkt>, zeiten: List<Long?>, typ: String, jetztMs: Long): Zustand? {
        val m = Fahrmodell.nachFahrplan(halte, weg, zeiten, typ) ?: return null
        val t = jetztMs / 1000.0
        if (t < m.abfahrt[0] || t > m.ankunft.last() + 30) return null
        return m.zustand(t)
    }

    /** Position ohne Fahrplan bei Abfahrt `abfahrtMs` am ersten Halt; `null` vor der Abfahrt und nach der Ankunft. */
    fun zustand(halte: List<GeoPunkt>, weg: List<GeoPunkt>, typ: String, abfahrtMs: Long, jetztMs: Long): Zustand? {
        val m = Fahrmodell.geschaetzt(halte, weg, typ) ?: return null
        val t = (jetztMs - abfahrtMs) / 1000.0
        if (t < 0 || t > m.ankunft.last()) return null
        return m.zustand(t)
    }

    /** Fahrdauer ohne Fahrplan in Sekunden. */
    fun dauer(halte: List<GeoPunkt>, weg: List<GeoPunkt>, typ: String): Double = Fahrmodell.geschaetzt(halte, weg, typ)?.ankunft?.lastOrNull() ?: 0.0

    /** Wo das Fahrzeug einer ÖPNV-Markierung gerade steht (vor der Abfahrt am ersten, nach der Ankunft am letzten Halt). */
    fun punkt(m: Markierung, jetztMs: Long): GeoPunkt? {
        if (!m.typ.istOepnv || m.punkte.size < 2) return null
        val typ = m.linie?.typ ?: "bus"
        m.fahrt?.let { fahrt ->
            zustand(m.punkte, m.weg, fahrt.zeiten, typ, jetztMs)?.let { return it.punkt }
            val erste = fahrt.zeiten.firstNotNullOfOrNull { it } ?: jetztMs
            return if (jetztMs < erste) m.punkte.first() else m.punkte.last()
        }
        if (m.typ == Form.OepnvFahrzeug && m.linie != null && m.zeit != null) {
            zustand(m.punkte, m.weg, typ, m.zeit, jetztMs)?.let { return it.punkt }
            return if (jetztMs < m.zeit) m.punkte.first() else m.punkte.last()
        }
        return null
    }

    /**
     * Halt `voraus` Halte vor dem Fahrzeug einer ÖPNV-Markierung (1 = nächster Halt; steht es gerade am Halt, der danach),
     * mit Name; `null`, wenn das Fahrzeug gerade nicht fährt. Rückt mit dem Fahrzeug weiter, bis zum Endhalt.
     */
    fun haltVoraus(m: Markierung, jetztMs: Long, voraus: Int): Pair<GeoPunkt, String>? {
        if (!m.typ.istOepnv || m.punkte.size < 2) return null
        val typ = m.linie?.typ ?: "bus"
        val z = m.fahrt?.let { zustand(m.punkte, m.weg, it.zeiten, typ, jetztMs) }
            ?: if (m.typ == Form.OepnvFahrzeug && m.zeit != null) zustand(m.punkte, m.weg, typ, m.zeit, jetztMs) else null
        z ?: return null
        val index = (z.naechsterHalt + if (z.amHalt) voraus else voraus - 1).coerceIn(0, m.punkte.lastIndex)
        return m.punkte[index] to (m.haltNamen.getOrNull(index)?.takeIf { it.isNotBlank() } ?: "Halt ${index + 1}")
    }

    /** Ankunft am Endhalt (ms): echte Zeit, sonst geschätzt. */
    fun ende(m: Markierung): Long? {
        m.fahrt?.zeiten?.lastOrNull { it != null }?.let { return it }
        val linie = m.linie ?: return null
        val abfahrt = m.zeit ?: return null
        return abfahrt + (dauer(m.punkte, m.weg, linie.typ) * 1000).toLong()
    }

    /** Wird das Fahrzeug gerade gezeichnet (fünf Minuten vor Abfahrt bis fünf nach Ankunft)? */
    fun fahrzeugSichtbar(m: Markierung, jetztMs: Long): Boolean {
        val start = m.fahrt?.zeiten?.firstNotNullOfOrNull { it } ?: m.zeit ?: return false
        val ende = ende(m) ?: return false
        return jetztMs >= start - STEHEN * 1000 && jetztMs <= ende + STEHEN * 1000
    }

    /** Fahrzeuge im Takt, die gerade auf dem Abschnitt sind: Abfahrt am ersten Halt (ms) und Zustand. */
    fun taktFahrzeuge(m: Markierung, jetztMs: Long): List<Pair<Long, Zustand>> {
        val takt = m.takt ?: return emptyList()
        val linie = m.linie ?: return emptyList()
        val bezug = m.zeit ?: return emptyList()
        if (m.typ != Form.OepnvLinie || takt <= 0) return emptyList()
        val abstand = takt * 60.0
        val gesamt = dauer(m.punkte, m.weg, linie.typ)
        val vergangen = (jetztMs - bezug) / 1000.0
        val erste = ceil((vergangen - gesamt - STEHEN) / abstand).toInt()
        val letzte = floor((vergangen + STEHEN) / abstand).toInt()
        val modell = Fahrmodell.geschaetzt(m.punkte, m.weg, linie.typ) ?: return emptyList()
        if (letzte < erste) return emptyList()
        return (erste..letzte).map { k ->
            val abfahrt = bezug + (k * abstand * 1000).toLong()
            abfahrt to modell.zustand((jetztMs - abfahrt) / 1000.0)
        }
    }
}

/**
 * Fahrmodell einer Fahrt, einmal berechnet und dann bei jedem Bild nur nachgeschlagen.
 *
 * 1. Fahrweg in 5-m-Stücke teilen und gleitend mitteln (Ecken abgerundet).
 * 2. Tempo: höchstens das der Verkehrsart, in Kurven nach Radius (Querbeschleunigung), an Halten null; vorwärts durch
 *    die Beschleunigung, rückwärts durch die Bremsverzögerung begrenzt.
 * 3. Fahrplan: Je Abschnitt das Profil strecken oder stauchen, mit realistischer Standzeit; viel zu viel Zeit wird am
 *    Halt gewartet statt gekrochen.
 */
class Fahrmodell private constructor(
    private val ursprungLat: Double,
    private val ursprungLon: Double,
    private val meterJeLon: Double,
    private val xs: DoubleArray,
    private val ys: DoubleArray,
    private val laengen: DoubleArray,
    val haltMeter: DoubleArray,
    /** Ankunft und Abfahrt je Halt (s; ohne Fahrplan ab der ersten Abfahrt, sonst seit 1970). */
    val ankunft: DoubleArray,
    val abfahrt: DoubleArray,
    private val zeitpunkte: DoubleArray,
    private val zeitMeter: DoubleArray,
) {
    data class Art(val vmax: Double, val anfahren: Double, val bremsen: Double, val quer: Double, val stand: Double, val verkehr: Double) {
        companion object {
            fun von(typ: String): Art = when (typ) {
                "subway", "light_rail" -> Art(19.5, 1.1, 1.1, 1.0, 25.0, 0.9)
                "train" -> Art(27.0, 0.7, 0.8, 0.8, 45.0, 0.9)
                "tram" -> Art(14.0, 1.0, 1.1, 1.0, 20.0, 0.65)
                "ferry" -> Art(6.0, 0.25, 0.3, 0.4, 60.0, 1.0)
                else -> Art(14.0, 1.0, 1.0, 1.2, 20.0, 0.6)
            }
        }
    }

    val gesamtMeter: Double get() = laengen.lastOrNull() ?: 0.0

    fun zustand(t: Double): OepnvSimulation.Zustand {
        val s = meter(t)
        val v = tempo(t)
        val punkt = punkt(s)
        for (k in haltMeter.indices) {
            if (t >= ankunft[k] - 0.01 && t <= abfahrt[k] + 0.01) return OepnvSimulation.Zustand(punkt, k, true, s, 0.0)
        }
        if (t < abfahrt[0]) return OepnvSimulation.Zustand(punkt, 0, true, s, 0.0)
        val naechster = haltMeter.indexOfFirst { it > s + 0.5 }.let { if (it < 0) haltMeter.size - 1 else it }
        return OepnvSimulation.Zustand(punkt, naechster, false, s, v)
    }

    fun meter(t: Double): Double {
        if (zeitpunkte.isEmpty()) return 0.0
        if (t <= zeitpunkte.first()) return zeitMeter.first()
        if (t >= zeitpunkte.last()) return zeitMeter.last()
        var lo = 0
        var hi = zeitpunkte.size - 1
        while (hi - lo > 1) {
            val mid = (lo + hi) / 2
            if (zeitpunkte[mid] <= t) lo = mid else hi = mid
        }
        val spanne = zeitpunkte[hi] - zeitpunkte[lo]
        val f = if (spanne > 0) (t - zeitpunkte[lo]) / spanne else 1.0
        return zeitMeter[lo] + (zeitMeter[hi] - zeitMeter[lo]) * f
    }

    fun tempo(t: Double): Double = max(0.0, (meter(t + 0.25) - meter(t - 0.25)) / 0.5)

    fun punkt(meter: Double): GeoPunkt {
        val m = meter.coerceIn(0.0, gesamtMeter)
        var lo = 0
        var hi = max(laengen.size - 1, 0)
        while (hi - lo > 1) {
            val mid = (lo + hi) / 2
            if (laengen[mid] <= m) lo = mid else hi = mid
        }
        val spanne = if (laengen.isEmpty()) 0.0 else laengen[hi] - laengen[lo]
        val f = if (spanne > 0) (m - laengen[lo]) / spanne else 0.0
        val x = xs[lo] + (xs[hi] - xs[lo]) * f
        val y = ys[lo] + (ys[hi] - ys[lo]) * f
        return GeoPunkt(ursprungLat + y / 110_540, ursprungLon + x / meterJeLon)
    }

    companion object {
        private val speicher = LinkedHashMap<String, Fahrmodell?>()

        private fun schluessel(halte: List<GeoPunkt>, weg: List<GeoPunkt>, zeiten: List<Long?>?, typ: String, endStand: Boolean): String =
            buildString {
                halte.forEach { append(it.lat).append(',').append(it.lon).append(';') }
                append('|').append(weg.size).append(weg.firstOrNull()).append(weg.getOrNull(weg.size / 2)).append(weg.lastOrNull())
                append('|').append(zeiten?.joinToString(",")).append('|').append(typ).append(endStand)
            }

        private fun zwischengespeichert(schluessel: String, bauen: () -> Fahrmodell?): Fahrmodell? {
            if (speicher.containsKey(schluessel)) return speicher[schluessel]
            val wert = bauen()
            if (speicher.size > 300) speicher.clear()
            speicher[schluessel] = wert
            return wert
        }

        /** Ohne Fahrplan: Abfahrt am ersten Halt zur Zeit 0, Tempo wie im Verkehr üblich. */
        fun geschaetzt(halte: List<GeoPunkt>, weg: List<GeoPunkt>, typ: String): Fahrmodell? =
            zwischengespeichert(schluessel(halte, weg, null, typ, false)) { bauen(halte, weg, null, typ, false) }

        /** Nach Fahrplan: Zeiten in ms je Halt (Abfahrt, am letzten Ankunft); fehlende werden geschätzt. */
        fun nachFahrplan(halte: List<GeoPunkt>, weg: List<GeoPunkt>, zeiten: List<Long?>, typ: String): Fahrmodell? {
            if (zeiten.size != halte.size || zeiten.count { it != null } < 2) return null
            return zwischengespeichert(schluessel(halte, weg, zeiten, typ, false)) { bauen(halte, weg, zeiten, typ, false) }
        }

        /** Ein Abschnitt zwischen zwei Halten (Live-Karte): kommt etwas früher an und steht dann am Halt. */
        fun abschnitt(a: GeoPunkt, b: GeoPunkt, weg: List<GeoPunkt>, abfahrtMs: Long, ankunftMs: Long, typ: String): Fahrmodell? {
            val zeiten = listOf<Long?>(abfahrtMs, ankunftMs)
            return zwischengespeichert(schluessel(listOf(a, b), weg, zeiten, typ, true)) { bauen(listOf(a, b), weg, zeiten, typ, true) }
        }

        private fun bauen(halte: List<GeoPunkt>, weg: List<GeoPunkt>, zeiten: List<Long?>?, typ: String, endStand: Boolean): Fahrmodell? {
            if (halte.size < 2) return null
            val art = Art.von(typ)
            val basis = if (weg.size >= 2 && OepnvSimulation.haltIndizes(halte, weg) != null) weg else halte
            val ursprung = basis[0]
            val meterJeLon = 111_320 * cos(ursprung.lat * PI / 180)
            fun proj(p: GeoPunkt) = Pair((p.lon - ursprung.lon) * meterJeLon, (p.lat - ursprung.lat) * 110_540)

            // 1. In 5-m-Stücke teilen.
            val schritt = 5.0
            val rx = ArrayList<Double>()
            val ry = ArrayList<Double>()
            var rest = 0.0
            var vorher = proj(basis[0])
            rx += vorher.first; ry += vorher.second
            for (p in basis.drop(1)) {
                val q = proj(p)
                val dx = q.first - vorher.first
                val dy = q.second - vorher.second
                val d = sqrt(dx * dx + dy * dy)
                if (d <= 0) continue
                var bei = schritt - rest
                while (bei <= d) {
                    rx += vorher.first + dx * bei / d; ry += vorher.second + dy * bei / d
                    bei += schritt
                }
                rest = d - (bei - schritt)
                vorher = q
            }
            if (rest > 0.5) { rx += vorher.first; ry += vorher.second }
            if (rx.size < 2) return null

            // 2. Gleitend mitteln (±25 m), Enden fest.
            val fenster = 5
            val xs = rx.toDoubleArray()
            val ys = ry.toDoubleArray()
            if (rx.size > 2 * fenster) {
                val px = DoubleArray(rx.size + 1)
                val py = DoubleArray(rx.size + 1)
                for (i in rx.indices) { px[i + 1] = px[i] + rx[i]; py[i + 1] = py[i] + ry[i] }
                for (i in 1 until rx.size - 1) {
                    val w = minOf(fenster, i, rx.size - 1 - i)
                    val lo = i - w
                    val hi = i + w + 1
                    xs[i] = (px[hi] - px[lo]) / (hi - lo)
                    ys[i] = (py[hi] - py[lo]) / (hi - lo)
                }
            }
            val n = xs.size
            val laengen = DoubleArray(n)
            for (i in 1 until n) {
                val dx = xs[i] - xs[i - 1]
                val dy = ys[i] - ys[i - 1]
                laengen[i] = laengen[i - 1] + sqrt(dx * dx + dy * dy)
            }

            // Halte auf dem abgerundeten Weg.
            val haltIndex = IntArray(halte.size)
            var ab = 0
            for ((k, halt) in halte.withIndex()) {
                val q = proj(halt)
                var beste = ab
                var besteD = Double.MAX_VALUE
                for (i in ab until n) {
                    val d = (xs[i] - q.first) * (xs[i] - q.first) + (ys[i] - q.second) * (ys[i] - q.second)
                    if (d < besteD) { besteD = d; beste = i }
                }
                haltIndex[k] = beste
                ab = beste
            }

            // 3. Tempogrenze aus der Krümmung.
            val grenze = DoubleArray(n) { art.vmax }
            for (i in 1 until n - 1) {
                val a0 = atan2(ys[i] - ys[i - 1], xs[i] - xs[i - 1])
                val a1 = atan2(ys[i + 1] - ys[i], xs[i + 1] - xs[i])
                var kurve = abs(a1 - a0)
                if (kurve > PI) kurve = 2 * PI - kurve
                val ds = (laengen[i + 1] - laengen[i - 1]) / 2
                if (ds <= 0 || kurve <= 1e-4) continue
                grenze[i] = min(art.vmax, sqrt(art.quer * ds / kurve))
            }
            val faktor = if (zeiten == null) art.verkehr else 1.0

            // Je Abschnitt das natürliche Profil (Zeit je Punkt ab Abfahrt).
            val natuerlich = ArrayList<DoubleArray>()
            for (k in 0 until halte.size - 1) {
                val i0 = haltIndex[k]
                val i1 = max(haltIndex[k + 1], haltIndex[k])
                val v = DoubleArray(i1 - i0 + 1) { min(grenze[i0 + it] * faktor, art.vmax * faktor) }
                v[0] = 0.0
                v[v.size - 1] = 0.0
                for (j in 1 until v.size) {
                    val ds = laengen[i0 + j] - laengen[i0 + j - 1]
                    v[j] = min(v[j], sqrt(v[j - 1] * v[j - 1] + 2 * art.anfahren * ds))
                }
                for (j in v.size - 2 downTo 0) {
                    val ds = laengen[i0 + j + 1] - laengen[i0 + j]
                    v[j] = min(v[j], sqrt(v[j + 1] * v[j + 1] + 2 * art.bremsen * ds))
                }
                val t = DoubleArray(max(v.size, 1))
                for (j in 1 until v.size) {
                    val ds = laengen[i0 + j] - laengen[i0 + j - 1]
                    t[j] = t[j - 1] + ds / max((v[j - 1] + v[j]) / 2, 0.3)
                }
                natuerlich += t
            }

            val ankunft = DoubleArray(halte.size)
            val abfahrt = DoubleArray(halte.size)
            val fahrt = DoubleArray(halte.size - 1)
            if (zeiten != null) {
                val bekannt = zeiten.map { it?.let { ms -> ms / 1000.0 } }.toMutableList()
                val natGesamt = natuerlich.map { it.last() + art.stand }
                val idx = bekannt.indices.filter { bekannt[it] != null }
                for ((a, b) in idx.zipWithNext()) {
                    if (b <= a + 1) continue
                    val spanne = bekannt[b]!! - bekannt[a]!!
                    val gewichte = (a until b).map { natGesamt[it] }
                    val summe = max(gewichte.sum(), 1.0)
                    var acc = 0.0
                    for (k in a + 1 until b) {
                        acc += gewichte[k - 1 - a]
                        bekannt[k] = bekannt[a]!! + spanne * acc / summe
                    }
                }
                idx.firstOrNull()?.let { erste -> for (k in erste - 1 downTo 0) bekannt[k] = bekannt[k + 1]!! - natGesamt[k] }
                idx.lastOrNull()?.let { letzte -> for (k in letzte + 1 until halte.size) bekannt[k] = bekannt[k - 1]!! + natGesamt[k - 1] }
                val t = bekannt.map { it ?: 0.0 }
                abfahrt[0] = t[0]
                ankunft[0] = t[0]
                for (k in 0 until halte.size - 1) {
                    val luecke = max(t[k + 1] - abfahrt[k], 1.0)
                    val nat = max(natuerlich[k].last(), 0.5)
                    val letzter = k + 1 == halte.size - 1
                    var stand: Double
                    if (letzter && !endStand) {
                        stand = 0.0
                    } else {
                        val spiel = luecke - nat
                        stand = if (spiel >= 8.0) min(spiel, art.stand) else min(8.0, luecke * 0.25)
                        if (letzter) stand = min(stand, luecke * 0.4)
                    }
                    var fahren = luecke - stand
                    val langsamste = nat / 0.4
                    if (!letzter && fahren > langsamste) {
                        stand += fahren - langsamste
                        fahren = langsamste
                    }
                    fahrt[k] = fahren
                    ankunft[k + 1] = abfahrt[k] + fahren
                    abfahrt[k + 1] = ankunft[k + 1] + stand
                }
            } else {
                for (k in 0 until halte.size - 1) {
                    fahrt[k] = natuerlich[k].last()
                    ankunft[k + 1] = abfahrt[k] + fahrt[k]
                    abfahrt[k + 1] = ankunft[k + 1] + if (k + 1 == halte.size - 1) 0.0 else art.stand
                }
            }

            // Zeitleiste.
            val zt = ArrayList<Double>()
            val zm = ArrayList<Double>()
            zt += abfahrt[0]; zm += laengen[haltIndex[0]]
            for (k in 0 until halte.size - 1) {
                val i0 = haltIndex[k]
                val nat = natuerlich[k]
                val skala = if (nat.last() > 0) fahrt[k] / nat.last() else 0.0
                for (j in 1 until nat.size) { zt += abfahrt[k] + nat[j] * skala; zm += laengen[i0 + j] }
                if (nat.size <= 1) { zt += ankunft[k + 1]; zm += laengen[haltIndex[k + 1]] }
                if (abfahrt[k + 1] > ankunft[k + 1]) { zt += abfahrt[k + 1]; zm += laengen[haltIndex[k + 1]] }
            }
            val ts = ArrayList<Double>()
            val ms = ArrayList<Double>()
            for (i in zt.indices) {
                if (ts.isNotEmpty() && zt[i] <= ts.last()) { ms[ms.size - 1] = zm[i]; continue }
                ts += zt[i]; ms += zm[i]
            }
            return Fahrmodell(
                ursprung.lat, ursprung.lon, meterJeLon, xs, ys, laengen,
                DoubleArray(halte.size) { laengen[haltIndex[it]] }, ankunft, abfahrt, ts.toDoubleArray(), ms.toDoubleArray(),
            )
        }
    }
}

/**
 * Hält angezeigte Fahrzeuge ruhig, wenn sich ihr Fahrplan ändert (neue Echtzeit): Die Abweichung wird über etwa drei
 * Sekunden abgebaut, rückwärts fährt es nie; über 400 m gelten als echte Korrektur.
 */
class OepnvGlaettung {
    private data class Gezeigt(val meter: Double, val versatz: Double, val zeit: Double, val modell: Fahrmodell)

    private val gezeigt = HashMap<String, Gezeigt>()

    fun punkt(id: String, modell: Fahrmodell, jetztMs: Long): GeoPunkt {
        val t = jetztMs / 1000.0
        val ziel = modell.meter(t)
        var versatz = 0.0
        var weiter = ziel
        gezeigt[id]?.let { vorher ->
            val dt = (t - vorher.zeit).coerceIn(0.0, 2.0)
            versatz = if (vorher.modell === modell) vorher.versatz else vorher.meter - ziel
            if (abs(versatz) > 400) versatz = 0.0
            versatz *= exp(-dt / 3)
            if (abs(versatz) < 0.05) versatz = 0.0
            weiter = max(ziel + versatz, vorher.meter)
            versatz = weiter - ziel
        }
        gezeigt[id] = Gezeigt(weiter, versatz, t, modell)
        if (gezeigt.size > 300) gezeigt.clear()
        return modell.punkt(weiter)
    }
}
