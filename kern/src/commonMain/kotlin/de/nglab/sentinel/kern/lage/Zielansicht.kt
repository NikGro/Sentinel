package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.Beziehung
import de.nglab.sentinel.kern.modell.BeziehungsStatus
import de.nglab.sentinel.kern.modell.Bindung
import de.nglab.sentinel.kern.modell.BindungsArt
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Standortquelle
import de.nglab.sentinel.kern.modell.ZeitPunkt
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielart

/** Ein Eingabefeld der Zielansicht. */
data class Zielfeld(
    val schluessel: String,
    val titel: String,
    val hinweis: String = "",
    val mehrzeilig: Boolean = false,
    val grossbuchstaben: Boolean = false,
)

/**
 * Felder, Prüfung und Änderungen eines Ziels, gemeinsam für alle Plattformen. Die Oberfläche zeigt `felder(art)` in
 * dieser Reihenfolge und liest bzw. schreibt über `wert` und `setzen`; so sind Felder und Begriffe überall gleich.
 */
object Zieleditor {
    fun felder(art: Zielart): List<Zielfeld> = when (art) {
        Zielart.Person -> listOf(
            Zielfeld("vorname", "Vorname"),
            Zielfeld("nachname", "Nachname"),
            Zielfeld("bezeichnung", "Bezeichnung", "falls der Name unbekannt ist"),
            Zielfeld("geburtsdatum", "Geburtsdatum", "TT.MM.JJJJ"),
            Zielfeld("geburtsort", "Geburtsort"),
            Zielfeld("staatsangehoerigkeit", "Staatsangehörigkeit"),
            Zielfeld("anschrift", "Anschrift"),
        )
        Zielart.Fahrzeug -> listOf(
            Zielfeld("kennzeichen", "Kennzeichen", grossbuchstaben = true),
            Zielfeld("bezeichnung", "Fahrzeug", "z. B. BMW 3er dunkelblau"),
        )
        Zielart.Objekt -> listOf(
            Zielfeld("bezeichnung", "Objekt", "z. B. Mehrfamilienhaus, Firmengebäude"),
            Zielfeld("anschrift", "Anschrift"),
        )
    } + Zielfeld("hinweise", "Notizen", mehrzeilig = true)

    fun wert(z: Ziel, schluessel: String): String = when (schluessel) {
        "vorname" -> z.vorname
        "nachname" -> z.nachname
        "bezeichnung" -> z.bezeichnung
        "geburtsdatum" -> z.geburtsdatum?.let(::datumAnzeigen) ?: ""
        "geburtsort" -> z.geburtsort
        "staatsangehoerigkeit" -> z.staatsangehoerigkeit
        "anschrift" -> z.anschrift
        "kennzeichen" -> z.kennzeichen
        "hinweise" -> z.freitext
        else -> ""
    }

    /** Setzt ein Feld. Das Geburtsdatum wird erst beim Sichern geprüft (`fehlt`), bis dahin als Eingabe gehalten. */
    fun setzen(z: Ziel, schluessel: String, wert: String): Ziel = when (schluessel) {
        "vorname" -> z.copy(vorname = wert)
        "nachname" -> z.copy(nachname = wert)
        "bezeichnung" -> z.copy(bezeichnung = wert)
        "geburtsdatum" -> z.copy(geburtsdatum = wert.ifBlank { null })
        "geburtsort" -> z.copy(geburtsort = wert)
        "staatsangehoerigkeit" -> z.copy(staatsangehoerigkeit = wert)
        "anschrift" -> z.copy(anschrift = wert)
        "kennzeichen" -> z.copy(kennzeichen = wert)
        // Ältere Stände mit getrennten Freitexten gehen in die Notizen über.
        "hinweise" -> z.copy(hinweise = wert, merkmale = "", fahrzeugBeschreibung = "", sachverhalt = "", massnahmen = "")
        else -> z
    }

    /** Was zum Sichern fehlt; `null` = sicherbar. */
    fun fehlt(z: Ziel): String? {
        val g = z.geburtsdatum
        if (g != null && datumSpeichern(g) == null) return "Geburtsdatum prüfen (TT.MM.JJJJ)"
        return null
    }

    /** Bereinigter Stand zum Senden. */
    fun fertig(z: Ziel): Ziel = z.copy(
        vorname = z.vorname.trim().take(80),
        nachname = z.nachname.trim().take(80),
        bezeichnung = z.bezeichnung.trim().take(120),
        geburtsdatum = z.geburtsdatum?.let(::datumSpeichern),
        geburtsort = z.geburtsort.trim().take(80),
        staatsangehoerigkeit = z.staatsangehoerigkeit.trim().take(80),
        anschrift = z.anschrift.trim().take(200),
        kennzeichen = z.kennzeichen.trim().uppercase().take(20),
        hinweise = z.hinweise.take(4000),
    )

