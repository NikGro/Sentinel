package de.nglab.sentinel.kern.modell

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Datenmodell, genau nach server/src/schemas.ts. Feldnamen wie auf dem Server (JSON), fehlende Felder mit den
// Vorgaben des Servers. Der Server ist die einzige Quelle der Wahrheit; der Kern schreibt nur Änderungswünsche.

/** Ein gemeinsam bearbeitetes Objekt samt Versionsstand. */
@Serializable
data class Versioniert<T>(
    val id: String,
    val rev: Long = 0,
    val updatedAt: Long = 0,
    val updatedBy: String = "",
    val data: T,
)

/** Objektart auf dem Server (`kind`). */
enum class Art(val schluessel: String) {
    Fahnder("member"), Fahrzeug("vehicle"), Markierung("annotation"), Ziel("target"), Beziehung("relation"),
    Zielgruppe("targetGroup"), Tracker("tracker"), Ebene("layer"), Raum("room"), Nachricht("message"), Instanz("instance");

    companion object {
        fun von(schluessel: String): Art? = entries.firstOrNull { it.schluessel == schluessel }
    }
}

@Serializable
enum class Fortbewegung {
    @SerialName("fuss") Fuss,
    @SerialName("fahrzeug") Fahrzeug,
    @SerialName("oepnv") Oepnv,
}

/** Gewählte Linie und Fahrtrichtung im ÖPNV. */
@Serializable
data class OepnvFahrt(val linienId: String, val linie: String, val richtung: String = "")

@Serializable
data class Fahnder(
    val name: String,
    val spitzname: String,
    val dienststelle: String,
    val telefon: String = "",
    val fotoBlob: String? = null,
    val aktiv: Boolean = true,
    val fortbewegung: Fortbewegung = Fortbewegung.Fuss,
    val fahrzeugId: String? = null,
    val oepnv: OepnvFahrt? = null,
    val instanz: String = Instanz.HAUPT,
    val fahrzeugSeit: Long? = null,
    val aufzeichnung: Boolean = true,
)

@Serializable
data class Fahrzeug(
    val funkrufname: String,
    val bezeichnung: String = "",
    val kennzeichen: String = "",
    val beschreibung: String = "",
    val fotoBlob: String? = null,
    val trackerId: String? = null,
    val aktiv: Boolean = true,
    val abgestellt: ZeitPunkt? = null,
    val aufzeichnung: Boolean = true,
) {
    /** Zusatzangabe unter dem Funkrufnamen (ältere Stände mit getrennter Beschreibung zusammengeführt). */
    val zusatz: String get() = listOf(bezeichnung, beschreibung).filter { it.isNotBlank() }.distinct().joinToString(", ")
}

@Serializable
enum class Anhangart {
    @SerialName("bild") Bild,
    @SerialName("audio") Audio,
    @SerialName("datei") Datei,
}

@Serializable
data class Anhang(
    val blobId: String,
    val art: Anhangart,
    val name: String = "",
    val mime: String,
    val groesse: Long,
    val dauer: Double? = null,
    val wellenform: List<Double>? = null,
)

@Serializable
enum class Form {
    @SerialName("marker") Marker,
    @SerialName("text") Text,
    @SerialName("linie") Linie,
    @SerialName("flaeche") Flaeche,
    @SerialName("kreis") Kreis,
    @SerialName("fahndungsraum") Fahndungsraum,
    @SerialName("haltestellen") Haltestellen,
    @SerialName("oepnvlinie") OepnvLinie,
    @SerialName("oepnvfahrzeug") OepnvFahrzeug,
    @SerialName("pfeil") Pfeil,
    @SerialName("haltestelle") Haltestelle,
    @SerialName("geofence") Geofence,
    @SerialName("verlauf") Verlauf;

    /** Mindestzahl an Punkten, ab der die Form gültig ist. */
    val mindestPunkte: Int get() = when (this) {
        Linie, Pfeil, OepnvLinie, OepnvFahrzeug -> 2
        Flaeche -> 3
        else -> 1
    }

    val istOepnv: Boolean get() = this == OepnvLinie || this == OepnvFahrzeug
    val istMehrpunkt: Boolean get() = this == Linie || this == Pfeil || this == Flaeche
}

@Serializable
data class Linienverweis(
    val id: String,
    val ref: String = "",
    val typ: String,
    val richtung: String = "",
    val farbe: String? = null,
)

/** Echte Fahrt (Transitous) mit Zeit (ms) an jedem Halt; der Server führt Verspätungen nach. */
@Serializable
data class OepnvFahrtDaten(
    val id: String,
    val zeiten: List<Long?> = emptyList(),
    val haltIds: List<String>? = null,
    val echtzeit: Boolean? = null,
    val stand: Long? = null,
)

/** Ebenen einer übernommenen ÖPNV-Strecke, jede einzeln zuschaltbar. */
@Serializable
data class OepnvEbenen(val fahrzeug: Boolean, val strecke: Boolean, val halte: Boolean)

