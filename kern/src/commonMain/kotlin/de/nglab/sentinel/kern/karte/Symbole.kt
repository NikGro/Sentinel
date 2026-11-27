package de.nglab.sentinel.kern.karte

/**
 * Symbole der App, plattformneutral: Jeder Schlüssel hat ein SF Symbol (iOS) und ein Material Symbol (Android, Web).
 * Gespeichert wird der Schlüssel; ältere Stände mit SF-Symbolnamen werden über `vonGespeichert` zugeordnet.
 */
enum class Symbol(val schluessel: String, val sf: String, val material: String) {
    // Kräfte und Fortbewegung
    Fuss("fuss", "figure.walk", "directions_walk"),
    Fahrzeug("fahrzeug", "car.fill", "directions_car"),
    Oepnv("oepnv", "tram.fill", "tram"),

    // Ziele
    Person("person", "person.fill", "person"),
    Zielfahrzeug("zielfahrzeug", "car.side.fill", "directions_car"),
    Objekt("objekt", "house.fill", "home"),

    // Markierungen
    Nadel("nadel", "mappin", "location_on"),
    Fahne("fahne", "flag.fill", "flag"),
    Auge("auge", "eye.fill", "visibility"),
    Haus("haus", "house.fill", "home"),
    Gebaeude("gebaeude", "building.2.fill", "apartment"),
    Auto("auto", "car.fill", "directions_car"),
    Gehen("gehen", "figure.walk", "directions_walk"),
    Mensch("mensch", "person.fill", "person"),
    Warnung("warnung", "exclamationmark.triangle.fill", "warning"),
    Kamera("kamera", "camera.fill", "photo_camera"),
    Tuer("tuer", "door.left.hand.open", "door_open"),
    Parken("parken", "p.circle.fill", "local_parking"),
    Bahn("bahn", "tram.fill", "tram"),
    Kreuz("kreuz", "cross.fill", "add"),
    Stern("stern", "star.fill", "star"),
    Verboten("verboten", "xmark.circle.fill", "cancel"),

    // Weitere Kartenobjekte
    Text("text", "textformat", "title"),
    Fahndungsraum("fahndungsraum", "scope", "radar"),
    Haltestelle("haltestelle", "h.circle.fill", "directions_bus"),
    Geofence("geofence", "shield.lefthalf.filled", "shield"),
    Verlauf("verlauf", "point.bottomleft.forward.to.point.topright.scurvepath", "timeline"),

    // Gruppen
    Ordner("ordner", "folder.fill", "folder"),
    Aktenkoffer("aktenkoffer", "briefcase.fill", "work"),
    Schild("schild", "shield.fill", "shield"),
    Ziel("ziel", "target", "my_location"),
    Personen("personen", "person.2.fill", "group"),
    Lkw("lkw", "truck.box.fill", "local_shipping"),
    Telefon("telefon", "phone.fill", "call"),
    Geld("geld", "eurosign.circle.fill", "euro"),
    Schloss("schloss", "lock.fill", "lock"),
    Glocke("glocke", "bell.fill", "notifications");

    /** Name des Kartenbilds, das die Plattform beim Laden der Karte anlegt (`sym-<schlüssel>`). */
    val bildname: String get() = "sym-$schluessel"

    companion object {
        val marker: List<Symbol> = listOf(Nadel, Fahne, Auge, Haus, Gebaeude, Auto, Gehen, Mensch, Warnung, Kamera, Tuer, Parken, Bahn, Kreuz, Stern, Verboten)
        val gruppen: List<Symbol> = listOf(Ordner, Aktenkoffer, Schild, Ziel, Personen, Auto, Lkw, Haus, Gebaeude, Telefon, Geld, Schloss, Glocke, Stern, Fahne, Warnung)

        /** Schlüssel oder (ältere Stände) SF-Symbolname; unbekannt wird zur Nadel bzw. zum Ordner. */
        fun vonGespeichert(wert: String, ersatz: Symbol = Nadel): Symbol =
            entries.firstOrNull { it.schluessel == wert } ?: entries.firstOrNull { it.sf == wert } ?: ersatz
    }
}

/** Farbe aus „#RRGGBB“; ungültige Angaben ergeben Orange. */
fun farbe(hex: String): String = if (Regex("^#[0-9A-Fa-f]{6}$").matches(hex)) hex.uppercase() else "#FF9F0A"

/** Gestaltungs-Grundwerte, gemeinsam für alle Plattformen (Farben der Rollen). */
object Farben {
    const val AKZENT = "#0A84FF"
    const val KRAEFTE = "#5E5CE6"
    const val ZIELE = "#FF375F"
    const val A_POSITION = "#FF3B30"
    const val SONDERBEREICH = "#AF52DE"
    const val BESTREIFUNG = "#FF9F0A"
    const val CLUSTER_GEMISCHT = "#5E6A7D"
    const val SONDERRECHTE = "#FF3B30"
    const val ROUTE = "#0A84FF"
    const val WEGZEIT_FUSS = "#34C759"
    const val WEGZEIT_KFZ = "#FF3B30"
    const val WEGZEIT_OEPNV = "#0A84FF"

    /** Markierungsfarben (gut unterscheidbar auf Karte und Luftbild). */
    val palette: List<Pair<String, String>> = listOf(
        "Orange" to "#FF9F0A", "Rot" to "#FF453A", "Gelb" to "#FFD60A", "Grün" to "#30D158",
        "Türkis" to "#64D2FF", "Blau" to "#0A84FF", "Violett" to "#BF5AF2", "Weiß" to "#F2F2F7",
    )
}
