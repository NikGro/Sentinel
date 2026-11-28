package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.BindungsArt
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielgruppe

/** Ein Abschnitt der Zielliste: eine Gruppe (oder „Ohne Gruppe“) mit ihren Zielen. */
data class Zielabschnitt(val gruppeId: String?, val titel: String, val farbe: String?, val ziele: List<Versioniert<Ziel>>)

/**
 * Zielliste für alle Plattformen: Suche, Abschnitte nach Gruppen, Insassen, Auswahlmodus und Gruppen. Die Oberfläche
 * zeigt `abschnitte(stand, suche)` in dieser Reihenfolge.
 */
object Zielverzeichnis {
    /** Trifft ein Ziel den Suchtext (Name, Bezeichnung, Kennzeichen, Anschrift, Notizen)? Leerer Text trifft alles. */
    fun trifft(z: Ziel, suche: String): Boolean {
        val worte = Sortierung.text(suche).split(' ').filter { it.isNotBlank() }
        if (worte.isEmpty()) return true
        val text = Sortierung.text(listOf(z.anzeigename, z.vorname, z.nachname, z.bezeichnung, z.kennzeichen.replace(" ", "").replace("-", ""), z.kennzeichen, z.anschrift, z.hinweise).joinToString(" "))
        return worte.all { it in text }
    }

    fun abschnitte(stand: LageStand, suche: String = ""): List<Zielabschnitt> {
        val ziele = stand.zieleSortiert.filter { trifft(it.data, suche) }
        val liste = ArrayList<Zielabschnitt>()
        for (g in stand.zielgruppenSortiert) {
            val drin = ziele.filter { it.data.gruppeId == g.id }
            // Leere Gruppen nur ohne Suche (damit man sie sieht und bearbeiten kann)
            if (drin.isNotEmpty() || suche.isBlank()) liste += Zielabschnitt(g.id, g.data.name, g.data.farbe, drin)
        }
        val ohne = ziele.filter { it.data.gruppeId == null || stand.zielgruppen[it.data.gruppeId] == null }
        if (ohne.isNotEmpty()) liste += Zielabschnitt(null, if (stand.zielgruppen.isEmpty()) "Ziele" else "Ohne Gruppe", null, ohne)
        return liste
    }

    /** Personen, die in diesem Zielfahrzeug bzw. Zielobjekt sind. */
    fun insassen(stand: LageStand, zielId: String): List<Versioniert<Ziel>> = stand.zieleSortiert.filter {
        val b = it.data.bindung
        b != null && b.zielId == zielId && (b.art == BindungsArt.Fahrzeug || b.art == BindungsArt.Objekt)
    }

    /** Änderungen, um mehrere Ziele einer Gruppe zuzuordnen (`null` = aus der Gruppe nehmen). Unveränderte fallen weg. */
    fun zuordnen(stand: LageStand, ids: List<String>, gruppeId: String?): List<Pair<String, Ziel>> =
        ids.mapNotNull { id -> stand.ziele[id]?.takeIf { it.data.gruppeId != gruppeId }?.let { id to it.data.copy(gruppeId = gruppeId) } }

    /** Alle Ziele, die beim Löschen einer Gruppe aus ihr herausfallen. */
    fun gruppeLoesen(stand: LageStand, gruppeId: String): List<Pair<String, Ziel>> =
        zuordnen(stand, stand.ziele.values.filter { it.data.gruppeId == gruppeId }.map { it.id }, null)
}

/** Gruppen anlegen und bearbeiten: Name und Farbe. */
object Zielgruppen {
    val farben: List<String> = listOf("#0A84FF", "#30D158", "#FF9F0A", "#FF453A", "#BF5AF2", "#64D2FF", "#FFD60A", "#8E8E93")

    fun neu(name: String, farbe: String = farben.first()): Zielgruppe = Zielgruppe(name = name.trim().take(60), farbe = farbe)

    fun aendern(g: Zielgruppe, name: String, farbe: String): Zielgruppe = g.copy(name = name.trim().take(60), farbe = farbe)

    fun gueltig(name: String): Boolean = name.isNotBlank()

    /** Nächste noch nicht benutzte Farbe als Vorschlag. */
    fun vorschlag(stand: LageStand): String {
        val benutzt = stand.zielgruppen.values.map { it.data.farbe }.toSet()
        return farben.firstOrNull { it !in benutzt } ?: farben.first()
    }
}
