package de.nglab.sentinel.kern.karte

import de.nglab.sentinel.kern.modell.Ausloeser
import de.nglab.sentinel.kern.modell.Ebene
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Standortquelle
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielart
import de.nglab.sentinel.kern.modell.ZeitPunkt
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Was sich über das Plus-Menü bzw. an einem Suchtreffer anlegen lässt. */
sealed interface Anlegbar {
    val titel: String
    val symbol: Symbol

    data class NeueForm(val form: Form) : Anlegbar {
        override val titel: String get() = Formen.titel(form)
        override val symbol: Symbol get() = Formen.symbol(form)
    }

    data class NeuesZiel(val art: Zielart) : Anlegbar {
        override val titel: String get() = when (art) {
            Zielart.Person -> "Zielperson"
            Zielart.Fahrzeug -> "Zielfahrzeug"
            Zielart.Objekt -> "Zielobjekt"
        }
        override val symbol: Symbol get() = when (art) {
            Zielart.Person -> Symbol.Person
            Zielart.Fahrzeug -> Symbol.Zielfahrzeug
            Zielart.Objekt -> Symbol.Objekt
        }
    }

    companion object {
        /** Reihenfolge im Plus-Menü (gleich auf allen Plattformen): Ziele, dann Markierungen. */
        val ziele: List<Anlegbar> = Zielart.entries.map { NeuesZiel(it) }
        val markierungen: List<Anlegbar> = listOf(
            Form.Marker, Form.Text, Form.Fahndungsraum, Form.Kreis, Form.Linie, Form.Pfeil, Form.Flaeche, Form.Haltestellen, Form.Geofence,
        ).map { NeueForm(it) }
        val alle: List<Anlegbar> = ziele + markierungen
    }
}

/** Titel, Symbol und Vorgaben der Markierungsformen. */
object Formen {
    fun titel(f: Form): String = when (f) {
        Form.Marker -> "Marker"
        Form.Text -> "Text"
        Form.Linie -> "Linie"
        Form.Flaeche -> "Fläche"
        Form.Kreis -> "Kreis"
        Form.Fahndungsraum -> "Sichtung"
        Form.Haltestellen -> "Haltestellen im Umkreis"
        Form.OepnvLinie -> "ÖPNV-Strecke"
        Form.OepnvFahrzeug -> "ÖPNV-Fahrzeug"
        Form.Pfeil -> "Pfeil"
        Form.Haltestelle -> "Haltestelle"
        Form.Geofence -> "Geofence"
        Form.Verlauf -> "Verlauf"
    }

    fun symbol(f: Form): Symbol = when (f) {
        Form.Marker -> Symbol.Nadel
        Form.Text -> Symbol.Text
        Form.Fahndungsraum -> Symbol.Fahndungsraum
        Form.Haltestellen, Form.Haltestelle -> Symbol.Haltestelle
        Form.OepnvLinie, Form.OepnvFahrzeug -> Symbol.Bahn
        Form.Geofence -> Symbol.Geofence
        Form.Verlauf -> Symbol.Verlauf
        Form.Kreis -> Symbol.Ziel
        Form.Linie, Form.Pfeil, Form.Flaeche -> Symbol.Verlauf
    }

    fun farbe(f: Form): String = when (f) {
        Form.Fahndungsraum -> "#C97C7C"
        Form.Geofence -> "#FF453A"
        Form.Haltestellen, Form.OepnvLinie, Form.OepnvFahrzeug, Form.Haltestelle -> "#0A84FF"
        else -> "#FF9F0A"
    }

    fun radius(f: Form): Double? = when (f) {
        Form.Kreis, Form.Geofence -> 150.0
        Form.Haltestellen -> 500.0
        else -> null
    }

    /** Neue Markierung mit den Vorgaben ihrer Art. */
    fun entwurf(f: Form, punkte: List<GeoPunkt>, ebene: String, jetztMs: Long): Markierung = Markierung(
        layerId = ebene,
        typ = f,
        farbe = farbe(f),
        punkte = punkte,
        radius = radius(f),
        zeit = if (f == Form.Fahndungsraum || f.istOepnv) jetztMs else null,
        symbol = if (f == Form.Marker) Symbol.Nadel.schluessel else "",
    )
}

/**
 * Platzierungsmodus auf der Karte: Was ein Tipp gerade bewirkt. Unveränderlich; jede Aktion gibt den neuen Zustand
 * zurück. Einzelne Orte erscheinen erst als Vorschau und werden bestätigt, mehrteilige Formen sammeln Punkte.
 * Gleiche Regeln auf allen Plattformen, die Leiste oben zeigt `hinweis` und, falls `kannBestaetigen`, „Fertig“.
 */
data class Platzierung(val zweck: Zweck, val punkte: List<GeoPunkt> = emptyList()) {
    sealed interface Zweck {
        data class Anlegen(val was: Anlegbar) : Zweck
        /** Markierung verschieben: alle Punkte um den Abstand zum neuen Ankerpunkt versetzen. */
        data class Verschieben(val markierungId: String) : Zweck
        /** Ort eines Ziels von Hand setzen. */
        data class ZielOrt(val zielId: String) : Zweck
    }

