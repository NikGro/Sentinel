package de.nglab.sentinel.kern.netz

import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.protokoll.json
import io.ktor.client.HttpClient
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.request
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsBytes
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpMethod
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray

/** Fehler beim Zugriff auf den Server, mit einer Meldung für die Oberfläche. */
class ApiFehler(val status: Int, override val message: String) : Exception(message) {
    val zugangEntzogen: Boolean get() = status == 401
}

@Serializable
data class Anmeldung(val deviceId: String, val token: String)

@Serializable
data class HochgeladeneDatei(val id: String, val mime: String, val groesse: Long)

@Serializable
data class Suchtreffer(val id: String, val titel: String, val untertitel: String, val punkt: GeoPunkt, val art: String, val exakt: Boolean = false)

@Serializable
data class Strassenbild(
    val quelle: String,
    val id: String,
    val punkt: GeoPunkt,
    val richtung: Double? = null,
    val aufgenommen: String? = null,
    val panorama: Boolean = false,
    val bild: String,
    val vorschau: String,
    val link: String,
    val urheber: String,
)

@Serializable
data class WegZeitFlaeche(val modus: String, val ringe: List<List<List<Double>>> = emptyList())

@Serializable
data class BestreifungsSpur(val memberId: String, val punkte: List<List<Double>> = emptyList())

/**
 * HTTP-Zugriff auf den eigenen Server. Ohne Zwischenspeicher auf der Platte, ohne Cookies; nur HTTPS (außer lokal).
 */
class Api(private val client: HttpClient, val server: String, private val token: String?) {

    companion object {
        /** Prüft und vereinheitlicht eine eingegebene Serveradresse; unverschlüsselte Adressen werden abgelehnt. */
        fun serverAdresse(eingabe: String): String? {
            var text = eingabe.trim()
            if (!text.contains("://")) text = "https://$text"
            text = text.trimEnd('/')
            val host = text.removePrefix("https://").substringBefore('/').substringBefore(':')
            return if (text.startsWith("https://") && host.isNotEmpty()) text else null
        }
    }

    private suspend fun anfrage(methode: HttpMethod, pfad: String, aufbau: HttpRequestBuilder.() -> Unit = {}): HttpResponse {
        val antwort = try {
            client.request("$server/$pfad") {
                method = methode
                token?.let { header("Authorization", "Bearer $it") }
                aufbau()
            }
        } catch (e: Throwable) {
            throw ApiFehler(0, "Server nicht erreichbar.")
        }
        if (!antwort.status.isSuccess()) {
            val meldung = runCatching { json.parseToJsonElement(antwort.bodyAsText()).jsonObject["fehler"]?.jsonPrimitive?.content }.getOrNull()
            throw ApiFehler(antwort.status.value, meldung ?: "Fehler ${antwort.status.value}")
        }
        return antwort
    }

    private suspend fun <T> lesen(s: KSerializer<T>, methode: HttpMethod, pfad: String, aufbau: HttpRequestBuilder.() -> Unit = {}): T =
        json.decodeFromString(s, anfrage(methode, pfad, aufbau).bodyAsText())

    private suspend fun element(methode: HttpMethod, pfad: String, aufbau: HttpRequestBuilder.() -> Unit = {}): JsonElement =
        json.parseToJsonElement(anfrage(methode, pfad, aufbau).bodyAsText())

    private fun HttpRequestBuilder.jsonInhalt(inhalt: JsonElement) {
        contentType(ContentType.Application.Json)
        setBody(inhalt.toString())
    }

    // Anmeldung

    suspend fun anmelden(code: String, geraet: String): Anmeldung = lesen(Anmeldung.serializer(), HttpMethod.Post, "api/v1/enroll") {
        jsonInhalt(buildJsonObject { put("code", code); put("geraet", geraet) })
    }

    /** Abmelden: Der Server sperrt dieses Gerät und entfernt das eigene Profil. */
    suspend fun abmelden() {
        anfrage(HttpMethod.Post, "api/v1/abmelden")
    }

    /** Ein bestehendes Profil (eines nicht verbundenen Geräts) übernehmen. */
    suspend fun profilUebernehmen(id: String) {
        anfrage(HttpMethod.Post, "api/v1/profil/uebernehmen") { jsonInhalt(buildJsonObject { put("id", id) }) }
    }

    // Dateien

    suspend fun hochladen(daten: ByteArray, mime: String): HochgeladeneDatei = lesen(HochgeladeneDatei.serializer(), HttpMethod.Post, "api/v1/blobs") {
        contentType(ContentType.parse(mime))
        setBody(daten)
    }

    suspend fun datei(id: String): ByteArray = anfrage(HttpMethod.Get, "api/v1/blobs/$id").bodyAsBytes()

    // Suche

