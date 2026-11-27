package de.nglab.sentinel.kern.protokoll

import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Einsatzzustand
import de.nglab.sentinel.kern.modell.Instanz
import de.nglab.sentinel.kern.modell.Position
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.serialisierer
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

// Echtzeit-Protokoll (WebSocket `/api/v1/ws`, JSON). Gegenstück: server/src/hub.ts.

val json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
    coerceInputValues = true
}

@Serializable
data class Akteur(val id: String, val role: String)

@Serializable
data class ServerInfo(val version: String, val routing: Boolean = false)

@Serializable
data class PositionEintrag(val id: String, val p: Position)

/** Vollständiger Zustand beim Verbindungsaufbau. Einzelne fehlerhafte Objekte werden übersprungen. */
data class Schnappschuss(
    val ich: Akteur,
    val server: ServerInfo,
    val online: List<String>,
    val objekte: Map<Art, List<Versioniert<Any>>>,
    val einsatz: Einsatzzustand,
    val positionen: List<PositionEintrag>,
    val trackerPositionen: List<PositionEintrag>,
    val instanz: String,
)

@Serializable
data class InstanzHinweis(val instanz: String, val name: String, val art: String, val memberId: String, val spitzname: String)

@Serializable
data class GeofenceAlarm(val annotationId: String, val titel: String, val zielId: String, val zielName: String, val art: String, val lat: Double, val lon: Double)

sealed interface ServerNachricht {
    data class Stand(val schnappschuss: Schnappschuss) : ServerNachricht
    data class Gesetzt(val art: Art, val objekt: Versioniert<Any>) : ServerNachricht
    data class Geloescht(val art: Art, val id: String) : ServerNachricht
    data class Einsatz(val zustand: Einsatzzustand) : ServerNachricht
    data class Ort(val id: String, val position: Position) : ServerNachricht
    data class TrackerOrt(val id: String, val position: Position) : ServerNachricht
    data class Online(val ids: List<String>) : ServerNachricht
    data class Hinweis(val hinweis: InstanzHinweis) : ServerNachricht
    data class Geofence(val alarm: GeofenceAlarm) : ServerNachricht
    data object BestreifungZurueckgesetzt : ServerNachricht
    data class Bestaetigt(val ref: String) : ServerNachricht
    data class Fehler(val ref: String?, val meldung: String) : ServerNachricht
    data object Pong : ServerNachricht
    data object Unbekannt : ServerNachricht
}

/** Schlüssel der Objektlisten im Schnappschuss. */
private val SCHNAPPSCHUSS_LISTEN = mapOf(
    "members" to Art.Fahnder, "vehicles" to Art.Fahrzeug, "annotations" to Art.Markierung, "targets" to Art.Ziel,
    "relations" to Art.Beziehung, "targetGroups" to Art.Zielgruppe, "trackers" to Art.Tracker, "layers" to Art.Ebene,
    "rooms" to Art.Raum, "messages" to Art.Nachricht, "instances" to Art.Instanz,
)

private fun versioniertSerializer(art: Art): KSerializer<Versioniert<Any>> = Versioniert.serializer(serialisierer(art))

private fun <T> nachsichtig(element: JsonElement?, lesen: (JsonElement) -> T): List<T> =
    (element as? JsonArray)?.mapNotNull { runCatching { lesen(it) }.getOrNull() } ?: emptyList()

object Protokoll {
    fun lesen(text: String): ServerNachricht = runCatching { lesen(json.parseToJsonElement(text).jsonObject) }.getOrElse { ServerNachricht.Unbekannt }

