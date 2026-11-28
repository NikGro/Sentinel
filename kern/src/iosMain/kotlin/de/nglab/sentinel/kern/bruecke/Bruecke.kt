package de.nglab.sentinel.kern.bruecke

import de.nglab.sentinel.kern.karte.Anzeige
import de.nglab.sentinel.kern.karte.Szene
import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.netz.Api
import de.nglab.sentinel.kern.netz.Verbindung
import de.nglab.sentinel.kern.netz.Verbindungszustand
import de.nglab.sentinel.kern.netz.plattformClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSData
import platform.Foundation.create
import platform.posix.memcpy

/**
 * Brücke für Swift (suspendierende Funktionen des Kerns erscheinen in Swift direkt als `async`): Beobachten über Rückrufe auf dem Hauptthread (SwiftUI übernimmt den Stand in ein beobachtbares
 * Objekt). `abmelden()` beendet die Beobachtung.
 */
class Abmelder internal constructor(private val auftrag: Job) {
    fun abmelden() = auftrag.cancel()
}

object Bruecke {
    /** Bereich auf dem Hauptthread für Verbindung und Beobachtung. */
    val hauptbereich: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    fun standBeobachten(lage: Lage, rueckruf: (LageStand) -> Unit): Abmelder =
        Abmelder(MainScope().launch { lage.stand.collect { rueckruf(it) } })

    fun verbindungBeobachten(verbindung: Verbindung, rueckruf: (Verbindungszustand) -> Unit): Abmelder =
        Abmelder(MainScope().launch { verbindung.zustand.collect { rueckruf(it) } })

    fun neueVerbindung(): Verbindung = Verbindung(Verbindung.httpClient(), hauptbereich)

    private val http by lazy { Verbindung.httpClient(plattformClient()) }

    fun api(server: String, token: String?): Api = Api(http, server, token)

    fun serverAdresse(eingabe: String): String? = Api.serverAdresse(eingabe)

    /** Kotlin-Bytes → `Data` (ein Kopiervorgang, nicht Byte für Byte über die Brücke). */
    @OptIn(ExperimentalForeignApi::class, kotlinx.cinterop.BetaInteropApi::class)
    fun alsData(b: ByteArray): NSData = if (b.isEmpty()) NSData() else b.usePinned { NSData.create(bytes = it.addressOf(0), length = b.size.toULong()) }

    /** `Data` → Kotlin-Bytes. */
    @OptIn(ExperimentalForeignApi::class)
    fun ausData(d: NSData): ByteArray {
        val b = ByteArray(d.length.toInt())
        if (b.isNotEmpty()) b.usePinned { memcpy(it.addressOf(0), d.bytes, d.length) }
        return b
    }

    /** Datenquellen der Karte (GeoJSON je Quelle) mit Auffächern bei der Zoomstufe `zoom`. */
    fun quellen(szene: Szene, stand: LageStand, jetztMs: Long, zoom: Double): Map<String, String> = szene.aufbauen(stand, jetztMs, Anzeige(), zoom)

    fun oepnvFahrzeuge(szene: Szene, stand: LageStand, jetztMs: Long): String = szene.oepnvFahrzeuge(stand, jetztMs, Anzeige())
}
