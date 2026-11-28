package de.nglab.sentinel.kern.navi

import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Fortbewegung
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.protokoll.json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put

/**
 * Navigation, gemeinsam für alle Plattformen. Den Weg legt der quelloffene Navigationskern Ferrostar (auf iOS und
 * Android dieselbe Version) auf die Straße und schaltet die Hinweise weiter; die Route rechnet der eigene Server
 * (Valhalla, mit Verkehrslage und Sperrungen von TomTom). Hier steht alles Übrige: wohin geführt wird, was der Server
 * zusätzlich erfährt, was er zurückmeldet, wann neu gerechnet wird und wie der Fortschritt angezeigt wird.
 */
sealed interface Naviziel {
    /** Wer gerade die A hält; wechselt die A, folgt die Führung der neuen Person. */
    data object APosition : Naviziel
    data class Objekt(val objekt: KartenObjekt) : Naviziel
    data class Ort(val punkt: GeoPunkt, val titel: String) : Naviziel
    /** Vorlauf: zur nächsten Kreuzung vor dem Ziel in seiner Fahrtrichtung (rückt mit). */
    data class Vorlauf(val ziel: Naviziel) : Naviziel
    /** Parallel: ebenfalls zur Kreuzung vor dem Ziel, aber über eine Nebenstrecke; seine Straße wird gemieden. */
    data class Parallel(val ziel: Naviziel) : Naviziel

    /** Das eigentliche Ziel, ohne Vorlauf bzw. Parallel. */
    val basis: Naviziel get() = when (this) {
        is Vorlauf -> ziel.basis
        is Parallel -> ziel.basis
        else -> this
    }
}

/** Aufgelöstes Ziel: Punkt, Titel und (bei Anschriften) die Straße, auf der angekommen werden soll. */
data class Zielort(val punkt: GeoPunkt, val titel: String, val strasse: String? = null)

object Navizielaufloesung {
    /** Aktueller Ort des Ziels; `null`, wenn es derzeit keine Position hat. */
    /**
     * Wie `aufloesen`, aber mit Vorlauf bzw. Parallel: dann die nächste Kreuzung vor dem Ziel (solange Richtung oder
     * Straße unbekannt sind, das Ziel selbst). Zweiter Wert: Hinweis für den Parallel-Modus.
     */
    suspend fun aufloesenMitVorlauf(ziel: Naviziel, stand: LageStand, jetztMs: Long, planer: Vorlaufplaner, api: de.nglab.sentinel.kern.netz.Api?): Pair<Zielort, Parallelhinweis?>? {
        if (ziel !is Naviziel.Vorlauf && ziel !is Naviziel.Parallel) return aufloesen(ziel, stand, jetztMs)?.let { it to null }
        val basis = ziel.basis
        val hier = aufloesen(basis, stand, jetztMs) ?: return null
        val schluessel = basis.toString()
        val k = planer.kreuzung(schluessel, hier.punkt, jetztMs, api)
        val hinweis = if (ziel is Naviziel.Parallel) planer.parallelhinweis(schluessel, k?.first) else null
        val ort = k?.let { Zielort(it.first, "Kreuzung ${it.second} vor ${hier.titel}") } ?: hier
        return ort to hinweis
    }

    fun aufloesen(ziel: Naviziel, stand: LageStand, jetztMs: Long): Zielort? = when (ziel) {
        is Naviziel.Vorlauf -> aufloesen(ziel.basis, stand, jetztMs)
        is Naviziel.Parallel -> aufloesen(ziel.basis, stand, jetztMs)
        Naviziel.APosition -> stand.aHalter?.let { a -> stand.positionen[a.id]?.let { Zielort(it.punkt, "A-Position (${a.data.spitzname})") } }
        is Naviziel.Ort -> Zielort(ziel.punkt, ziel.titel, Strassenname.aus(ziel.titel))
        is Naviziel.Objekt -> {
            val id = ziel.objekt.id
            when (ziel.objekt.art) {
                Objektart.Kraft -> stand.fahnder[id]?.let { f -> stand.positionen[id]?.let { Zielort(it.punkt, f.data.spitzname) } }
                Objektart.Fahrzeug -> stand.fahrzeuge[id]?.let { v -> stand.ortung(v)?.let { Zielort(it.punkt, v.data.funkrufname) } }
                Objektart.Ziel -> stand.ziele[id]?.let { z ->
                    stand.ortung(z, jetztMs)?.let { Zielort(it.punkt, z.data.anzeigename, Strassenname.aus(z.data.anschrift)) }
                }
                Objektart.Markierung -> stand.markierungen[id]?.let { m -> Zielort(stand.ortung(m.data, jetztMs), m.data.titel.ifBlank { "Markierung" }) }
                else -> null
            }
        }
    }

