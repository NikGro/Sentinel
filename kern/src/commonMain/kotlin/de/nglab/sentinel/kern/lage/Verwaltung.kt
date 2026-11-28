package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.Fahnder
import de.nglab.sentinel.kern.modell.Instanz
import de.nglab.sentinel.kern.modell.Versioniert

/** Instanzen, Pakete und eigenes Profil: Regeln und Texte, gemeinsam für alle Plattformen. */
object Verwaltung {
    /** Umbenennen und Löschen darf, wer die Instanz angelegt hat; die Hauptinstanz (KSOD) bleibt. */
    fun darfBearbeiten(stand: LageStand, i: Versioniert<Instanz>): Boolean =
        i.id != Instanz.HAUPT && (i.data.erstelltVon.isBlank() || i.data.erstelltVon == stand.ichId)

    fun darfVerlassen(i: Versioniert<Instanz>): Boolean = i.id != Instanz.HAUPT

    /** „3 Mitglieder · Geöffnet“ usw. */
    fun beschreibung(stand: LageStand, i: Versioniert<Instanz>): String = listOfNotNull(
        when (val n = i.data.mitglieder.size) { 0 -> null; 1 -> "1 Mitglied"; else -> "$n Mitglieder" },
        "Geöffnet".takeIf { i.id == stand.instanz && stand.imDienst },
        i.data.beschreibung.takeIf { it.isNotBlank() },
    ).joinToString(" · ")

    /** Name prüfen; `null` = in Ordnung. */
    fun nameFehlt(name: String): String? = when {
        name.isBlank() -> "Namen eingeben"
        name.trim().length > 60 -> "Höchstens 60 Zeichen"
        else -> null
    }

    /** Eigenes Profil ändern (für Plattformen ohne benannte Kopien, etwa Swift). */
    fun profil(f: Fahnder, name: String, spitzname: String, dienststelle: String, telefon: String): Fahnder =
        f.copy(name = name.trim().take(80), spitzname = spitzname.trim().take(40), dienststelle = dienststelle.trim().take(80), telefon = telefon.trim().take(40))

    fun profilFehlt(spitzname: String): String? = if (spitzname.isBlank()) "Spitznamen eingeben (so erscheinen Sie auf der Karte)" else null
}
