package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.Fahnder
import de.nglab.sentinel.kern.modell.Fahrzeug
import de.nglab.sentinel.kern.modell.Versioniert

/** Fahrzeugflotte bearbeiten (Funkrufname, Kennzeichen, Bezeichnung, Foto, Tracker), gemeinsam für alle Plattformen. */
object Fahrzeugeditor {
    fun felder(): List<Zielfeld> = listOf(
        Zielfeld("funkrufname", "Funkrufname", "z. B. Adler 21/1"),
        Zielfeld("kennzeichen", "Kennzeichen", grossbuchstaben = true),
        Zielfeld("bezeichnung", "Fahrzeug", "z. B. VW Passat grau"),
    )

    fun wert(v: Fahrzeug, schluessel: String): String = when (schluessel) {
        "funkrufname" -> v.funkrufname
        "kennzeichen" -> v.kennzeichen
        "bezeichnung" -> v.zusatz
        else -> ""
    }

    fun setzen(v: Fahrzeug, schluessel: String, wert: String): Fahrzeug = when (schluessel) {
        "funkrufname" -> v.copy(funkrufname = wert)
        "kennzeichen" -> v.copy(kennzeichen = wert)
        "bezeichnung" -> v.copy(bezeichnung = wert, beschreibung = "")
        else -> v
    }

    fun neu(): Fahrzeug = Fahrzeug(funkrufname = "")

    fun fehlt(v: Fahrzeug): String? = if (v.funkrufname.isBlank()) "Funkrufname fehlt" else null

    fun fertig(v: Fahrzeug): Fahrzeug = v.copy(
        funkrufname = v.funkrufname.trim().take(40),
        kennzeichen = v.kennzeichen.trim().uppercase().take(20),
        bezeichnung = v.bezeichnung.trim().take(120),
    )

    fun mitTracker(v: Fahrzeug, trackerId: String?): Fahrzeug = v.copy(trackerId = trackerId)
    fun mitFoto(v: Fahrzeug, blobId: String?): Fahrzeug = v.copy(fotoBlob = blobId)
    fun mitAufzeichnung(v: Fahrzeug, an: Boolean): Fahrzeug = v.copy(aufzeichnung = an)
}

/** Suche im Kräfte-Tab: Kräfte nach Spitz- und Klarname, Dienststelle; Fahrzeuge nach Funkrufname, Kennzeichen. */
object Kraeftesuche {
    private fun worte(suche: String) = Sortierung.text(suche).split(' ').filter { it.isNotBlank() }

    fun kraft(f: Fahnder, suche: String): Boolean {
        val w = worte(suche)
        val text = Sortierung.text("${f.spitzname} ${f.name} ${f.dienststelle}")
        return w.all { it in text }
    }

    fun fahrzeug(v: Fahrzeug, suche: String): Boolean {
        val w = worte(suche)
        val text = Sortierung.text("${v.funkrufname} ${v.kennzeichen} ${v.kennzeichen.replace(" ", "").replace("-", "")} ${v.zusatz}")
        return w.all { it in text }
    }

    fun kraefte(stand: LageStand, suche: String): List<Versioniert<Fahnder>> = Kraefteansicht.sortiert(stand).filter { kraft(it.data, suche) }
    fun fahrzeuge(stand: LageStand, suche: String): List<Versioniert<Fahrzeug>> = stand.fahrzeugeSortiert.filter { fahrzeug(it.data, suche) }
}