    fun fehlertext(ziel: Naviziel): String = when (ziel) {
        Naviziel.APosition -> "Niemand hält gerade die A."
        else -> "Ziel hat derzeit keine Position."
    }
}

/** Straßenname aus einer Anschrift („Musterstraße 3, 22391 Hamburg“ → „Musterstraße“); `null` ohne Hausnummer. */
object Strassenname {
    private val muster = Regex("""^(.+?)\s+\d+\s*[a-zA-Z]?(\s*[-/]\s*\d+\s*[a-zA-Z]?)?$""")

    fun aus(anschrift: String): String? {
        val erste = anschrift.split(',').first().trim()
        val s = muster.matchEntire(erste)?.groupValues?.get(1)?.trim() ?: return null
        return s.takeIf { it.length >= 3 }
    }
}

/** Was der Server zur Routenanfrage zusätzlich erfährt. */
data class Anfrageoptionen(val sonderrechte: Boolean, val zuFuss: Boolean, val zielstrasse: String? = null, val parallel: Parallelhinweis? = null)

object Routenanfrage {
    /**
     * Ergänzt die Anfrage, die Ferrostar im Valhalla-Format erzeugt: Sonderrechte (der Server wägt ab, ob sich der
     * Regelbruch lohnt), zu Fuß, und bei Anschriften die Straße am Ziel (Valhalla rastet dann auf dieser Straße ein,
     * nicht auf einer Nachbarstraße, die in Luftlinie näher am Gebäude liegt).
     */
    fun anpassen(body: String, o: Anfrageoptionen): String {
        val alt = runCatching { json.parseToJsonElement(body).jsonObject }.getOrNull() ?: return body
        val neu = alt.toMutableMap()
        neu["sentinel"] = buildJsonObject {
            put("sonderrechte", o.sonderrechte && !o.zuFuss)
            if (o.parallel != null && !o.zuFuss) put("parallel", buildJsonObject {
                put("lat", o.parallel.punkt.lat); put("lon", o.parallel.punkt.lon); put("kurs", o.parallel.kurs); put("meter", o.parallel.meter)
            })
        }
        if (o.zuFuss) neu["costing"] = JsonPrimitive("pedestrian")
        val orte = (alt["locations"] as? JsonArray)?.toMutableList()
        if (o.zielstrasse != null && !orte.isNullOrEmpty()) {
            val letzter = orte.last().jsonObject.toMutableMap()
            letzter["street"] = JsonPrimitive(o.zielstrasse)
            orte[orte.lastIndex] = JsonObject(letzter)
            neu["locations"] = JsonArray(orte)
        }
        return JsonObject(neu).toString()
    }

    /** Pfad der Routenanfrage am eigenen Server. */
    fun adresse(server: String): String = "${server.trimEnd('/')}/api/v1/navi/route"

    /** Fortbewegung → zu Fuß führen? */
    fun zuFuss(f: Fortbewegung?): Boolean = f == Fortbewegung.Fuss
}

