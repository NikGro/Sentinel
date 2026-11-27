package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Beziehung
import de.nglab.sentinel.kern.modell.BeziehungsStatus
import de.nglab.sentinel.kern.modell.BindungsArt
import de.nglab.sentinel.kern.modell.ChatRaum
import de.nglab.sentinel.kern.modell.Ebene
import de.nglab.sentinel.kern.modell.Einsatzzustand
import de.nglab.sentinel.kern.modell.Fahnder
import de.nglab.sentinel.kern.modell.Fahrzeug
import de.nglab.sentinel.kern.modell.Fortbewegung
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Instanz
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Nachricht
import de.nglab.sentinel.kern.modell.Position
import de.nglab.sentinel.kern.modell.Standortquelle
import de.nglab.sentinel.kern.modell.Tracker
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielgruppe
import de.nglab.sentinel.kern.oepnv.OepnvSimulation

/** Woher ein Standort stammt. */
enum class Herkunft { Besatzung, Tracker, Abgestellt, Hand, APosition, Oepnv, Gebunden }

data class Ortung(val punkt: GeoPunkt, val zeitMs: Long, val herkunft: Herkunft)

/** Beziehung aus Sicht eines Ziels, mit dem jeweils anderen Ziel. */
data class VerbundenesZiel(val beziehung: Versioniert<Beziehung>, val anderes: Versioniert<Ziel>)

/**
 * Unveränderlicher Stand der Lage, wie ihn der Server verteilt. Alle Ableitungen (Sichtbarkeit, Standorte, Ketten)
 * stehen hier, damit iOS, Android und Tests dieselben Regeln nutzen.
 */