@Serializable
data class SpurVerweis(val art: String, val id: String)

@Serializable
enum class Ausloeser {
    @SerialName("verlassen") Verlassen,
    @SerialName("betreten") Betreten,
}

/** Markierung auf der Karte (`annotation`). */
@Serializable
data class Markierung(
    val layerId: String,
    val typ: Form,
    val titel: String = "",
    val notiz: String = "",
    val farbe: String = "#FF9F0A",
    val symbol: String = "",
    val punkte: List<GeoPunkt>,
    val radius: Double? = null,
    val wert: Double? = null,
    val zeit: Long? = null,
    val trackerId: String? = null,
    val anhaenge: List<Anhang> = emptyList(),
    val linie: Linienverweis? = null,
    val weg: List<GeoPunkt> = emptyList(),
    val fahrt: OepnvFahrtDaten? = null,
    val ebenen: OepnvEbenen? = null,
    val haltNamen: List<String> = emptyList(),
    val takt: Int? = null,
    val ablauf: Long? = null,
    val ziele: List<String> = emptyList(),
    val ausloeser: Ausloeser? = null,
    val spuren: List<SpurVerweis> = emptyList(),
    val zeitVon: Long? = null,
    val zeitBis: Long? = null,
) {
    /** Ankerpunkt für Beschriftung und Antippen (Mitte bei Flächen, erster Punkt sonst). */
    val anker: GeoPunkt get() = when (typ) {
        Form.Flaeche, Form.Geofence -> if (punkte.size >= 3) GeoPunkt(punkte.map { it.lat }.average(), punkte.map { it.lon }.average()) else punkte.first()
        else -> punkte.first()
    }

    fun abgelaufen(jetztMs: Long): Boolean = ablauf?.let { it <= jetztMs } ?: false

    val zeigtStrecke: Boolean get() = ebenen?.strecke ?: true
    val zeigtHalte: Boolean get() = ebenen?.halte ?: true
    val zeigtFahrzeug: Boolean get() = ebenen?.fahrzeug ?: true

    /** Standortspur (Farbe nach Alter bzw. Häufigkeit statt nach Quelle); gekennzeichnet über das Symbol. */
    val istStandortspur: Boolean get() = typ == Form.Verlauf && symbol.startsWith(STANDORTSPUR)
    val standortspurNachHaeufigkeit: Boolean get() = symbol == STANDORTSPUR_HAEUFIGKEIT

    /** Fährt hier ein Fahrzeug nach echtem Fahrplan? */
    val hatEchtesFahrzeug: Boolean get() = fahrt != null && (typ == Form.OepnvFahrzeug || (typ == Form.OepnvLinie && zeigtFahrzeug))

    companion object {
        const val STANDORTSPUR = "standortspur"
        const val STANDORTSPUR_HAEUFIGKEIT = "standortspur.haeufigkeit"
    }
}

@Serializable
enum class Zielart {
    @SerialName("person") Person,
    @SerialName("fahrzeug") Fahrzeug,
    @SerialName("objekt") Objekt,
}

@Serializable
data class Bindung(val art: BindungsArt, val zielId: String? = null)

@Serializable
enum class BindungsArt {
    @SerialName("fuss") Fuss,
    @SerialName("oepnv") Oepnv,
    @SerialName("fahrzeug") Fahrzeug,
    @SerialName("objekt") Objekt,
}

@Serializable
enum class Standortquelle {
    @SerialName("hand") Hand,
    @SerialName("tracker") Tracker,
    @SerialName("a") APosition,
}

@Serializable
data class Ziel(
    val art: Zielart = Zielart.Person,
    val bezeichnung: String = "",
    val vorname: String = "",
    val nachname: String = "",
    val geburtsdatum: String? = null,
    val geburtsort: String = "",
    val staatsangehoerigkeit: String = "",
    val anschrift: String = "",
    val merkmale: String = "",
    val fotoBlob: String? = null,
    val kennzeichen: String = "",
    val fahrzeugBeschreibung: String = "",
    val fahrzeugFotoBlob: String? = null,
    val sachverhalt: String = "",
    val hinweise: String = "",
    val massnahmen: String = "",
    val anhaenge: List<Anhang> = emptyList(),
    val trackerId: String? = null,
    val bindung: Bindung? = null,
    val quelle: Standortquelle? = null,
    val gruppeId: String? = null,
    val standort: ZeitPunkt? = null,
    val aufzeichnung: Boolean = true,
) {
    /** Anzeigename: Person Vor- und Nachname, Fahrzeug Kennzeichen, Objekt Bezeichnung. */
    val anzeigename: String get() = when (art) {
        Zielart.Person -> listOf(vorname, nachname).filter { it.isNotBlank() }.joinToString(" ").ifBlank { bezeichnung.ifBlank { "Unbekannte Person" } }
        Zielart.Fahrzeug -> kennzeichen.ifBlank { bezeichnung.ifBlank { "Zielfahrzeug" } }
        Zielart.Objekt -> bezeichnung.ifBlank { anschrift.ifBlank { "Zielobjekt" } }
    }

    /** Zweite Zeile: beim Fahrzeug die Bezeichnung, sonst ein Kennzeichen, falls eingetragen. */
    val zweiteZeile: String? get() = when (art) {
        Zielart.Fahrzeug -> bezeichnung.takeIf { it.isNotBlank() && kennzeichen.isNotBlank() }
        else -> kennzeichen.takeIf { it.isNotBlank() }
    }

    /** Alle Freitexte in einem Feld; ältere Stände mit getrennten Feldern werden mit Überschriften zusammengeführt. */
    val freitext: String get() {
        if (hinweise.isNotBlank()) return hinweise
        return listOf("Merkmale" to merkmale, "Fahrzeug" to fahrzeugBeschreibung, "Sachverhalt" to sachverhalt, "Maßnahmen" to massnahmen)
            .filter { it.second.isNotBlank() }
            .joinToString("\n\n") { "${it.first}:\n${it.second}" }
    }

    val gewaehlteQuelle: Standortquelle get() = quelle ?: if (trackerId != null) Standortquelle.Tracker else Standortquelle.Hand
    val kannLiveQuelle: Boolean get() = art != Zielart.Objekt
}