/** Rückmeldung des Servers zur gelieferten Route (Kopfzeilen der Antwort). */
data class Routeninfo(
    val sonderrechte: Boolean = false,
    val gemieden: Boolean = false,
    /** Folgt die Route TomToms Weg mit Verkehrslage (Stau, Sperrung umfahren)? */
    val verkehr: Boolean = false,
    /** Verhältnis Fahrzeit mit Verkehr zu ohne; für eine ehrliche Ankunftszeit. */
    val verkehrsfaktor: Double = 1.0,
) {
    companion object {
        fun ausKopfzeilen(kopf: (String) -> String?): Routeninfo = Routeninfo(
            sonderrechte = kopf("x-sentinel-sonderrechte") == "1",
            gemieden = kopf("x-sentinel-parallel") == "1",
            verkehr = kopf("x-sentinel-verkehr") == "1",
            verkehrsfaktor = kopf("x-sentinel-verkehrsfaktor")?.toDoubleOrNull()?.coerceIn(1.0, 3.0) ?: 1.0,
        )
    }
}

/** Manöver mit Symbol je Plattform (SF Symbol, Material Symbol). */
enum class Manoever(val sf: String, val material: String) {
    Geradeaus("arrow.up", "straight"),
    Rechts("arrow.turn.up.right", "turn_right"),
    LeichtRechts("arrow.up.right", "turn_slight_right"),
    Links("arrow.turn.up.left", "turn_left"),
    LeichtLinks("arrow.up.left", "turn_slight_left"),
    Wenden("arrow.uturn.down", "u_turn_left"),
    Kreisverkehr("arrow.triangle.turn.up.right.circle", "roundabout_right"),
    Start("arrow.triangle.turn.up.right.diamond.fill", "navigation"),
    Ziel("flag.checkered", "sports_score");

    companion object {
        /** Aus Art und Richtung (OSRM-Begriffe, wie Ferrostar sie liefert, klein geschrieben, Leerzeichen erlaubt). */
        /** „slightRight“, „SLIGHT_RIGHT“, „slight-right“ → „slight right“ (Swift-, Kotlin- und OSRM-Schreibweise). */
        private fun norm(s: String?): String? = s?.replace(Regex("([a-z])([A-Z])"), "$1 $2")?.lowercase()?.replace("_", " ")?.replace("-", " ")?.trim()

        fun von(art: String?, richtung: String?): Manoever {
            val a = norm(art)
            when (a) {
                "arrive" -> return Ziel
                "depart" -> return Start
                "roundabout", "rotary", "roundabout turn", "exit roundabout", "exit rotary" -> return Kreisverkehr
            }
            return when (norm(richtung)) {
                "uturn", "u turn" -> Wenden
                "sharp right", "right" -> Rechts
                "slight right" -> LeichtRechts
                "slight left" -> LeichtLinks
                "left", "sharp left" -> Links
                else -> Geradeaus
            }
        }

        /** Pfeil für eine Fahrspur („left“, „slight right“, „straight“, …). */
        fun spur(richtung: String): Manoever = von(null, richtung)
    }
}

/** Eine Fahrspur am nächsten Manöver. */
data class Fahrspur(val richtungen: List<String>, val aktiv: Boolean) {
    val symbole: List<Manoever> get() = richtungen.map { Manoever.spur(it) }
}

/** Fortschritt auf der Route bezogen auf den eigenen Standort, fertig für die Anzeige. */
data class Fortschritt(
    val anweisung: String,
    val manoever: Manoever,
    val bisManoever: Double,
    val danach: String? = null,
    val danachManoever: Manoever? = null,
    val restMeter: Double,
    val restSekunden: Double,
    val spuren: List<Fahrspur> = emptyList(),
    val angekommen: Boolean = false,
) {
    fun ankunftMs(jetztMs: Long): Long = jetztMs + (restSekunden * 1000).toLong()

    companion object {
        val angekommenStand = Fortschritt("Ziel erreicht", Manoever.Ziel, 0.0, restMeter = 0.0, restSekunden = 0.0, angekommen = true)

        /**
         * Aus den Werten, die Ferrostar liefert. `faktor`: Verkehrsfaktor des Servers (Restzeit mit Verkehr).
         * Leere Anweisungen werden zu „Dem Straßenverlauf folgen“.
         */
        fun aus(
            anweisung: String?, art: String?, richtung: String?, bisManoever: Double,
            danach: String?, danachArt: String?, danachRichtung: String?,
            restMeter: Double, restSekunden: Double, faktor: Double, spuren: List<Fahrspur>,
        ): Fortschritt = Fortschritt(
            anweisung = anweisung?.takeIf { it.isNotBlank() } ?: "Dem Straßenverlauf folgen",
            manoever = Manoever.von(art, richtung),
            bisManoever = bisManoever,
            danach = danach?.takeIf { it.isNotBlank() },
            danachManoever = if (danach.isNullOrBlank()) null else Manoever.von(danachArt, danachRichtung),
            restMeter = restMeter,
            restSekunden = restSekunden * faktor,
            spuren = spuren,
        )
    }
}

