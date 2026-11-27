package de.nglab.sentinel.kern.karte

import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.BindungsArt
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.Fortbewegung
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Zielart
import de.nglab.sentinel.kern.oepnv.OepnvSimulation
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin

/**
 * Karten-Szene: übersetzt den Lagestand in GeoJSON für die Datenquellen des Kartenstils. Die Darstellung (Farben,
 * Größen, Beschriftung, Cluster) steht im Stil des Servers; iOS, Android und Web reichen nur diese Daten an die
 * Karten-Engine weiter. Jedes Objekt trägt `id` („art:kennung“) und `art`, damit ein Tipp über die Engine eindeutig
 * zum Objekt führt.
 */
object Quellen {
    const val SYMBOLE = "s-symbole"
    const val LINIEN = "s-linien"
    const val FLAECHEN = "s-flaechen"
    const val FLAECHEN_TEXT = "s-flaechen-text"
    const val HALTE = "s-halte"
    const val OEPNV_FAHRZEUGE = "s-oepnv-fahrzeuge"
    const val ICH = "s-ich"
    const val ROUTE = "s-route"
    const val SPUREN = "s-spuren"
    const val WEGZEIT = "s-wegzeit"
    const val BESTREIFUNG = "s-bestreifung"
    const val AUSWAHL = "s-auswahl"

    val alle = listOf(SYMBOLE, LINIEN, FLAECHEN, FLAECHEN_TEXT, HALTE, OEPNV_FAHRZEUGE, ICH, ROUTE, SPUREN, WEGZEIT, BESTREIFUNG, AUSWAHL)
}

/** Was auf der Karte angetippt werden kann. */
enum class Objektart(val schluessel: String) {
    Kraft("kraft"), Fahrzeug("fahrzeug"), Ziel("ziel"), Markierung("markierung"), OepnvFahrzeug("oepnv"), Halt("halt"), Spur("spur");

    companion object {
        fun von(s: String): Objektart? = entries.firstOrNull { it.schluessel == s }
    }
}

/** Kennung eines Kartenobjekts aus einem angetippten Merkmal (`id` = „art:kennung“). */
data class KartenObjekt(val art: Objektart, val id: String) {
    val schluessel: String get() = "${art.schluessel}:$id"

    companion object {
        fun von(schluessel: String): KartenObjekt? {
            val teile = schluessel.split(':', limit = 2)
            if (teile.size != 2) return null
            return Objektart.von(teile[0])?.let { KartenObjekt(it, teile[1]) }
        }
    }
}

/** Einstellungen dieses Geräts, die beeinflussen, was gezeigt wird. */
data class Anzeige(
    val ausgeblendeteEbenen: Set<String> = emptySet(),
    val ausgeblendeteZielarten: Set<Zielart> = emptySet(),
)

class Szene {
    private fun punkt(p: GeoPunkt): JsonObject = buildJsonObject {
        put("type", "Point")
        putJsonArray("coordinates") { add(JsonPrimitive(p.lon)); add(JsonPrimitive(p.lat)) }
    }

    private fun linie(punkte: List<GeoPunkt>): JsonObject = buildJsonObject {
        put("type", "LineString")
        put("coordinates", koordinaten(punkte))
    }

    private fun flaeche(punkte: List<GeoPunkt>): JsonObject = buildJsonObject {
        put("type", "Polygon")
        putJsonArray("coordinates") { add(koordinaten(if (punkte.first() == punkte.last()) punkte else punkte + punkte.first())) }
    }

    private fun koordinaten(punkte: List<GeoPunkt>): JsonArray = buildJsonArray {
        punkte.forEach { p -> add(buildJsonArray { add(JsonPrimitive(p.lon)); add(JsonPrimitive(p.lat)) }) }
    }

    private fun merkmal(geometrie: JsonObject, eigenschaften: JsonObject): JsonObject = buildJsonObject {
        put("type", "Feature")
        put("geometry", geometrie)
        put("properties", eigenschaften)
    }

    private fun sammlung(merkmale: List<JsonObject>): String = buildJsonObject {
        put("type", "FeatureCollection")
        put("features", JsonArray(merkmale))
    }.toString()

    /** Kreis als Vieleck (64 Ecken). */
    fun kreis(mitte: GeoPunkt, radius: Double): List<GeoPunkt> = (0..64).map { i ->
        val w = 2 * PI * i / 64
        GeoPunkt(mitte.lat + radius * cos(w) / 110_540, mitte.lon + radius * sin(w) / (111_320 * cos(mitte.lat * PI / 180)))
    }