    /** „1990-05-03“ → „03.05.1990“; Eingaben im Anzeigeformat bleiben, wie sie sind. */
    fun datumAnzeigen(gespeichert: String): String {
        val m = Regex("""^(\d{4})-(\d{2})-(\d{2})$""").matchEntire(gespeichert) ?: return gespeichert
        val (j, mo, t) = m.destructured
        return "$t.$mo.$j"
    }

    /** „3.5.1990“ oder „1990-05-03“ → „1990-05-03“; `null`, wenn kein gültiges Datum. */
    fun datumSpeichern(eingabe: String): String? {
        val e = eingabe.trim()
        Regex("""^(\d{4})-(\d{2})-(\d{2})$""").matchEntire(e)?.let { return if (gueltig(it.groupValues[1].toInt(), it.groupValues[2].toInt(), it.groupValues[3].toInt())) e else null }
        val m = Regex("""^(\d{1,2})\.(\d{1,2})\.(\d{4})$""").matchEntire(e) ?: return null
        val t = m.groupValues[1].toInt()
        val mo = m.groupValues[2].toInt()
        val j = m.groupValues[3].toInt()
        if (!gueltig(j, mo, t)) return null
        return "$j-${mo.toString().padStart(2, '0')}-${t.toString().padStart(2, '0')}"
    }

