package de.nglab.sentinel.kern.oepnv

import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.karte.Szene
import de.nglab.sentinel.kern.lage.Kurzaktion
import de.nglab.sentinel.kern.lage.Kurzinfo
import de.nglab.sentinel.kern.lage.Kurzzeile
import de.nglab.sentinel.kern.karte.Symbol
import de.nglab.sentinel.kern.modell.Ebene
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Linienverweis
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.OepnvEbenen
import de.nglab.sentinel.kern.modell.OepnvFahrtDaten
import de.nglab.sentinel.kern.netz.Api
import de.nglab.sentinel.kern.protokoll.json
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

@Serializable
data class LiveHalt(val name: String, val stopId: String, val lat: Double, val lon: Double) {
    val punkt: GeoPunkt get() = GeoPunkt(lat, lon)
}

/** Ein fahrendes Fahrzeug auf einem Abschnitt zwischen zwei Halten (Transitous über den eigenen Server). */
@Serializable
data class LiveAbschnitt(
    val tripId: String,
    val name: String,
    val mode: String,
    val from: LiveHalt,
    val to: LiveHalt,
    val dep: Long,
    val arr: Long,
    val realTime: Boolean = false,
    val delay: Int? = null,
    val path: List<List<Double>> = emptyList(),
)

@Serializable
data class FahrtHalt(val name: String, val stopId: String, val lat: Double, val lon: Double, val arr: Long? = null, val dep: Long? = null) {
    val punkt: GeoPunkt get() = GeoPunkt(lat, lon)
}

@Serializable
data class Fahrt(
    val tripId: String,
    val name: String,
    val mode: String,
    val headsign: String = "",
    val color: String? = null,
    val stops: List<FahrtHalt> = emptyList(),
    val path: List<List<Double>> = emptyList(),
    val realTime: Boolean = false,
)

@Serializable
data class Abfahrt(
    val tripId: String,
    val name: String,
    val mode: String,
    val headsign: String = "",
    val time: Long,
    val scheduled: Long,
    val realTime: Boolean = false,
    val color: String? = null,
)

/** Verkehrsarten: OSM-Typ, Farbe und Symbol einer Linie (gleich auf allen Plattformen). */
object Linienart {
    fun typ(mode: String): String = when (mode) {
        "SUBWAY" -> "subway"
        "TRAM" -> "tram"
        "FERRY" -> "ferry"
        "SUBURBAN", "REGIONAL_RAIL", "RAIL" -> "train"
        else -> "bus"
    }

    /** Farbe nach Art und Liniennummer (S-Bahn grün, U-Bahn je Linie, Busse rot …), eigene Linienfarbe zuerst. */
    fun farbe(typ: String, ref: String, eigene: String? = null): String {
        if (eigene != null && Regex("^#?[0-9A-Fa-f]{6}$").matches(eigene)) {
            val h = (if (eigene.startsWith("#")) eigene else "#$eigene").uppercase()
            return if (h == "#FFFFFF") "#E2001A" else h
        }
        val r = ref.uppercase()
        return when {
            typ == "subway" || (typ == "bus" && r.startsWith("U")) -> when (r) {
                "U1" -> "#0066B3"; "U2" -> "#E2001A"; "U3" -> "#FFDD00"; "U4" -> "#00A8A8"; "U5" -> "#7C4A9A"; else -> "#0066B3"
            }
            typ == "train" && r.startsWith("S") -> "#00A651"
            typ == "bus" && r.startsWith("S") && r.length <= 3 -> "#00A651"
            typ == "train" -> "#6B6B6B"
            typ == "tram" -> "#C8102E"
            typ == "ferry" -> "#0095DA"
            else -> "#E2001A"
        }
    }

    fun titel(typ: String, ref: String): String = when (typ) {
        "subway" -> "U-Bahn $ref"
        "tram" -> "Straßenbahn $ref"
        "ferry" -> "Fähre $ref"
        "train" -> if (ref.uppercase().startsWith("S")) "S-Bahn $ref" else "Bahn $ref"
        else -> "Bus $ref"
    }

    fun verspaetung(delaySekunden: Int?, echtzeit: Boolean): String = when {
        !echtzeit -> "Fahrplan"
        delaySekunden == null -> "Echtzeit"
        delaySekunden < 60 -> "pünktlich"
        else -> "+${(delaySekunden + 30) / 60} Min."
    }
}

/**
 * ÖPNV live im Kartenausschnitt: Fahrzeuge und Haltestellen aus Transitous. Die Fahrzeuge fahren zwischen den Halten
 * flüssig über das Fahrmodell (gleich wie übernommene Strecken). Erst ab Zoom 12 (Fahrzeuge) bzw. 14 (Halte).
 */