    /** Pfeilspitze am letzten Punkt: zwei Schenkel, je etwa ein Fünftel der letzten Strecke (12 bis 60 m). */
    fun pfeilspitze(punkte: List<GeoPunkt>): List<GeoPunkt>? {
        if (punkte.size < 2) return null
        val ende = punkte.last()
        val vorher = punkte[punkte.size - 2]
        val laenge = (vorher.distanz(ende) / 5).coerceIn(12.0, 60.0)
        val richtung = ende.richtung(vorher) * PI / 180
        fun schenkel(w: Double) = GeoPunkt(
            ende.lat + laenge * cos(richtung + w) / 110_540,
            ende.lon + laenge * sin(richtung + w) / (111_320 * cos(ende.lat * PI / 180)),
        )
        return listOf(schenkel(0.45), ende, schenkel(-0.45))
    }

    /** Alle Datenquellen außer den bewegten (ÖPNV-Fahrzeuge, eigener Standort), als GeoJSON je Quelle. */
    fun aufbauen(lage: LageStand, jetztMs: Long, anzeige: Anzeige = Anzeige(), versatz: Map<String, Pair<Double, Double>> = emptyMap()): Map<String, String> {
        val symbole = ArrayList<JsonObject>()
        val linien = ArrayList<JsonObject>()
        val flaechen = ArrayList<JsonObject>()
        val flaechenText = ArrayList<JsonObject>()
        val halte = ArrayList<JsonObject>()

        fun symbol(objekt: KartenObjekt, p: GeoPunkt, sym: Symbol, farbe: String, titel: String, rang: Int, veraltet: Boolean = false, a: Boolean = false, live: Boolean = false) {
            val v = versatz[objekt.schluessel]
            symbole += merkmal(punkt(p), buildJsonObject {
                put("id", objekt.schluessel)
                put("art", objekt.art.schluessel)
                put("bild", sym.bildname)
                put("farbe", farbe)
                put("titel", titel)
                put("rang", rang)
                putJsonArray("versatz") { add(JsonPrimitive(v?.first ?: 0.0)); add(JsonPrimitive(v?.second ?: 0.0)) }
                // Name unter dem Symbol, in Schrifthöhen (12 pt), mit dem Symbol versetzt.
                putJsonArray("textversatz") { add(JsonPrimitive((v?.first ?: 0.0) / 12)); add(JsonPrimitive(1.6 + (v?.second ?: 0.0) / 12)) }
                put("versetzt", v != null)
                put("veraltet", veraltet)
                put("a", a)
                put("live", live)
            })
        }

        // Kräfte: zu Fuß bzw. im ÖPNV einzeln; im Fahrzeug erscheint das Fahrzeug samt Besatzung.
        val aId = lage.einsatz.a?.memberId
        for (f in lage.aktiveKraefte) {
            if (f.id == lage.ichId) continue
            val pos = lage.positionen[f.id] ?: continue
            if (f.data.fortbewegung == Fortbewegung.Fahrzeug && lage.fahrzeugVon(f.data) != null) continue
            val sym = if (f.data.fortbewegung == Fortbewegung.Oepnv) Symbol.Oepnv else Symbol.Fuss
            val veraltet = jetztMs - pos.ts > 120_000 || !lage.istOnline(f.id)
            symbol(KartenObjekt(Objektart.Kraft, f.id), pos.punkt, sym, Farben.KRAEFTE, lage.beschriftung(f.data), if (f.id == aId) 0 else 2, veraltet, f.id == aId)
        }
        for (fz in lage.fahrzeugeSortiert) {
            if (!lage.imEinsatz(fz)) continue
            val ortung = lage.ortung(fz) ?: continue
            val besatzung = lage.insassen(fz.id)
            val titel = if (besatzung.isEmpty()) fz.data.funkrufname else "${fz.data.funkrufname} (${besatzung.joinToString(", ") { it.data.spitzname }})"
            val mitA = besatzung.any { it.id == aId }
            symbol(KartenObjekt(Objektart.Fahrzeug, fz.id), ortung.punkt, Symbol.Fahrzeug, Farben.KRAEFTE, titel, if (mitA) 0 else 2, jetztMs - ortung.zeitMs > 300_000, mitA)
        }

        // Ziele: Zielperson in Zielfahrzeug oder Gebäude steckt darin (Name in dessen Beschriftung); im ÖPNV am Fahrzeug.
        for (z in lage.zieleSortiert) {
            if (!lage.zielSichtbar(z.id) || z.data.art in anzeige.ausgeblendeteZielarten) continue
            val bindung = z.data.bindung
            if (bindung != null && (bindung.art == BindungsArt.Fahrzeug || bindung.art == BindungsArt.Objekt) && bindung.zielId != null && lage.ziele[bindung.zielId] != null) continue
            val ortung = lage.ortung(z, jetztMs) ?: continue
            val mitfahrer = lage.mitfahrer(z.id).filter { it.data.bindung?.art != BindungsArt.Oepnv }
            val titel = buildString {
                append(z.data.anzeigename)
                if (mitfahrer.isNotEmpty()) append(" (").append(mitfahrer.joinToString(", ") { it.data.anzeigename }).append(")")
                if (bindung?.art == BindungsArt.Oepnv) lage.markierungen[bindung.zielId]?.data?.linie?.ref?.let { append(" (").append(it).append(")") }
            }
            val sym = when (z.data.art) {
                Zielart.Person -> if (bindung?.art == BindungsArt.Oepnv) Symbol.Oepnv else Symbol.Person
                Zielart.Fahrzeug -> Symbol.Zielfahrzeug
                Zielart.Objekt -> Symbol.Objekt
            }
            symbol(KartenObjekt(Objektart.Ziel, z.id), ortung.punkt, sym, Farben.ZIELE, titel, 1, live = lage.istLive(z))
        }

        // Markierungen
        for (m in lage.sichtbareMarkierungen(jetztMs, anzeige.ausgeblendeteEbenen)) {
            val d = m.data
            val objekt = KartenObjekt(Objektart.Markierung, m.id)
            val f = farbe(d.farbe)
            val props = buildJsonObject { put("id", objekt.schluessel); put("art", "markierung"); put("farbe", f); put("titel", d.titel); put("form", formName(d.typ)) }
            when (d.typ) {
                Form.Linie, Form.Pfeil -> {
                    linien += merkmal(linie(d.punkte), props)
                    if (d.typ == Form.Pfeil) pfeilspitze(d.punkte)?.let { linien += merkmal(linie(it), props) }
                }
                Form.Flaeche -> if (d.punkte.size >= 3) {
                    flaechen += merkmal(flaeche(d.punkte), props)
                    if (d.titel.isNotBlank()) flaechenText += merkmal(punkt(d.anker), props)
                }
                Form.Kreis, Form.Haltestellen, Form.Geofence -> {
                    val umriss = if (d.typ == Form.Geofence && d.radius == null && d.punkte.size >= 3) d.punkte else kreis(d.punkte.first(), d.radius ?: 100.0)
                    flaechen += merkmal(flaeche(umriss), props)
                    if (d.titel.isNotBlank()) flaechenText += merkmal(punkt(d.anker), props)
                }
                Form.OepnvLinie, Form.OepnvFahrzeug -> {
                    val strecke = if (d.weg.size >= 2) d.weg else d.punkte
                    val linienFarbe = d.linie?.farbe ?: f
                    if (d.zeigtStrecke && d.typ == Form.OepnvLinie) {
                        linien += merkmal(linie(strecke), buildJsonObject { put("id", objekt.schluessel); put("art", "markierung"); put("farbe", linienFarbe); put("titel", d.titel); put("form", "oepnv") })
                    }
                    if (d.zeigtHalte && d.typ == Form.OepnvLinie) d.punkte.forEachIndexed { i, p ->
                        halte += merkmal(punkt(p), buildJsonObject { put("id", objekt.schluessel); put("art", "markierung"); put("titel", d.haltNamen.getOrElse(i) { "" }); put("linie", d.linie?.ref ?: "") })
                    }
                }
                Form.Verlauf -> Unit // Spuren laden die Plattformen über `Spurszene`.
                else -> {
                    val sym = when (d.typ) {
                        Form.Text -> Symbol.Text
                        Form.Fahndungsraum -> Symbol.Fahndungsraum
                        Form.Haltestelle -> Symbol.Haltestelle
                        else -> Symbol.vonGespeichert(d.symbol)
                    }
                    val p = d.trackerId?.let { lage.trackerPositionen[it]?.punkt } ?: d.anker
                    symbol(objekt, p, sym, f, d.titel, 3)
                }
            }
        }

        return mapOf(
            Quellen.SYMBOLE to sammlung(symbole),
            Quellen.LINIEN to sammlung(linien),
            Quellen.FLAECHEN to sammlung(flaechen),
            Quellen.FLAECHEN_TEXT to sammlung(flaechenText),
            Quellen.HALTE to sammlung(halte),
        )
    }

