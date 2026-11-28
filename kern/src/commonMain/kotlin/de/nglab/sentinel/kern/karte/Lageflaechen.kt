package de.nglab.sentinel.kern.karte

import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.netz.Api
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/** Ebenen der Karte, die man zuschalten kann (gleich auf allen Plattformen). */
data class Kartenebenen(
    val verkehr: Boolean = false,
    val oepnvLive: Boolean = false,
    val wegZeitFuss: Boolean = true,
    val wegZeitKfz: Boolean = true,
    val wegZeitOepnv: Boolean = false,
    val bestreifung: Boolean = false,
    /** Grundkarte: „standard“ (eigene Karte) oder „satellit“ (Luftbild mit Straßen und Beschriftung). */
    val grundkarte: String = STANDARD,
    /** Gebäude in 3D; aus = flache Karte. */
    val dreiD: Boolean = true,
    val ausgeblendeteZielarten: Set<de.nglab.sentinel.kern.modell.Zielart> = emptySet(),
    val ausgeblendeteGruppen: Set<String> = emptySet(),
) {
    /** Stiladresse auf dem eigenen Server. */
    fun stilAdresse(server: String, dunkel: Boolean): String {
        val name = if (grundkarte == SATELLIT) "satellit" else if (dunkel) "dunkel" else "hell"
        return "$server/karte/stil/$name${if (dreiD) "" else "-flach"}.json"
    }

    /** Was die Szene ausblendet. */
    val anzeige: Anzeige get() = Anzeige(ausgeblendeteZielarten = ausgeblendeteZielarten, ausgeblendeteGruppen = ausgeblendeteGruppen)

    fun mitGrundkarte(g: String): Kartenebenen = copy(grundkarte = g)
    fun mitDreiD(an: Boolean): Kartenebenen = copy(dreiD = an)
    fun zielartAn(art: de.nglab.sentinel.kern.modell.Zielart): Boolean = art !in ausgeblendeteZielarten
    fun mitZielart(art: de.nglab.sentinel.kern.modell.Zielart, an: Boolean): Kartenebenen =
        copy(ausgeblendeteZielarten = if (an) ausgeblendeteZielarten - art else ausgeblendeteZielarten + art)
    fun gruppeAn(id: String): Boolean = id !in ausgeblendeteGruppen
    fun mitGruppe(id: String, an: Boolean): Kartenebenen = copy(ausgeblendeteGruppen = if (an) ausgeblendeteGruppen - id else ausgeblendeteGruppen + id)

    /** Etwas weicht von der Grundeinstellung ab (Knopf hervorheben). */
    val veraendert: Boolean get() = verkehr || oepnvLive || bestreifung || grundkarte != STANDARD || !dreiD || ausgeblendeteZielarten.isNotEmpty() || ausgeblendeteGruppen.isNotEmpty()

    val wegZeitModi: List<String> get() = listOfNotNull("fuss".takeIf { wegZeitFuss }, "kfz".takeIf { wegZeitKfz }, "oepnv".takeIf { wegZeitOepnv })

    /** Für Plattformen ohne benannte Kopien (Swift): eine Ebene umschalten. */
    fun mit(schluessel: String, an: Boolean): Kartenebenen = when (schluessel) {
        "verkehr" -> copy(verkehr = an)
        "oepnvLive" -> copy(oepnvLive = an)
        "wegZeitFuss" -> copy(wegZeitFuss = an)
        "wegZeitKfz" -> copy(wegZeitKfz = an)
        "wegZeitOepnv" -> copy(wegZeitOepnv = an)
        "bestreifung" -> copy(bestreifung = an)
        else -> this
    }

    fun an(schluessel: String): Boolean = when (schluessel) {
        "verkehr" -> verkehr
        "oepnvLive" -> oepnvLive
        "wegZeitFuss" -> wegZeitFuss
        "wegZeitKfz" -> wegZeitKfz
        "wegZeitOepnv" -> wegZeitOepnv
        "bestreifung" -> bestreifung
        else -> false
    }

    companion object {
        const val STANDARD = "standard"
        const val SATELLIT = "satellit"
        val standard: Kartenebenen = Kartenebenen()
        val grundkarten: List<Pair<String, String>> = listOf(STANDARD to "Karte", SATELLIT to "Satellit")
        val zielarten: List<Pair<de.nglab.sentinel.kern.modell.Zielart, String>> = listOf(
            de.nglab.sentinel.kern.modell.Zielart.Person to "Personen",
            de.nglab.sentinel.kern.modell.Zielart.Fahrzeug to "Fahrzeuge",
            de.nglab.sentinel.kern.modell.Zielart.Objekt to "Objekte",
        )

        /** Schalter in der Reihenfolge der Oberfläche: Schlüssel und Titel. */
        val schalter: List<Pair<String, String>> = listOf(
            "verkehr" to "Verkehr und Sperrungen",
            "oepnvLive" to "ÖPNV live",
            "bestreifung" to "Bestreifung",
            "wegZeitFuss" to "Weg-Zeit zu Fuß",
            "wegZeitKfz" to "Weg-Zeit Kfz",
            "wegZeitOepnv" to "Weg-Zeit ÖPNV",
        )
    }
}

