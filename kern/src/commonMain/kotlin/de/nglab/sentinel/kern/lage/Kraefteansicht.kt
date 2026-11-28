package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.modell.Fahnder
import de.nglab.sentinel.kern.modell.Fahrzeug
import de.nglab.sentinel.kern.modell.Versioniert

/** Texte und Auswahl für den Kräfte-Tab, gemeinsam für alle Plattformen. */
object Kraefteansicht {
    /** „Online · Fahrzeug P 35/24 · vor 2 min“ bzw. „Ruhemodus“. */
    fun status(stand: LageStand, f: Versioniert<Fahnder>, jetztMs: Long): String {
        if (!f.data.aktiv) return "Ruhemodus"
        val teile = ArrayList<String>()
        if (stand.einsatz.a?.memberId == f.id) teile += "A-Position"
        teile += if (stand.istOnline(f.id)) "Online" else "Nicht verbunden"
        teile += stand.fortbewegungText(f.data)
        stand.positionen[f.id]?.let { teile += Format.vor(it.ts, jetztMs) }
        return teile.joinToString(" · ")
    }

    /** „Im Einsatz · Besatzung: Adler, Bär“ bzw. „Nicht im Einsatz“. */
    fun fahrzeugStatus(stand: LageStand, v: Versioniert<Fahrzeug>): String {
        if (!stand.imEinsatz(v)) return "Nicht im Einsatz"
        val besatzung = stand.insassen(v.id).joinToString(", ") { it.data.spitzname }
        return if (besatzung.isBlank()) "Im Einsatz · unbesetzt" else "Im Einsatz · Besatzung: $besatzung"
    }

    /** Fahrzeuge, in die man einsteigen kann (im Einsatz). */
    fun waehlbareFahrzeuge(stand: LageStand): List<Versioniert<Fahrzeug>> = stand.fahrzeugeSortiert.filter { stand.imEinsatz(it) }

    /** Eigene Kraft zuerst, dann A, dann nach Name; Ruhemodus zuletzt. */
    fun sortiert(stand: LageStand): List<Versioniert<Fahnder>> = stand.kraefte.sortedWith(
        compareBy<Versioniert<Fahnder>> { !it.data.aktiv }
            .thenBy { it.id != stand.ichId }
            .thenBy { stand.einsatz.a?.memberId != it.id }
            .thenBy { Sortierung.text(it.data.spitzname) },
    )
}