data class LageStand(
    val ichId: String? = null,
    val hatStand: Boolean = false,
    val serverVersion: String? = null,
    val routing: Boolean = false,
    val instanz: String = Instanz.HAUPT,
    val fahnder: Map<String, Versioniert<Fahnder>> = emptyMap(),
    val fahrzeuge: Map<String, Versioniert<Fahrzeug>> = emptyMap(),
    val markierungen: Map<String, Versioniert<Markierung>> = emptyMap(),
    val ziele: Map<String, Versioniert<Ziel>> = emptyMap(),
    val beziehungen: Map<String, Versioniert<Beziehung>> = emptyMap(),
    val zielgruppen: Map<String, Versioniert<Zielgruppe>> = emptyMap(),
    val tracker: Map<String, Versioniert<Tracker>> = emptyMap(),
    val ebenen: Map<String, Versioniert<Ebene>> = emptyMap(),
    val raeume: Map<String, Versioniert<ChatRaum>> = emptyMap(),
    val nachrichten: List<Versioniert<Nachricht>> = emptyList(),
    val instanzen: Map<String, Versioniert<Instanz>> = emptyMap(),
    val einsatz: Einsatzzustand = Einsatzzustand(),
    val positionen: Map<String, Position> = emptyMap(),
    val trackerPositionen: Map<String, Position> = emptyMap(),
    val online: Set<String> = emptySet(),
    val bestreifungStand: Int = 0,
) {
    // Eigene Rolle

    val ich: Versioniert<Fahnder>? get() = ichId?.let { fahnder[it] }
    val eigenePosition: Position? get() = ichId?.let { positionen[it] }
    val haeltA: Boolean get() = ichId != null && einsatz.a?.memberId == ichId
    val aHalter: Versioniert<Fahnder>? get() = einsatz.a?.let { fahnder[it.memberId] }
    val aPosition: Position? get() = einsatz.a?.let { positionen[it.memberId] }
    val aImOepnv: Boolean get() = aHalter?.data?.let { it.fortbewegung == Fortbewegung.Oepnv && it.oepnv != null } ?: false
    val fremderNotruf: Versioniert<Fahnder>? get() = einsatz.sos?.takeIf { it.memberId != ichId }?.let { fahnder[it.memberId] }
    val eigenerNotruf: Boolean get() = ichId != null && einsatz.sos?.memberId == ichId
    /** Im Dienst = in einer Instanz aktiv; außer Dienst bleibt nur das Hauptmenü und der Standort wird nicht geteilt. */
    val imDienst: Boolean get() = ich?.data?.aktiv ?: false
    val ueberschlagTeilnahme: Boolean get() = ichId?.let { it in einsatz.ueberschlagen.teilnehmer } ?: false

    // Instanzen

    val aktuelleInstanz: Versioniert<Instanz>? get() = instanzen[instanz]
    /** In einem Paket wird nur vorbereitet: kein Einsatzbetrieb (A, Notruf, Navigation, Fortbewegung). */
    val istPaketbereich: Boolean get() = aktuelleInstanz?.data?.istPaket ?: false

    val eigeneInstanzen: List<Versioniert<Instanz>>
        get() = instanzen.values.filter { !it.data.istPaket && (ichId ?: "") in it.data.mitglieder }
            .sortedWith(compareBy<Versioniert<Instanz>> { it.id != Instanz.HAUPT }.thenBy { Sortierung.text(it.data.name) })

    val andereInstanzen: List<Versioniert<Instanz>>
        get() {
            val meine = eigeneInstanzen.map { it.id }.toSet()
            return instanzen.values.filter { !it.data.istPaket && it.id !in meine }.sortedWith(compareBy { Sortierung.text(it.data.name) })
        }

    val pakete: List<Versioniert<Instanz>> get() = instanzen.values.filter { it.data.istPaket }.sortedWith(compareBy { Sortierung.text(it.data.name) })

    // Listen

    /** Kräfte in der geöffneten Instanz: aktive zuerst, dann nach Spitzname. */
    val kraefte: List<Versioniert<Fahnder>>
        get() = fahnder.values.filter { it.data.instanz == instanz }
            .sortedWith(compareBy<Versioniert<Fahnder>> { !it.data.aktiv }.thenBy { Sortierung.text(it.data.spitzname) })

    val aktiveKraefte: List<Versioniert<Fahnder>> get() = kraefte.filter { it.data.aktiv }

    val zieleSortiert: List<Versioniert<Ziel>> get() = ziele.values.sortedWith(compareBy { Sortierung.text(it.data.anzeigename) })

    val zielgruppenSortiert: List<Versioniert<Zielgruppe>> get() = zielgruppen.values.sortedWith(compareBy { Sortierung.text(it.data.name) })

    val fahrzeugeSortiert: List<Versioniert<Fahrzeug>>
        get() = fahrzeuge.values.sortedWith(compareBy<Versioniert<Fahrzeug>> { !imEinsatz(it) }.thenBy { Sortierung.text(it.data.funkrufname) })

    val ebenenSortiert: List<Versioniert<Ebene>>
        get() {
            val reihenfolge = mapOf("lage" to 0, "dauerhaft" to 1, "paket" to 2, "argus" to 3)
            return ebenen.values.sortedWith(compareBy<Versioniert<Ebene>> { reihenfolge[it.data.art] ?: 9 }.thenBy { it.data.name })
        }

    val raeumeSortiert: List<Versioniert<ChatRaum>>
        get() = raeume.values.sortedWith(compareBy<Versioniert<ChatRaum>> { it.id != "allgemein" }.thenBy { Sortierung.text(it.data.name) })

    fun nachrichtenIn(raumId: String): List<Versioniert<Nachricht>> = nachrichten.filter { it.data.roomId == raumId }

    // Sichtbarkeit

    fun zielEingeblendet(id: String): Boolean = einsatz.ziele?.contains(id) ?: true
    fun gruppeEingeblendet(id: String): Boolean = id !in einsatz.gruppenAus

    /** Auf der Karte sichtbar: Ziel eingeblendet und (falls gruppiert) seine Gruppe auch. */
    fun zielSichtbar(id: String): Boolean {
        if (!zielEingeblendet(id)) return false
        val gruppe = ziele[id]?.data?.gruppeId ?: return true
        if (zielgruppen[gruppe] == null) return true
        return gruppeEingeblendet(gruppe)
    }

    fun imEinsatz(fahrzeug: Versioniert<Fahrzeug>): Boolean = einsatz.fahrzeuge?.contains(fahrzeug.id) ?: fahrzeug.data.aktiv

    fun istOnline(fahnderId: String): Boolean = fahnderId in online

    // Kräfte und Fahrzeuge

    fun fahrzeugVon(f: Fahnder): Versioniert<Fahrzeug>? =
        if (f.fortbewegung == Fortbewegung.Fahrzeug) f.fahrzeugId?.let { fahrzeuge[it] } else null

    /** Bezeichnung auf der Karte: zu Fuß der Spitzname, im Fahrzeug dessen Funkrufname, im ÖPNV mit Linie. */
    fun beschriftung(f: Fahnder): String {
        fahrzeugVon(f)?.let { return it.data.funkrufname }
        if (f.fortbewegung == Fortbewegung.Oepnv && f.oepnv != null) return "${f.spitzname} (${f.oepnv.linie})"
        return f.spitzname
    }

    /** Kurzbeschreibung der Fortbewegung, z. B. „Fahrzeug P 35/24“ oder „U3 Richtung Barmbek“. */
    fun fortbewegungText(f: Fahnder): String = when (f.fortbewegung) {
        Fortbewegung.Fuss -> "Zu Fuß"
        Fortbewegung.Fahrzeug -> fahrzeugVon(f)?.let { "Fahrzeug ${it.data.funkrufname}" } ?: "Im Fahrzeug"
        Fortbewegung.Oepnv -> f.oepnv?.let { "${it.linie} Richtung ${it.richtung}" } ?: "Im ÖPNV"
    }

    fun insassen(fahrzeugId: String): List<Versioniert<Fahnder>> =
        aktiveKraefte.filter { it.data.fortbewegung == Fortbewegung.Fahrzeug && it.data.fahrzeugId == fahrzeugId }

    /**
     * Standort eines Fahrzeugs: Sitzt jemand drin, ist das Telefon dessen, der zuerst eingestiegen ist, die Quelle.
     * Der Tracker zählt nur, wenn niemand drinsitzt oder seine Meldung deutlich (2 min) frischer ist; sonst der Abstellort.
     */
    fun ortung(fahrzeug: Versioniert<Fahrzeug>): Ortung? {
        val fuehrer = insassen(fahrzeug.id).filter { positionen[it.id] != null }
            .minWithOrNull(compareBy<Versioniert<Fahnder>> { it.data.fahrzeugSeit ?: Long.MAX_VALUE }.thenBy { it.id })
        val besatzung = fuehrer?.let { positionen[it.id] }
        val tracker = fahrzeug.data.trackerId?.let { trackerPositionen[it] }
        if (tracker != null && besatzung != null && tracker.ts > besatzung.ts + 120_000) return Ortung(tracker.punkt, tracker.ts, Herkunft.Tracker)
        if (besatzung != null) return Ortung(besatzung.punkt, besatzung.ts, Herkunft.Besatzung)
        if (tracker != null) return Ortung(tracker.punkt, tracker.ts, Herkunft.Tracker)
        return fahrzeug.data.abgestellt?.let { Ortung(it.punkt, it.ts, Herkunft.Abgestellt) }
    }

    // Ziele

    /**
     * Standort eines Ziels. Eingestiegen (Zielfahrzeug, ÖPNV-Fahrzeug, Gebäude): dessen Standort (Ketten höchstens zwei
     * Stufen tief). Sonst nach Standortquelle: der A-Position folgend, vom Tracker oder von Hand gesetzt.
     */
    fun ortung(ziel: Versioniert<Ziel>, jetztMs: Long, tiefe: Int = 0): Ortung? {
        val bindung = ziel.data.bindung
        if (bindung != null && bindung.art != BindungsArt.Fuss && bindung.zielId != null && tiefe < 2) {
            when (bindung.art) {
                BindungsArt.Oepnv -> markierungen[bindung.zielId]?.let { return Ortung(ortung(it.data, jetztMs), jetztMs, Herkunft.Oepnv) }
                BindungsArt.Fahrzeug, BindungsArt.Objekt ->
                    ziele[bindung.zielId]?.let { anderes -> ortung(anderes, jetztMs, tiefe + 1)?.let { return it.copy(herkunft = Herkunft.Gebunden) } }
                BindungsArt.Fuss -> Unit
            }
        }
        when (ziel.data.gewaehlteQuelle) {
            Standortquelle.APosition -> aPosition?.let { return Ortung(it.punkt, it.ts, Herkunft.APosition) }
            Standortquelle.Tracker -> ziel.data.trackerId?.let { trackerPositionen[it] }?.let { return Ortung(it.punkt, it.ts, Herkunft.Tracker) }
            Standortquelle.Hand -> Unit
        }
        return ziel.data.standort?.let { Ortung(it.punkt, it.ts, Herkunft.Hand) }
    }

    /** Bewegt sich der Standort eines Ziels mit einer Live-Quelle mit? */
    fun istLive(ziel: Versioniert<Ziel>, tiefe: Int = 0): Boolean {
        val bindung = ziel.data.bindung
        if (bindung != null && bindung.art != BindungsArt.Fuss && bindung.zielId != null && tiefe < 2) {
            if (bindung.art == BindungsArt.Oepnv) return markierungen[bindung.zielId] != null
            ziele[bindung.zielId]?.let { return istLive(it, tiefe + 1) }
        }
        return when (ziel.data.gewaehlteQuelle) {
            Standortquelle.APosition -> aPosition != null
            Standortquelle.Tracker -> ziel.data.trackerId?.let { trackerPositionen[it] } != null
            Standortquelle.Hand -> false
        }
    }

    /** Zielpersonen, die in einem Zielfahrzeug, Gebäude oder ÖPNV-Fahrzeug sitzen. */
    fun mitfahrer(id: String): List<Versioniert<Ziel>> =
        zieleSortiert.filter { it.data.bindung?.zielId == id && it.data.bindung?.art != BindungsArt.Fuss }

    /** Beziehungen eines Ziels; laufende zuerst, beendete zuletzt, sonst nach Name. */
    fun verbundeneZiele(zielId: String): List<VerbundenesZiel> =
        beziehungen.values.filter { it.data.von == zielId || it.data.nach == zielId }
            .mapNotNull { b -> ziele[b.data.andere(zielId)]?.let { VerbundenesZiel(b, it) } }
            .sortedWith(compareBy<VerbundenesZiel> { it.beziehung.data.status == BeziehungsStatus.Beendet }.thenBy { Sortierung.text(it.anderes.data.anzeigename) })

    // Markierungen

    /** Nur geladene Ebenen erscheinen auf der Karte; abgelaufene Markierungen nicht. */
    fun sichtbareMarkierungen(jetztMs: Long, ausgeblendeteEbenen: Set<String> = emptySet()): List<Versioniert<Markierung>> =
        markierungen.values.filter { m ->
            val ebene = ebenen[m.data.layerId]
            (ebene == null || ebene.data.istLive) && m.data.layerId !in ausgeblendeteEbenen && !m.data.abgelaufen(jetztMs)
        }

    /** Standort einer Markierung: ÖPNV nach Fahrmodell, mit Tracker dessen Position, sonst der gesetzte Punkt. */
    fun ortung(m: Markierung, jetztMs: Long): GeoPunkt {
        if (m.typ.istOepnv) OepnvSimulation.punkt(m, jetztMs)?.let { return it }
        return m.trackerId?.let { trackerPositionen[it]?.punkt } ?: m.anker
    }

    fun name(akteurId: String): String = when (akteurId) {
        "zentrale" -> "Zentrale"
        "system" -> "System"
        else -> fahnder[akteurId]?.data?.spitzname ?: "Unbekannt"
    }

    /** App und Server passen zusammen, wenn Haupt- und Nebenversion übereinstimmen; sonst eine Meldung. */
    fun versionsHinweis(appVersion: String): String? {
        val server = serverVersion ?: return null
        val schluessel = { v: String -> v.split('.').take(2).mapNotNull { it.toIntOrNull() } }
        val s = schluessel(server)
        val a = schluessel(appVersion)
        if (s.size != 2 || a.size != 2 || s == a) return null
        val serverAelter = s[0] < a[0] || (s[0] == a[0] && s[1] < a[1])
        return if (serverAelter) "Server $server ist älter als die App $appVersion. Bitte den Server aktualisieren."
        else "Die App $appVersion ist älter als der Server $server. Bitte die App aktualisieren."
    }

    /** Liste der Objekte einer Art (für die Anwendung von Änderungen). */
    internal fun mitObjekt(art: Art, objekt: Versioniert<Any>): LageStand {
        @Suppress("UNCHECKED_CAST")
        return when (art) {
            Art.Fahnder -> copy(fahnder = fahnder + (objekt.id to objekt as Versioniert<Fahnder>))
            Art.Fahrzeug -> copy(fahrzeuge = fahrzeuge + (objekt.id to objekt as Versioniert<Fahrzeug>))
            Art.Markierung -> copy(markierungen = markierungen + (objekt.id to objekt as Versioniert<Markierung>))
            Art.Ziel -> copy(ziele = ziele + (objekt.id to objekt as Versioniert<Ziel>))
            Art.Beziehung -> copy(beziehungen = beziehungen + (objekt.id to objekt as Versioniert<Beziehung>))
            Art.Zielgruppe -> copy(zielgruppen = zielgruppen + (objekt.id to objekt as Versioniert<Zielgruppe>))
            Art.Tracker -> copy(tracker = tracker + (objekt.id to objekt as Versioniert<Tracker>))
            Art.Ebene -> copy(ebenen = ebenen + (objekt.id to objekt as Versioniert<Ebene>))
            Art.Raum -> copy(raeume = raeume + (objekt.id to objekt as Versioniert<ChatRaum>))
            Art.Instanz -> copy(instanzen = instanzen + (objekt.id to objekt as Versioniert<Instanz>))
            Art.Nachricht -> if (nachrichten.any { it.id == objekt.id }) this else copy(nachrichten = nachrichten + (objekt as Versioniert<Nachricht>))
        }
    }

    internal fun ohneObjekt(art: Art, id: String): LageStand = when (art) {
        Art.Fahnder -> copy(fahnder = fahnder - id, positionen = positionen - id)
        Art.Fahrzeug -> copy(fahrzeuge = fahrzeuge - id)
        Art.Markierung -> copy(markierungen = markierungen - id)
        Art.Ziel -> copy(ziele = ziele - id, beziehungen = beziehungen.filterValues { it.data.von != id && it.data.nach != id })
        Art.Beziehung -> copy(beziehungen = beziehungen - id)
        Art.Zielgruppe -> copy(zielgruppen = zielgruppen - id)
        Art.Tracker -> copy(tracker = tracker - id, trackerPositionen = trackerPositionen - id)
        Art.Ebene -> copy(ebenen = ebenen - id)
        Art.Raum -> copy(raeume = raeume - id, nachrichten = nachrichten.filter { it.data.roomId != id })
        Art.Nachricht -> copy(nachrichten = nachrichten.filter { it.id != id })
        Art.Instanz -> copy(instanzen = instanzen - id)
    }
}

/** Natürliche Sortierung deutscher Texte (Groß/klein egal, Zahlen nach Wert). */
object Sortierung {
    fun text(a: String): String = a.lowercase()
        .replace("ä", "a").replace("ö", "o").replace("ü", "u").replace("ß", "ss")
        .replace(Regex("\\d+")) { it.value.padStart(10, '0') }
}