    suspend fun suche(text: String, nahe: GeoPunkt?): List<Suchtreffer> {
        val e = element(HttpMethod.Get, "api/v1/suche") {
            parameter("q", text)
            nahe?.let { parameter("lat", it.lat); parameter("lon", it.lon) }
        }
        return json.decodeFromJsonElement(kotlinx.serialization.builtins.ListSerializer(Suchtreffer.serializer()), e.jsonObject["treffer"]!!)
    }

    suspend fun umkehr(p: GeoPunkt): Suchtreffer? {
        val e = element(HttpMethod.Get, "api/v1/suche/umkehr") { parameter("lat", p.lat); parameter("lon", p.lon) }
        val t = e.jsonObject["treffer"] ?: return null
        return runCatching { json.decodeFromJsonElement(Suchtreffer.serializer(), t) }.getOrNull()
    }

    suspend fun strassenbild(p: GeoPunkt): Strassenbild? {
        val e = element(HttpMethod.Get, "api/v1/strassenbild") { parameter("lat", p.lat); parameter("lon", p.lon) }
        val b = e.jsonObject["bild"] ?: return null
        return runCatching { json.decodeFromJsonElement(Strassenbild.serializer(), b) }.getOrNull()
    }

    // Straße und Tempolimit am Ort

    suspend fun strasse(p: GeoPunkt, kurs: Double?): String? {
        val e = element(HttpMethod.Get, "api/v1/strasse") {
            parameter("lat", p.lat); parameter("lon", p.lon)
            kurs?.let { parameter("kurs", it) }
        }
        return e.jsonObject["name"]?.jsonPrimitive?.content?.takeIf { it != "null" }
    }

    suspend fun tempolimit(p: GeoPunkt): Int? {
        val e = element(HttpMethod.Get, "api/v1/tempolimit") { parameter("lat", p.lat); parameter("lon", p.lon) }
        return e.jsonObject["kmh"]?.jsonPrimitive?.content?.toIntOrNull()
    }

    // Weg-Zeit, Bestreifung, Spuren

    suspend fun wegZeit(von: GeoPunkt, minuten: Double, modi: List<String>): JsonElement = element(HttpMethod.Post, "api/v1/reach") {
        jsonInhalt(buildJsonObject {
            put("lat", von.lat); put("lon", von.lon); put("minuten", minuten)
            putJsonArray("modi") { modi.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) } }
        })
    }

    suspend fun bestreifung(): JsonElement = element(HttpMethod.Get, "api/v1/coverage")

    suspend fun spur(art: String, id: String, vonMs: Long, bisMs: Long): JsonElement = element(HttpMethod.Get, "api/v1/spur") {
        parameter("art", art); parameter("id", id); parameter("von", vonMs); parameter("bis", bisMs)
    }

    // ÖPNV (Transitous über den eigenen Server)

    suspend fun oepnvLive(sued: Double, west: Double, nord: Double, ost: Double, zoom: Int): JsonElement = element(HttpMethod.Get, "api/v1/oepnv/live") {
        parameter("minLat", sued); parameter("minLon", west); parameter("maxLat", nord); parameter("maxLon", ost); parameter("zoom", zoom)
    }

    suspend fun oepnvHaltestellenLive(sued: Double, west: Double, nord: Double, ost: Double): JsonElement = element(HttpMethod.Get, "api/v1/oepnv/live/haltestellen") {
        parameter("minLat", sued); parameter("minLon", west); parameter("maxLat", nord); parameter("maxLon", ost)
    }

    suspend fun oepnvFahrt(id: String): JsonElement = element(HttpMethod.Get, "api/v1/oepnv/fahrt") { parameter("id", id) }
    suspend fun oepnvAbfahrten(haltId: String): JsonElement = element(HttpMethod.Get, "api/v1/oepnv/abfahrten") { parameter("halt", haltId) }
    suspend fun oepnvHaltestellenSuche(text: String, nahe: GeoPunkt?): JsonElement = element(HttpMethod.Get, "api/v1/oepnv/haltestellen/suche") {
        parameter("q", text)
        nahe?.let { parameter("lat", it.lat); parameter("lon", it.lon) }
    }
    suspend fun oepnvVerbindung(von: GeoPunkt, nach: GeoPunkt): JsonElement = element(HttpMethod.Get, "api/v1/oepnv/verbindung") {
        parameter("vonLat", von.lat); parameter("vonLon", von.lon); parameter("nachLat", nach.lat); parameter("nachLon", nach.lon)
    }

    // Tracker

    suspend fun trackerZustand(id: String): JsonElement = element(HttpMethod.Get, "api/v1/trackers/$id/status")
    suspend fun trackerBefehl(id: String, befehl: JsonElement): JsonElement = element(HttpMethod.Post, "api/v1/trackers/$id/befehl") { jsonInhalt(befehl) }
}