    val mehrpunkt: Boolean get() = (zweck as? Zweck.Anlegen)?.was.let { it is Anlegbar.NeueForm && it.form.istMehrpunkt }

    private val mindestPunkte: Int get() = ((zweck as? Zweck.Anlegen)?.was as? Anlegbar.NeueForm)?.form?.mindestPunkte ?: 1

    val kannBestaetigen: Boolean get() = punkte.size >= mindestPunkte
    val kannZuruecknehmen: Boolean get() = mehrpunkt && punkte.isNotEmpty()

    val hinweis: String get() = when (val z = zweck) {
        is Zweck.Anlegen -> if (mehrpunkt) "${z.was.titel}: Punkte antippen (${punkte.size} gesetzt)"
        else if (punkte.isEmpty()) "${z.was.titel}: Ort antippen" else "${z.was.titel}: Ort prüfen und bestätigen"
        is Zweck.Verschieben -> if (punkte.isEmpty()) "Neuen Ort antippen" else "Neuen Ort bestätigen"
        is Zweck.ZielOrt -> if (punkte.isEmpty()) "Standort des Ziels antippen" else "Standort bestätigen"
    }

    /** Tipp auf die Karte: Mehrpunkt hängt an, sonst ersetzt der Tipp die Vorschau. */
    fun tippen(p: GeoPunkt): Platzierung = copy(punkte = if (mehrpunkt) punkte + p else listOf(p))

    fun zuruecknehmen(): Platzierung = copy(punkte = punkte.dropLast(1))

    /** Vorschau für die Quelle `s-entwurf`: Punkte, Linie bzw. Fläche, Umkreis. */
    fun vorschau(radius: Double? = null): String {
        val s = Szene()
        val form = ((zweck as? Zweck.Anlegen)?.was as? Anlegbar.NeueForm)?.form
        val m = ArrayList<JsonObject>()
        fun art(a: String) = buildJsonObject { put("art", a) }
        if (form != null) {
            val r = radius ?: Formen.radius(form)
            if (r != null && punkte.isNotEmpty()) m += s.merkmal(s.flaeche(s.kreis(punkte.first(), r)), art("flaeche"))
            if (form == Form.Flaeche && punkte.size >= 3) m += s.merkmal(s.flaeche(punkte), art("flaeche"))
            if (punkte.size >= 2) m += s.merkmal(s.linie(if (form == Form.Flaeche && punkte.size >= 3) punkte + punkte.first() else punkte), art("linie"))
        }
        punkte.forEachIndexed { i, p -> m += s.merkmal(s.punkt(p), buildJsonObject { put("art", "punkt"); put("letzter", i == punkte.lastIndex) }) }
        return s.sammlung(m)
    }

    /** Ergebnis der Platzierung, das die Plattform weitergibt (Editor öffnen bzw. direkt speichern). */
    sealed interface Ergebnis {
        data class NeueMarkierung(val markierung: Markierung) : Ergebnis
        data class NeuesZiel(val ziel: Ziel) : Ergebnis
        data class Verschoben(val id: String, val markierung: Markierung) : Ergebnis
        data class ZielVersetzt(val id: String, val ziel: Ziel) : Ergebnis
    }

    /**
     * Bestätigen. `markierung`/`ziel`: bestehendes Objekt beim Verschieben bzw. Versetzen. `ebene`: Ebene für neue
     * Markierungen. `null`, wenn noch Punkte fehlen oder das Objekt nicht mehr existiert.
     */
    fun bestaetigen(jetztMs: Long, ebene: String = Ebene.LAGE, markierung: Markierung? = null, ziel: Ziel? = null): Ergebnis? {
        if (!kannBestaetigen) return null
        return when (val z = zweck) {
            is Zweck.Anlegen -> when (val was = z.was) {
                is Anlegbar.NeueForm -> Ergebnis.NeueMarkierung(Formen.entwurf(was.form, punkte, ebene, jetztMs))
                is Anlegbar.NeuesZiel -> Ergebnis.NeuesZiel(
                    Ziel(art = was.art, quelle = Standortquelle.Hand, standort = ZeitPunkt(punkte[0].lat, punkte[0].lon, jetztMs)),
                )
            }
            is Zweck.Verschieben -> markierung?.let { Ergebnis.Verschoben(z.markierungId, verschieben(it, punkte[0])) }
            is Zweck.ZielOrt -> ziel?.let {
                Ergebnis.ZielVersetzt(z.zielId, it.copy(quelle = Standortquelle.Hand, standort = ZeitPunkt(punkte[0].lat, punkte[0].lon, jetztMs)))
            }
        }
    }

    companion object {
        fun anlegen(was: Anlegbar, start: GeoPunkt? = null): Platzierung {
            val p = Platzierung(Zweck.Anlegen(was))
            return if (start != null) p.tippen(start) else p
        }

        /** Alle Punkte so versetzen, dass der Ankerpunkt auf `neu` liegt. */
        fun verschieben(m: Markierung, neu: GeoPunkt): Markierung {
            val a = m.anker
            val dLat = neu.lat - a.lat
            val dLon = neu.lon - a.lon
            return m.copy(punkte = m.punkte.map { GeoPunkt(it.lat + dLat, it.lon + dLon) })
        }
    }
}