    private fun lesen(o: JsonObject): ServerNachricht {
        val t = o["t"]?.jsonPrimitive?.contentOrNull ?: return ServerNachricht.Unbekannt
        return when (t) {
            "snapshot" -> ServerNachricht.Stand(schnappschuss(o))
            "put" -> {
                val art = o["kind"]?.jsonPrimitive?.contentOrNull?.let(Art::von) ?: return ServerNachricht.Unbekannt
                val objekt = json.decodeFromJsonElement(versioniertSerializer(art), o["entity"] ?: return ServerNachricht.Unbekannt)
                ServerNachricht.Gesetzt(art, objekt)
            }
            "del" -> {
                val art = o["kind"]?.jsonPrimitive?.contentOrNull?.let(Art::von) ?: return ServerNachricht.Unbekannt
                ServerNachricht.Geloescht(art, o["id"]!!.jsonPrimitive.content)
            }
            "operation" -> ServerNachricht.Einsatz(json.decodeFromJsonElement(Einsatzzustand.serializer(), o["operation"]!!))
            "pos" -> json.decodeFromJsonElement(PositionEintrag.serializer(), o).let { ServerNachricht.Ort(it.id, it.p) }
            "tpos" -> json.decodeFromJsonElement(PositionEintrag.serializer(), o).let { ServerNachricht.TrackerOrt(it.id, it.p) }
            "online" -> ServerNachricht.Online(nachsichtig(o["ids"]) { it.jsonPrimitive.content })
            "hinweis" -> ServerNachricht.Hinweis(json.decodeFromJsonElement(InstanzHinweis.serializer(), o))
            "geofence" -> ServerNachricht.Geofence(json.decodeFromJsonElement(GeofenceAlarm.serializer(), o))
            "bestreifungReset" -> ServerNachricht.BestreifungZurueckgesetzt
            "ack" -> ServerNachricht.Bestaetigt(o["ref"]!!.jsonPrimitive.content)
            "err" -> ServerNachricht.Fehler(o["ref"]?.jsonPrimitive?.contentOrNull, o["message"]?.jsonPrimitive?.contentOrNull ?: "Unbekannter Fehler")
            "pong" -> ServerNachricht.Pong
            else -> ServerNachricht.Unbekannt
        }
    }

    private fun schnappschuss(o: JsonObject): Schnappschuss {
        val objekte = SCHNAPPSCHUSS_LISTEN.entries.associate { (schluessel, art) ->
            art to nachsichtig(o[schluessel]) { json.decodeFromJsonElement(versioniertSerializer(art), it) }
        }
        return Schnappschuss(
            ich = json.decodeFromJsonElement(Akteur.serializer(), o["self"]!!),
            server = json.decodeFromJsonElement(ServerInfo.serializer(), o["server"]!!),
            online = nachsichtig(o["online"]) { it.jsonPrimitive.content },
            objekte = objekte,
            einsatz = json.decodeFromJsonElement(Einsatzzustand.serializer(), o["operation"]!!),
            positionen = nachsichtig(o["positions"]) { json.decodeFromJsonElement(PositionEintrag.serializer(), it) },
            trackerPositionen = nachsichtig(o["trackerPositions"]) { json.decodeFromJsonElement(PositionEintrag.serializer(), it) },
            instanz = o["instanz"]?.jsonPrimitive?.contentOrNull ?: Instanz.HAUPT,
        )
    }

    // Ausgehend

    fun setzen(art: Art, id: String, daten: Any, ref: String): String = buildJsonObject {
        put("t", "put")
        put("kind", art.schluessel)
        put("id", id)
        put("data", json.encodeToJsonElement(serialisierer(art), daten))
        put("ref", ref)
    }.toString()

    fun loeschen(art: Art, id: String, ref: String): String = buildJsonObject {
        put("t", "del")
        put("kind", art.schluessel)
        put("id", id)
        put("ref", ref)
    }.toString()

    fun position(p: Position): String = buildJsonObject {
        put("t", "pos")
        put("p", json.encodeToJsonElement(Position.serializer(), p))
    }.toString()

    fun kommando(name: String, argumente: JsonObject = JsonObject(emptyMap()), ref: String): String = buildJsonObject {
        put("t", "cmd")
        put("name", name)
        put("args", argumente)
        put("ref", ref)
    }.toString()

    const val PING = """{"t":"ping"}"""
}