    private fun gueltig(j: Int, m: Int, t: Int): Boolean {
        if (j !in 1900..2100 || m !in 1..12 || t < 1) return false
        val tage = intArrayOf(31, if (j % 4 == 0 && (j % 100 != 0 || j % 400 == 0)) 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
        return t <= tage[m - 1]
    }

    /** Alter in Jahren zu einem gespeicherten Geburtsdatum am Stichtag (Jahr, Monat, Tag). */
    fun alter(geburtsdatum: String?, jahr: Int, monat: Int, tag: Int): Int? {
        val g = geburtsdatum?.let(::datumSpeichern) ?: return null
        val (j, m, t) = g.split('-').map { it.toInt() }
        var a = jahr - j
        if (monat < m || (monat == m && tag < t)) a--
        return a.takeIf { it in 0..130 }
    }

    // Standort

    /** Standortquelle wählen; Tracker nur mit Kennung. Von Hand behält den letzten Ort. */
    fun mitQuelle(z: Ziel, quelle: Standortquelle, trackerId: String?): Ziel = when (quelle) {
        Standortquelle.Tracker -> z.copy(quelle = quelle, trackerId = trackerId ?: z.trackerId)
        else -> z.copy(quelle = quelle)
    }

    fun quellen(z: Ziel): List<Standortquelle> =
        if (z.kannLiveQuelle) listOf(Standortquelle.Hand, Standortquelle.APosition, Standortquelle.Tracker) else listOf(Standortquelle.Hand)

    fun quelleTitel(q: Standortquelle): String = when (q) {
        Standortquelle.Hand -> "Von Hand"
        Standortquelle.APosition -> "Folgt der A-Position"
        Standortquelle.Tracker -> "Tracker"
    }

    // Unterwegs (nur Personen): zu Fuß, im Zielfahrzeug, im ÖPNV, im Gebäude

    /** Mögliche Bindungen einer Person: Zielfahrzeuge, Zielobjekte und ÖPNV-Fahrzeuge der Lage. */
    fun bindungsziele(stand: LageStand, zielId: String): List<Bindungsziel> {
        val z = stand.ziele[zielId]?.data ?: return emptyList()
        if (z.art != Zielart.Person) return emptyList()
        val liste = ArrayList<Bindungsziel>()
        liste += Bindungsziel(BindungsArt.Fuss, null, "Zu Fuß")
        for (v in stand.zieleSortiert) {
            if (v.id == zielId) continue
            when (v.data.art) {
                Zielart.Fahrzeug -> liste += Bindungsziel(BindungsArt.Fahrzeug, v.id, "Im Fahrzeug ${v.data.anzeigename}")
                Zielart.Objekt -> liste += Bindungsziel(BindungsArt.Objekt, v.id, "Im Gebäude ${v.data.anzeigename}")
                Zielart.Person -> Unit
            }
        }
        for (m in stand.markierungen.values.sortedBy { it.data.titel }) {
            if (m.data.typ == Form.OepnvFahrzeug || (m.data.typ == Form.OepnvLinie && m.data.fahrt != null)) {
                liste += Bindungsziel(BindungsArt.Oepnv, m.id, "Im ÖPNV ${m.data.linie?.ref?.ifBlank { null } ?: m.data.titel.ifBlank { "Fahrzeug" }}")
            }
        }
        return liste
    }

    /** Einsteigen bzw. Aussteigen. Beim Aussteigen bleibt die Person dort, wo das Fahrzeug gerade ist. */
    fun binden(stand: LageStand, zielId: String, b: Bindungsziel, jetztMs: Long): Ziel? {
        val v = stand.ziele[zielId] ?: return null
        if (b.art == BindungsArt.Fuss) {
            val hier = stand.ortung(v, jetztMs)?.punkt
            return v.data.copy(
                bindung = null,
                quelle = Standortquelle.Hand,
                standort = hier?.let { ZeitPunkt(it.lat, it.lon, jetztMs) } ?: v.data.standort,
            )
        }
        return v.data.copy(bindung = Bindung(b.art, b.zielId))
    }

    /** Aktuelle Bindung als Auswahl (für die Anzeige). */
    fun aktuelleBindung(stand: LageStand, zielId: String): Bindungsziel? {
        val b = stand.ziele[zielId]?.data?.bindung
        return bindungsziele(stand, zielId).firstOrNull { if (b == null || b.art == BindungsArt.Fuss) it.art == BindungsArt.Fuss else it.art == b.art && it.zielId == b.zielId }
    }

    /** Standortaufzeichnung (Verlauf) für dieses Ziel an oder aus. */
    fun mitAufzeichnung(z: Ziel, an: Boolean): Ziel = z.copy(aufzeichnung = an)

    /** Anschrift aus einem Suchtreffer übernehmen und den Standort dorthin setzen. */
    fun anschriftUebernehmen(z: Ziel, t: de.nglab.sentinel.kern.netz.Suchtreffer, jetztMs: Long): Ziel =
        standortSetzen(z.copy(anschrift = listOf(t.titel, t.untertitel).filter { it.isNotBlank() }.joinToString(", ")), t.punkt, jetztMs)

    /** Felder, unter denen Anschriftsvorschläge erscheinen. */
    fun mitVorschlaegen(schluessel: String): Boolean = schluessel == "anschrift"

    /** Gruppe setzen (für Plattformen ohne benannte Kopien, etwa Swift). */
    fun mitGruppe(z: Ziel, gruppeId: String?): Ziel = z.copy(gruppeId = gruppeId)

    /** Bindung, Quelle und Ort aus einem neueren Stand übernehmen, ohne andere offene Änderungen zu verlieren. */
    fun ortUebernehmen(z: Ziel, von: Ziel): Ziel = z.copy(bindung = von.bindung, quelle = von.quelle, standort = von.standort)

    // Standort von Hand an einem Punkt (Platzierung, Suche)
    fun standortSetzen(z: Ziel, p: GeoPunkt, jetztMs: Long): Ziel = z.copy(quelle = Standortquelle.Hand, standort = ZeitPunkt(p.lat, p.lon, jetztMs))
}

data class Bindungsziel(val art: BindungsArt, val zielId: String?, val titel: String) {
    val schluessel: String get() = "${art.name}:${zielId ?: ""}"
}

/** Beziehungen zwischen Zielen (Halter, Fahrer, Bewohner …), von beiden Seiten sichtbar. */
object Beziehungen {
    val vorschlaege: List<String> = listOf("Halter", "Fahrer", "Bewohner", "Kontaktperson", "Arbeitsstelle", "Familie")

    fun neu(von: String, nach: String, bezeichnung: String, ich: String?): Beziehung =
        Beziehung(von = von, nach = nach, bezeichnung = bezeichnung.trim().take(80), status = BeziehungsStatus.Bestaetigt, herkunft = ich ?: "")

    /** Ziele, die noch nicht mit `zielId` verbunden sind. */
    fun kandidaten(stand: LageStand, zielId: String): List<de.nglab.sentinel.kern.modell.Versioniert<Ziel>> {
        val verbunden = stand.verbundeneZiele(zielId).map { it.anderes.id }.toSet()
        return stand.zieleSortiert.filter { it.id != zielId && it.id !in verbunden }
    }

    fun statusTitel(s: BeziehungsStatus): String = when (s) {
        BeziehungsStatus.Vermutet -> "Vermutet"
        BeziehungsStatus.Bestaetigt -> "Bestätigt"
        BeziehungsStatus.Beendet -> "Beendet"
    }
}