class OepnvLive {
    var abschnitte: List<LiveAbschnitt> = emptyList()
        private set
    var halte: List<LiveHalt> = emptyList()
        private set
    /** Ausschnitt zu groß (herauszoomen zeigt keine Fahrzeuge). */
    var zuGross: Boolean = false
        private set

    private val szene = Szene()

    /** Daten für den Kartenausschnitt laden. Fehler lassen den letzten Stand stehen. */
    suspend fun laden(api: Api, sued: Double, west: Double, nord: Double, ost: Double, zoom: Double) {
        if (zoom < MIN_ZOOM_FAHRZEUGE) {
            abschnitte = emptyList(); halte = emptyList(); zuGross = false
            return
        }
        runCatching {
            val e = api.oepnvLive(sued, west, nord, ost, zoom.toInt()).jsonObject
            zuGross = e["zuGross"]?.jsonPrimitive?.boolean ?: false
            abschnitte = json.decodeFromJsonElement(ListSerializer(LiveAbschnitt.serializer()), e["fahrzeuge"]!!)
        }
        halte = if (zoom >= MIN_ZOOM_HALTE) runCatching {
            json.decodeFromJsonElement(ListSerializer(LiveHalt.serializer()), api.oepnvHaltestellenLive(sued, west, nord, ost).jsonObject["haltestellen"]!!)
        }.getOrDefault(halte) else emptyList()
    }

    fun leeren() {
        abschnitte = emptyList(); halte = emptyList(); zuGross = false
    }

    private fun weg(a: LiveAbschnitt): List<GeoPunkt> = a.path.filter { it.size >= 2 }.map { GeoPunkt(it[0], it[1]) }

    /** Position eines Fahrzeugs jetzt; `null` außerhalb seines Abschnitts. */
    fun position(a: LiveAbschnitt, jetztMs: Long): GeoPunkt? {
        if (jetztMs < a.dep - 30_000 || jetztMs > a.arr + 30_000) return null
        val typ = Linienart.typ(a.mode)
        val modell = Fahrmodell.abschnitt(a.from.punkt, a.to.punkt, weg(a), a.dep, a.arr, typ)
        return modell?.zustand(((jetztMs - a.dep) / 1000.0).coerceAtLeast(0.0))?.punkt ?: a.from.punkt
    }

    /** Merkmale der Fahrzeuge (für `s-oepnv-fahrzeuge`, gleiche Eigenschaften wie übernommene Fahrzeuge). */
    fun fahrzeugMerkmale(jetztMs: Long): List<JsonObject> = abschnitte.mapNotNull { a ->
        val p = position(a, jetztMs) ?: return@mapNotNull null
        val typ = Linienart.typ(a.mode)
        szene.merkmal(szene.punkt(p), buildJsonObject {
            put("id", "${Objektart.OepnvLive.schluessel}:${a.tripId}")
            put("art", Objektart.OepnvLive.schluessel)
            put("titel", a.name)
            put("farbe", Linienart.farbe(typ, a.name))
            put("typ", typ)
        })
    }

    /** Haltestellen als GeoJSON (Quelle `s-oepnv-live-halte`). */
    fun halteGeoJson(): String = szene.sammlung(halte.map { h ->
        szene.merkmal(szene.punkt(h.punkt), buildJsonObject {
            put("id", "${Objektart.HaltLive.schluessel}:${h.stopId}")
            put("art", Objektart.HaltLive.schluessel)
            put("titel", h.name)
        })
    })

    fun abschnitt(tripId: String): LiveAbschnitt? = abschnitte.firstOrNull { it.tripId == tripId }
    fun halt(stopId: String): LiveHalt? = halte.firstOrNull { it.stopId == stopId }

    /** Kurzübersicht eines Live-Fahrzeugs bzw. einer Haltestelle. */
    fun kurzinfo(objekt: KartenObjekt, jetztMs: Long): Kurzinfo? = when (objekt.art) {
        Objektart.OepnvLive -> abschnitt(objekt.id)?.let { a ->
            val typ = Linienart.typ(a.mode)
            Kurzinfo(
                titel = Linienart.titel(typ, a.name),
                untertitel = "${a.from.name} → ${a.to.name}",
                farbe = Linienart.farbe(typ, a.name),
                symbol = Symbol.Bahn,
                zeilen = listOf(
                    Kurzzeile("Abfahrt", Format.uhrzeit(a.dep)),
                    Kurzzeile("Ankunft", "${Format.uhrzeit(a.arr)} in ${a.to.name}"),
                    Kurzzeile("Stand", Linienart.verspaetung(a.delay, a.realTime)),
                ),
                ort = position(a, jetztMs),
                aktionen = listOf(Kurzaktion.Details, Kurzaktion.Hinfuehren),
            )
        }
        Objektart.HaltLive -> halt(objekt.id)?.let { h ->
            Kurzinfo(
                titel = h.name, untertitel = "Haltestelle", farbe = "#1E7A3C", symbol = Symbol.Haltestelle,
                zeilen = emptyList(), ort = h.punkt, aktionen = listOf(Kurzaktion.Details, Kurzaktion.Hinfuehren),
            )
        }
        else -> null
    }