    /** ÖPNV-Fahrzeuge zur Zeit `jetztMs` (für den schnellen Takt, eigene Quelle). */
    fun oepnvFahrzeuge(lage: LageStand, jetztMs: Long, anzeige: Anzeige = Anzeige()): String {
        val merkmale = ArrayList<JsonObject>()
        for (m in lage.sichtbareMarkierungen(jetztMs, anzeige.ausgeblendeteEbenen)) {
            val d = m.data
            if (!d.typ.istOepnv || !d.zeigtFahrzeug) continue
            // Sitzt eine Zielperson darin, steht ihr Symbol dort (siehe `aufbauen`); das Fahrzeug selbst entfällt.
            if (lage.mitfahrer(m.id).any { it.data.bindung?.art == BindungsArt.Oepnv }) continue
            if (d.typ == Form.OepnvFahrzeug || d.fahrt != null) {
                if (!OepnvSimulation.fahrzeugSichtbar(d, jetztMs)) continue
                val p = OepnvSimulation.punkt(d, jetztMs) ?: continue
                merkmale += merkmal(punkt(p), fahrzeugEigenschaften("markierung:${m.id}", d))
            }
            OepnvSimulation.taktFahrzeuge(d, jetztMs).forEach { (abfahrt, zustand) ->
                merkmale += merkmal(punkt(zustand.punkt), fahrzeugEigenschaften("oepnv:${m.id}@$abfahrt", d))
            }
        }
        return sammlung(merkmale)
    }