/**
 * Wann neu gerechnet wird: beim Start, nach Abweichung (meldet Ferrostar), und wenn sich ein bewegtes Ziel um mehr
 * als 40 m bewegt hat, frühestens alle 8 s.
 */
class Nachfuehrung {
    private var gerechnetFuer: GeoPunkt? = null
    private var zuletztMs: Long = 0
    var noetig: Boolean = true
        private set

    fun faellig(ziel: GeoPunkt, jetztMs: Long): Boolean {
        if (noetig) return true
        val bewegt = gerechnetFuer?.let { it.distanz(ziel) > ZIEL_SCHWELLE_M } ?: true
        return bewegt && jetztMs - zuletztMs >= MINDESTABSTAND_MS
    }

    fun gerechnet(ziel: GeoPunkt, jetztMs: Long) {
        gerechnetFuer = ziel
        zuletztMs = jetztMs
        noetig = false
    }

    fun fehlgeschlagen() {
        noetig = true
    }

    fun zuruecksetzen() {
        gerechnetFuer = null
        zuletztMs = 0
        noetig = true
    }

    companion object {
        const val ZIEL_SCHWELLE_M = 40.0
        const val MINDESTABSTAND_MS = 8_000L
        /** Takt, in dem die Plattform das Ziel nachführt. */
        const val TAKT_MS = 2_000L
    }
}

/**
 * Noch zu fahrender Teil der Route: Die Linie beginnt am eigenen (auf die Route gelegten) Standort. Gesucht wird nur
 * vorwärts und höchstens 250 m voraus; bei einer Wende läge der Rückweg sonst schon näher als die Wendestelle.
 */
class Routenrest {
    private var route: List<GeoPunkt> = emptyList()
    private var index = 0

    fun rest(neueRoute: List<GeoPunkt>, ort: GeoPunkt?): List<GeoPunkt> {
        if (neueRoute !== route && neueRoute != route) {
            route = neueRoute
            index = 0
        }
        if (ort == null || route.size < 2) return route
        var bester = index
        var besterAbstand = Double.MAX_VALUE
        var bisher = 0.0
        var i = index
        while (i < route.size - 1 && bisher <= 250.0) {
            val d = abstandZuStrecke(ort, route[i], route[i + 1])
            if (d < besterAbstand) {
                besterAbstand = d
                bester = i
            }
            bisher += route[i].distanz(route[i + 1])
            i++
        }
        index = bester
        return listOf(ort) + route.drop(index + 1)
    }

    private fun abstandZuStrecke(p: GeoPunkt, a: GeoPunkt, b: GeoPunkt): Double {
        val kx = 111_320 * kotlin.math.cos(p.lat * kotlin.math.PI / 180)
        val ky = 110_540.0
        val ax = (a.lon - p.lon) * kx
        val ay = (a.lat - p.lat) * ky
        val dx = (b.lon - a.lon) * kx
        val dy = (b.lat - a.lat) * ky
        val l2 = dx * dx + dy * dy
        val t = if (l2 > 0) (-(ax * dx + ay * dy) / l2).coerceIn(0.0, 1.0) else 0.0
        return kotlin.math.hypot(ax + dx * t, ay + dy * t)
    }
}