/**
 * Weg-Zeit-Flächen um Sichtungen (wie weit kommt jemand seit der Sichtung zu Fuß, mit dem Kfz, mit dem ÖPNV) und
 * die Bestreifung (wo Kräfte schon waren). Lädt nach, solange die Ebenen an sind; Ergebnis als GeoJSON für
 * `s-wegzeit` und `s-bestreifung`.
 */
class Lageflaechen {
    private data class Flaeche(val modus: String, val ringe: List<List<GeoPunkt>>)
    private data class Eintrag(val minute: Long, val modi: List<String>, val flaechen: List<Flaeche>)
    private val wegZeit = HashMap<String, Eintrag>()
    private var bestreifungsLinien: List<List<Pair<GeoPunkt, Long>>> = emptyList()
    private var bestreifungGeladenMs = 0L

    /** Lädt nach, was fehlt oder veraltet ist (Weg-Zeit jede Minute, Bestreifung alle 60 s). `true` bei Änderung. */
    suspend fun aktualisieren(api: Api, stand: LageStand, ebenen: Kartenebenen, jetztMs: Long): Boolean {
        var geaendert = false
        val modi = ebenen.wegZeitModi
        val sichtungen = if (modi.isEmpty()) emptyList() else
            stand.sichtbareMarkierungen(jetztMs).filter { it.data.typ == Form.Fahndungsraum && it.data.zeit != null }
        if (wegZeit.keys.retainAll(sichtungen.map { it.id }.toSet())) geaendert = true
        for (s in sichtungen) {
            val minute = (jetztMs - s.data.zeit!!) / 60_000
            val alt = wegZeit[s.id]
            if (alt != null && alt.minute == minute && alt.modi == modi) continue
            val minuten = (minute.toDouble()).coerceIn(1.0, 24 * 60.0)
            runCatching {
                val antwort = api.wegZeit(s.data.anker, minuten, modi).jsonObject["flaechen"]!!.jsonArray
                antwort.map { f ->
                    val o = f.jsonObject
                    Flaeche(o["modus"]!!.jsonPrimitive.content, o["ringe"]!!.jsonArray.map { r -> r.jsonArray.map { p -> GeoPunkt(p.jsonArray[0].jsonPrimitive.double, p.jsonArray[1].jsonPrimitive.double) } })
                }
            }.onSuccess {
                wegZeit[s.id] = Eintrag(minute, modi, it)
                geaendert = true
            }
        }
        if (!ebenen.bestreifung) {
            if (bestreifungsLinien.isNotEmpty()) { bestreifungsLinien = emptyList(); geaendert = true }
        } else if (jetztMs - bestreifungGeladenMs >= 60_000) {
            runCatching {
                val tracks = api.bestreifung().jsonObject["tracks"]!!.jsonArray
                tracks.flatMap { t -> stuecke(t.jsonObject["punkte"]!!.jsonArray) }
            }.onSuccess {
                bestreifungsLinien = it
                bestreifungGeladenMs = jetztMs
                geaendert = true
            }
        }
        return geaendert
    }

    /** Spur einer Kraft in zusammenhängende Stücke (Pause über 3 min trennt). Punkte: [lat, lon, ts]. */
    private fun stuecke(punkte: JsonArray): List<List<Pair<GeoPunkt, Long>>> {
        val ergebnis = ArrayList<List<Pair<GeoPunkt, Long>>>()
        var aktuell = ArrayList<Pair<GeoPunkt, Long>>()
        for (p in punkte) {
            val a = p.jsonArray
            val punkt = GeoPunkt(a[0].jsonPrimitive.double, a[1].jsonPrimitive.double) to a[2].jsonPrimitive.double.toLong()
            if (aktuell.isNotEmpty() && punkt.second - aktuell.last().second > LUECKE_MS) {
                if (aktuell.size >= 2) ergebnis += aktuell
                aktuell = ArrayList()
            }
            aktuell += punkt
        }
        if (aktuell.size >= 2) ergebnis += aktuell
        return ergebnis
    }

    private val szene = Szene()

    fun wegZeitGeoJson(): String = szene.sammlung(wegZeit.values.flatMap { e ->
        e.flaechen.flatMap { f -> f.ringe.filter { it.size >= 3 }.map { ring -> szene.merkmal(szene.flaeche(ring), buildJsonObject { put("modus", f.modus) }) } }
    })

    /** Bestreifung: ältere Wege blasser (bis 6 Stunden zurück). */
    fun bestreifungGeoJson(jetztMs: Long): String = szene.sammlung(bestreifungsLinien.map { stueck ->
        val alter = (jetztMs - stueck.last().second).coerceAtLeast(0)
        val deckkraft = (0.45 - 0.3 * (alter / (6 * 3_600_000.0))).coerceIn(0.12, 0.45)
        szene.merkmal(szene.linie(stueck.map { it.first }), buildJsonObject { put("deckkraft", deckkraft) })
    })

    companion object {
        const val LUECKE_MS = 180_000L
        const val TAKT_MS = 20_000L
    }
}