@Serializable
enum class BeziehungsStatus {
    @SerialName("vermutet") Vermutet,
    @SerialName("bestaetigt") Bestaetigt,
    @SerialName("beendet") Beendet,
}

@Serializable
data class Beziehung(
    val von: String,
    val nach: String,
    val bezeichnung: String = "",
    val notiz: String = "",
    val status: BeziehungsStatus = BeziehungsStatus.Vermutet,
    val herkunft: String = "",
) {
    fun andere(als: String): String = if (von == als) nach else von
}

@Serializable
data class Zielgruppe(val name: String, val symbol: String = "folder.fill", val farbe: String = "#0A84FF")

@Serializable
data class Tracker(
    val name: String,
    val anbieter: String,
    val kennung: String,
    val intervall: Int? = null,
    val kontoEmail: String = "",
    val telefon: String = "",
    val smsPin: String = "",
    val aufzeichnung: Boolean = true,
)

@Serializable
data class Ebene(val name: String, val art: String, val status: String, val beschreibung: String = "") {
    val istLive: Boolean get() = status == "live"

    companion object {
        const val LAGE = "lage"
        const val DAUERHAFT = "dauerhaft"
    }
}

@Serializable
data class Instanz(
    val name: String,
    val art: String = "einsatz",
    val beschreibung: String = "",
    val mitglieder: List<String> = emptyList(),
    val erstelltVon: String = "",
) {
    val istPaket: Boolean get() = art == "paket"

    companion object {
        const val HAUPT = "haupt"
    }
}

@Serializable
data class ChatRaum(val name: String)

@Serializable
data class Nachricht(val roomId: String = "allgemein", val text: String = "", val anhang: Anhang? = null)

/** Was überschlagend angefahren wird: die A, ein Fahnder, ein Ziel oder ein ÖPNV-Fahrzeug. */
@Serializable
data class UeberschlagKurs(val art: String, val id: String? = null)

@Serializable
data class UeberschlagHalt(val name: String, val lat: Double, val lon: Double) {
    val punkt: GeoPunkt get() = GeoPunkt(lat, lon)
}

@Serializable
data class Einsatzzustand(
    val funkkanal: String? = null,
    val titel: String = "",
    val hinweise: String = "",
    val a: Halter? = null,
    val ueberschlagen: Ueberschlagen = Ueberschlagen(),
    val sos: Halter? = null,
    val fahrzeuge: List<String>? = null,
    val ziele: List<String>? = null,
    val gruppenAus: List<String> = emptyList(),
    val rev: Long = 0,
) {
    @Serializable
    data class Halter(val memberId: String, val seit: Long)

    @Serializable
    data class Ueberschlagen(
        val teilnehmer: List<String> = emptyList(),
        val zuweisungen: Map<String, UeberschlagHalt> = emptyMap(),
        val naechste: List<UeberschlagHalt> = emptyList(),
        val kurs: UeberschlagKurs? = null,
    )
}

/** Serialisierer je Objektart (für das Protokoll). */
@Suppress("UNCHECKED_CAST")
internal fun serialisierer(art: Art): KSerializer<Any> = when (art) {
    Art.Fahnder -> Fahnder.serializer()
    Art.Fahrzeug -> Fahrzeug.serializer()
    Art.Markierung -> Markierung.serializer()
    Art.Ziel -> Ziel.serializer()
    Art.Beziehung -> Beziehung.serializer()
    Art.Zielgruppe -> Zielgruppe.serializer()
    Art.Tracker -> Tracker.serializer()
    Art.Ebene -> Ebene.serializer()
    Art.Raum -> ChatRaum.serializer()
    Art.Nachricht -> Nachricht.serializer()
    Art.Instanz -> Instanz.serializer()
} as KSerializer<Any>
