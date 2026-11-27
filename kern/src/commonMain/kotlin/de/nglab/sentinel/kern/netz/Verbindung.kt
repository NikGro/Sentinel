package de.nglab.sentinel.kern.netz

import de.nglab.sentinel.kern.protokoll.Protokoll
import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.plugins.websocket.webSocketSession
import io.ktor.client.request.header
import io.ktor.websocket.CloseReason
import io.ktor.websocket.DefaultWebSocketSession
import io.ktor.websocket.Frame
import io.ktor.websocket.close
import io.ktor.websocket.readText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.trySendBlocking
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.min

enum class Verbindungszustand { Getrennt, Verbinde, Verbunden }

/** Anmeldung dieses Geräts am Server. */
data class Zugang(val server: String, val geraetId: String, val token: String)

/**
 * Dauerhafte Echtzeitverbindung (WebSocket) mit automatischem Wiederaufbau (1 s bis 30 s Pause) und Ping alle 25 s.
 * Ein Entzug des Zugangs durch den Server (Schließen mit 4401/4403) beendet die Verbindung endgültig.
 */
class Verbindung(
    private val client: HttpClient,
    private val bereich: CoroutineScope,
) {
    private val _zustand = MutableStateFlow(Verbindungszustand.Getrennt)
    val zustand: StateFlow<Verbindungszustand> = _zustand.asStateFlow()

    var beiNachricht: (String) -> Unit = {}
    var beiZugangEntzogen: () -> Unit = {}

    private var sitzung: DefaultWebSocketSession? = null
    private var auftrag: Job? = null

    fun starten(zugang: Zugang) {
        stoppen()
        auftrag = bereich.launch {
            var pause = 1_000L
            while (isActive) {
                _zustand.value = Verbindungszustand.Verbinde
                try {
                    val url = zugang.server.trimEnd('/').replace("https://", "wss://").replace("http://", "ws://") + "/api/v1/ws"
                    val s = client.webSocketSession(url) { header("Authorization", "Bearer ${zugang.token}") }
                    sitzung = s
                    _zustand.value = Verbindungszustand.Verbunden
                    pause = 1_000L
                    val ping = launch {
                        while (isActive) {
                            delay(25_000)
                            s.send(Frame.Text(Protokoll.PING))
                        }
                    }
                    for (frame in s.incoming) {
                        if (frame is Frame.Text) beiNachricht(frame.readText())
                    }
                    ping.cancel()
                    val grund = s.closeReason.await()
                    if (grund?.code == 4401.toShort() || grund?.code == 4403.toShort()) {
                        _zustand.value = Verbindungszustand.Getrennt
                        beiZugangEntzogen()
                        return@launch
                    }
                } catch (_: Throwable) {
                    // Netz weg oder Server nicht erreichbar: gleich erneut versuchen.
                }
                sitzung = null
                _zustand.value = Verbindungszustand.Getrennt
                if (!isActive) break
                delay(pause)
                pause = min(pause * 2, 30_000L)
            }
        }
    }

    fun stoppen() {
        auftrag?.cancel()
        auftrag = null
        val s = sitzung
        sitzung = null
        if (s != null) bereich.launch { runCatching { s.close(CloseReason(CloseReason.Codes.NORMAL, "Abgemeldet")) } }
        _zustand.value = Verbindungszustand.Getrennt
    }

    /** Sendet, wenn verbunden; `false`, wenn die Nachricht nicht abgeschickt werden konnte. */
    fun senden(text: String): Boolean {
        val s = sitzung ?: return false
        return s.outgoing.trySendBlocking(Frame.Text(text)).isSuccess
    }

    companion object {
        fun httpClient(basis: HttpClient = plattformClient()): HttpClient = basis.config { install(WebSockets) }
    }
}

/** HTTP-Client der Plattform (OkHttp auf Android/JVM, URLSession auf iOS). */
expect fun plattformClient(): HttpClient