    private fun fahrzeugEigenschaften(id: String, d: Markierung): JsonObject = buildJsonObject {
        put("id", id)
        put("art", if (id.startsWith("markierung:")) "markierung" else "oepnv")
        put("titel", d.linie?.ref ?: "")
        put("farbe", d.linie?.farbe ?: farbe(d.farbe))
        put("typ", d.linie?.typ ?: "bus")
    }

    /** Eigener Standort: Punkt, Richtung (Grad) und Darstellung (punkt, fahrzeug, pfeil). */
    fun ich(p: GeoPunkt?, richtung: Double?, darstellung: String, mitA: Boolean): String =
        sammlung(listOfNotNull(p?.let {
            merkmal(punkt(it), buildJsonObject {
                put("id", "ich"); put("art", "ich"); put("richtung", richtung ?: 0.0); put("darstellung", darstellung); put("a", mitA)
            })
        }))

    private fun formName(f: Form): String = when (f) {
        Form.Linie -> "linie"
        Form.Pfeil -> "pfeil"
        Form.Flaeche -> "flaeche"
        Form.Kreis -> "kreis"
        Form.Haltestellen -> "haltestellen"
        Form.Geofence -> "geofence"
        else -> "punkt"
    }

    companion object {
        /** Meter je Bildpunkt bei einer Zoomstufe (Web-Mercator, 512er-Kacheln wie MapLibre). */
        fun meterJePunkt(zoom: Double, lat: Double): Double = 156_543.03 * cos(lat * PI / 180) / 2.0.pow(zoom + 1)
    }
}

/**
 * Auffächern übereinanderliegender Symbole nah herangezoomt: Gruppen dicht beieinander werden als Spalte neben dem
 * echten Ort gezeigt (Versatz in Bildpunkten, die Engine zeichnet und trifft dort). Herausgezoomt übernimmt der
 * Cluster der Engine. Feste Reihenfolge nach Kennung, damit beim Zoomen nichts die Plätze tauscht.
 */
object Auffaechern {
    const val ZEILE = 58.0
    const val SPALTE = 46.0
    /** Ab dieser Zoomstufe wird aufgefächert statt geclustert (wie `clusterMaxZoom` im Stil). */
    const val AB_ZOOM = 14.0

    fun versatz(punkte: List<Pair<String, GeoPunkt>>, zoom: Double): Map<String, Pair<Double, Double>> {
        if (zoom < AB_ZOOM || punkte.size < 2) return emptyMap()
        val mpp = Szene.meterJePunkt(zoom, punkte.first().second.lat)
        val schwelle = max(mpp, 0.05) * 44
        val gruppen = ArrayList<MutableList<Pair<String, GeoPunkt>>>()
        for (p in punkte) {
            val g = gruppen.firstOrNull { it.first().second.distanz(p.second) < schwelle }
            if (g != null) g += p else gruppen += mutableListOf(p)
        }
        val ergebnis = HashMap<String, Pair<Double, Double>>()
        for (g in gruppen) {
            if (g.size < 2) continue
            val sortiert = g.sortedBy { it.first }
            val spalten = if (sortiert.size <= 5) listOf(sortiert) else listOf(sortiert.take((sortiert.size + 1) / 2), sortiert.drop((sortiert.size + 1) / 2))
            spalten.forEachIndexed { s, spalte ->
                val x = if (s == 0) SPALTE else -SPALTE
                spalte.forEachIndexed { zeile, p -> ergebnis[p.first] = x to (zeile - (spalte.size - 1) / 2.0) * ZEILE }
            }
        }
        return ergebnis
    }
}