/**
 * Bearbeitungsstand einer Markierung im Editor, gemeinsam für alle Plattformen: Prüfen und Bereinigen beim Sichern.
 * Die Oberfläche zeigt je nach `typ` die passenden Felder (`zeigt…`).
 */
object Markierungseditor {
    data class Lebensdauer(val sekunden: Int, val titel: String)

    val lebensdauern: List<Lebensdauer> = listOf(
        Lebensdauer(0, "Unbegrenzt"), Lebensdauer(900, "15 Minuten"), Lebensdauer(1800, "30 Minuten"), Lebensdauer(3600, "1 Stunde"),
        Lebensdauer(7200, "2 Stunden"), Lebensdauer(14_400, "4 Stunden"), Lebensdauer(28_800, "8 Stunden"), Lebensdauer(43_200, "12 Stunden"),
        Lebensdauer(86_400, "24 Stunden"), Lebensdauer(259_200, "3 Tage"), Lebensdauer(604_800, "7 Tage"),
    )

    fun zeigtSymbol(m: Markierung) = m.typ == Form.Marker
    fun zeigtFarbe(m: Markierung) = !m.istStandortspur && !m.typ.istOepnv
    fun zeigtRadius(m: Markierung) = m.typ == Form.Kreis || m.typ == Form.Haltestellen || (m.typ == Form.Geofence && m.radius != null)
    fun zeigtLebensdauer(m: Markierung) = m.typ != Form.OepnvFahrzeug
    fun zeigtZiele(m: Markierung) = m.typ == Form.Geofence

    fun radiusBereich(m: Markierung): ClosedFloatingPointRange<Double> = radiusMin(m)..radiusMax(m)
    fun radiusMin(m: Markierung): Double = if (m.typ == Form.Haltestellen) 50.0 else 5.0
    fun radiusMax(m: Markierung): Double = if (m.typ == Form.Haltestellen) 5000.0 else 100_000.0

    /** Schieberegler-Bereich (bis 3 km; größere Werte nur über das Web). */
    fun reglerMax(m: Markierung): Double = minOf(radiusMax(m), 3000.0)

    /** Aktueller Radius für die Anzeige (Vorgabe der Form, falls leer). */
    fun radius(m: Markierung): Double = (m.radius ?: Formen.radius(m.typ) ?: 150.0).coerceIn(radiusMin(m), radiusMax(m))

    /** Geänderter Stand aus den Feldern des Editors (für Plattformen ohne benannte Kopien, etwa Swift). */
    fun aendern(
        m: Markierung, titel: String, notiz: String, farbe: String, symbol: String, radius: Double?, layerId: String,
        ausloeser: Ausloeser?, ziele: List<String>,
    ): Markierung = m.copy(titel = titel, notiz = notiz, farbe = farbe, symbol = symbol, radius = radius, layerId = layerId, ausloeser = ausloeser, ziele = ziele)

    /** Was zum Sichern fehlt; `null` = sicherbar. */
    fun fehlt(m: Markierung): String? = when {
        m.typ == Form.Text && m.titel.isBlank() -> "Text eingeben"
        m.typ.istOepnv && (m.linie == null || m.punkte.size < 2) -> "Linie wählen"
        m.typ == Form.Geofence && m.ziele.isEmpty() -> "Mindestens ein Ziel wählen"
        m.punkte.size < m.typ.mindestPunkte -> "Weitere Punkte setzen"
        else -> null
    }

    /**
     * Bereinigter Stand zum Senden: Längen begrenzt, Radius in den erlaubten Bereich, Ablauf aus der gewählten
     * Lebensdauer (`null` = bisherigen Ablauf behalten).
     */
    fun sichern(m: Markierung, lebensdauerSekunden: Int?, jetztMs: Long): Markierung {
        var r = m.copy(titel = m.titel.trim().take(80), notiz = m.notiz.take(1000), farbe = farbe(m.farbe))
        if (zeigtRadius(m)) {
            val b = radiusBereich(m)
            r = r.copy(radius = (m.radius ?: Formen.radius(m.typ) ?: 150.0).coerceIn(b.start, b.endInclusive))
        }
        if (zeigtLebensdauer(m) && lebensdauerSekunden != null) {
            r = r.copy(ablauf = if (lebensdauerSekunden == 0) null else jetztMs + lebensdauerSekunden * 1000L)
        }
        return r
    }
}

/** Schnellerfassung eines neuen Ziels: Felder übernehmen und bereinigen (gleich auf allen Plattformen). */
object Zielerfassung {
    fun fertig(z: Ziel, vorname: String, nachname: String, bezeichnung: String, kennzeichen: String, anschrift: String, hinweise: String): Ziel = z.copy(
        vorname = vorname.trim().take(80),
        nachname = nachname.trim().take(80),
        bezeichnung = bezeichnung.trim().take(120),
        kennzeichen = kennzeichen.trim().uppercase().take(20),
        anschrift = anschrift.trim().take(200),
        hinweise = hinweise.take(4000),
    )
}