    companion object {
        const val MIN_ZOOM_FAHRZEUGE = 12.0
        const val MIN_ZOOM_HALTE = 14.0
        /** Neu laden spätestens nach dieser Zeit (Fahrzeuge erreichen ihre nächsten Halte). */
        const val AKTUALISIEREN_MS = 20_000L

        suspend fun fahrt(api: Api, tripId: String): Fahrt? = runCatching { json.decodeFromJsonElement(Fahrt.serializer(), api.oepnvFahrt(tripId)) }.getOrNull()

        suspend fun abfahrten(api: Api, stopId: String): List<Abfahrt> = runCatching {
            json.decodeFromJsonElement(ListSerializer(Abfahrt.serializer()), api.oepnvAbfahrten(stopId).jsonObject["abfahrten"]!!)
        }.getOrDefault(emptyList())

        /**
         * Fahrt als ÖPNV-Strecke in die Lage übernehmen: Fahrzeug fährt nach echtem Fahrplan (der Server führt
         * Verspätungen nach); Strecke und Halte sind einzeln zuschaltbar. Nur das Fahrzeug: verschwindet nach Ankunft.
         */
        fun alsStrecke(f: Fahrt, fahrzeug: Boolean, strecke: Boolean, halte: Boolean, jetztMs: Long): Markierung? {
            if (f.stops.size < 2) return null
            val typ = Linienart.typ(f.mode)
            val zeiten = f.stops.map { it.dep ?: it.arr }
            return Markierung(
                layerId = Ebene.LAGE,
                typ = Form.OepnvLinie,
                titel = if (f.headsign.isBlank()) f.name else "${f.name} → ${f.headsign}",
                farbe = Linienart.farbe(typ, f.name, f.color),
                punkte = f.stops.map { it.punkt },
                zeit = zeiten.firstNotNullOfOrNull { it },
                linie = Linienverweis(id = f.tripId, ref = f.name, typ = typ, richtung = f.headsign),
                haltNamen = f.stops.map { it.name },
                weg = f.path.filter { it.size >= 2 }.map { GeoPunkt(it[0], it[1]) },
                fahrt = OepnvFahrtDaten(id = f.tripId, zeiten = zeiten, haltIds = f.stops.map { it.stopId }, echtzeit = f.realTime, stand = jetztMs),
                ebenen = OepnvEbenen(fahrzeug = fahrzeug, strecke = strecke, halte = halte),
                ablauf = if (fahrzeug && !strecke && !halte) zeiten.lastOrNull { it != null }?.plus(300_000) else null,
            )
        }

        fun alsHaltestelle(h: LiveHalt): Markierung =
            Markierung(layerId = Ebene.LAGE, typ = Form.Haltestelle, titel = h.name, farbe = "#0A84FF", punkte = listOf(h.punkt))
    }
}

/** Einsteigen in eine ÖPNV-Fahrt: selbst (Fortbewegung) oder eine Zielperson (Bindung an das Fahrzeug in der Lage). */
object Einsteigen {
    /** Eigene Fortbewegung „ÖPNV“ für diese Fahrt. */
    fun eigeneFahrt(f: Fahrt): de.nglab.sentinel.kern.modell.OepnvFahrt =
        de.nglab.sentinel.kern.modell.OepnvFahrt(linienId = f.tripId, linie = f.name, richtung = f.headsign)

    /** Zielpersonen, die einsteigen können. */
    fun personen(stand: de.nglab.sentinel.kern.lage.LageStand): List<de.nglab.sentinel.kern.modell.Versioniert<de.nglab.sentinel.kern.modell.Ziel>> =
        stand.zieleSortiert.filter { it.data.art == de.nglab.sentinel.kern.modell.Zielart.Person }

    /** Bereits übernommenes Fahrzeug derselben Fahrt (sonst wird es zum Einsteigen angelegt). */
    fun vorhandenesFahrzeug(stand: de.nglab.sentinel.kern.lage.LageStand, tripId: String): String? =
        stand.markierungen.entries.firstOrNull { it.value.data.typ.istOepnv && it.value.data.fahrt?.id == tripId }?.key

    /** Zielperson an das Fahrzeug binden (rückt mit, Symbol am Fahrzeug). */
    fun zielBinden(z: de.nglab.sentinel.kern.modell.Ziel, markierungId: String): de.nglab.sentinel.kern.modell.Ziel =
        z.copy(bindung = de.nglab.sentinel.kern.modell.Bindung(de.nglab.sentinel.kern.modell.BindungsArt.Oepnv, markierungId))
}
