package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.karte.Farben
import de.nglab.sentinel.kern.karte.Formen
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.karte.Symbol
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.Fortbewegung
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Zielart

/** Aktionen der Kurzübersicht; die Plattform zeigt sie als Knöpfe in dieser Reihenfolge. */
enum class Kurzaktion(val titel: String) {
    Hinfuehren("Hinführen"),
    Bearbeiten("Bearbeiten"),
    Verschieben("Verschieben"),
    StandortSetzen("Standort setzen"),
    Anrufen("Anrufen"),
    Details("Details"),
}

/** Zeile der Kurzübersicht: Bezeichnung und Wert. */
data class Kurzzeile(val titel: String, val wert: String)

/**
 * Inhalt der Kurzübersicht eines angetippten Objekts, gemeinsam für alle Plattformen: Kopfzeile (Symbol, Farbe,
 * Titel, Untertitel), Zeilen mit Ort, Zeit und Entfernung, und die passenden Aktionen.
 */
data class Kurzinfo(
    val titel: String,
    val untertitel: String,
    val farbe: String,
    val symbol: Symbol,
    val zeilen: List<Kurzzeile>,
    val ort: GeoPunkt?,
    val aktionen: List<Kurzaktion>,
    val telefon: String? = null,
) {
    companion object {
        /** `null`, wenn das Objekt nicht (mehr) in der Lage ist. `ich`: eigener Standort für die Entfernung. */
        fun fuer(stand: LageStand, objekt: KartenObjekt, jetztMs: Long, ich: GeoPunkt?): Kurzinfo? {
            fun entfernung(p: GeoPunkt?): Kurzzeile? = if (p != null && ich != null) Kurzzeile("Entfernung", Format.entfernung(ich.distanz(p))) else null
            fun stand(ms: Long?, herkunft: String? = null): Kurzzeile? =
                ms?.let { Kurzzeile("Stand", listOfNotNull(Format.vor(it, jetztMs), herkunft).joinToString(" · ")) }

            return when (objekt.art) {
                Objektart.Kraft -> {
                    val f = stand.fahnder[objekt.id] ?: return null
                    val pos = stand.positionen[f.id]
                    val istA = stand.einsatz.a?.memberId == f.id
                    Kurzinfo(
                        titel = f.data.spitzname,
                        untertitel = listOfNotNull(if (istA) "A-Position" else null, if (f.data.aktiv) stand.fortbewegungText(f.data) else "Ruhemodus").joinToString(" · "),
                        farbe = if (istA) Farben.A_POSITION else Farben.KRAEFTE,
                        symbol = when (f.data.fortbewegung) {
                            Fortbewegung.Fuss -> Symbol.Fuss
                            Fortbewegung.Fahrzeug -> Symbol.Fahrzeug
                            Fortbewegung.Oepnv -> Symbol.Oepnv
                        },
                        zeilen = listOfNotNull(
                            f.data.dienststelle.takeIf { it.isNotBlank() }?.let { Kurzzeile("Dienststelle", it) },
                            Kurzzeile("Verbindung", if (stand.istOnline(f.id)) "Online" else "Nicht verbunden"),
                            pos?.spd?.takeIf { it > 1 }?.let { Kurzzeile("Tempo", Format.kmh(it)) },
                            stand(pos?.ts),
                            entfernung(pos?.punkt),
                        ),
                        ort = pos?.punkt,
                        aktionen = listOfNotNull(
                            Kurzaktion.Hinfuehren.takeIf { pos != null && f.id != stand.ichId },
                            Kurzaktion.Anrufen.takeIf { f.data.telefon.isNotBlank() && f.id != stand.ichId },
                        ),
                        telefon = f.data.telefon.takeIf { it.isNotBlank() },
                    )
                }

                Objektart.Fahrzeug -> {
                    val v = stand.fahrzeuge[objekt.id] ?: return null
                    val o = stand.ortung(v)
                    val insassen = stand.insassen(v.id)
                    Kurzinfo(
                        titel = v.data.funkrufname,
                        untertitel = listOf(v.data.kennzeichen, v.data.zusatz).filter { it.isNotBlank() }.joinToString(" · "),
                        farbe = Farben.KRAEFTE,
                        symbol = Symbol.Fahrzeug,
                        zeilen = listOfNotNull(
                            Kurzzeile("Besatzung", insassen.joinToString(", ") { it.data.spitzname }.ifBlank { "Niemand" }),
                            stand(o?.zeitMs, when (o?.herkunft) {
                                Herkunft.Tracker -> "Tracker"
                                Herkunft.Abgestellt -> "abgestellt"
                                Herkunft.Besatzung -> "Besatzung"
                                else -> null
                            }),
                            entfernung(o?.punkt),
                        ),
                        ort = o?.punkt,
                        aktionen = listOfNotNull(Kurzaktion.Hinfuehren.takeIf { o != null }),
                    )
                }

                Objektart.Ziel -> {
                    val z = stand.ziele[objekt.id] ?: return null
                    val o = stand.ortung(z, jetztMs)
                    Kurzinfo(
                        titel = z.data.anzeigename,
                        untertitel = listOfNotNull(
                            when (z.data.art) { Zielart.Person -> "Zielperson"; Zielart.Fahrzeug -> "Zielfahrzeug"; Zielart.Objekt -> "Zielobjekt" },
                            z.data.zweiteZeile,
                        ).joinToString(" · "),
                        farbe = Farben.ZIELE,
                        symbol = when (z.data.art) { Zielart.Person -> Symbol.Person; Zielart.Fahrzeug -> Symbol.Zielfahrzeug; Zielart.Objekt -> Symbol.Objekt },
                        zeilen = listOfNotNull(
                            z.data.anschrift.takeIf { it.isNotBlank() }?.let { Kurzzeile("Anschrift", it) },
                            stand(o?.zeitMs, when (o?.herkunft) {
                                Herkunft.Tracker -> "Tracker"
                                Herkunft.APosition -> "folgt der A-Position"
                                Herkunft.Oepnv -> "im ÖPNV"
                                Herkunft.Gebunden -> "eingestiegen"
                                Herkunft.Hand -> "von Hand"
                                else -> null
                            }),
                            entfernung(o?.punkt),
                            z.data.freitext.takeIf { it.isNotBlank() }?.let { Kurzzeile("Hinweise", it.take(200)) },
                        ),
                        ort = o?.punkt,
                        aktionen = listOfNotNull(Kurzaktion.Hinfuehren.takeIf { o != null }, Kurzaktion.StandortSetzen, Kurzaktion.Details),
                    )
                }

                Objektart.Markierung -> {
                    val m = stand.markierungen[objekt.id] ?: return null
                    val d = m.data
                    val p = stand.ortung(d, jetztMs)
                    Kurzinfo(
                        titel = d.titel.ifBlank { Formen.titel(d.typ) },
                        untertitel = listOfNotNull(Formen.titel(d.typ).takeIf { d.titel.isNotBlank() }, stand.ebenen[d.layerId]?.data?.name).joinToString(" · "),
                        farbe = d.farbe,
                        symbol = if (d.typ == Form.Marker) Symbol.vonGespeichert(d.symbol) else Formen.symbol(d.typ),
                        zeilen = listOfNotNull(
                            d.notiz.takeIf { it.isNotBlank() }?.let { Kurzzeile("Notiz", it.take(300)) },
                            d.radius?.let { Kurzzeile(if (d.typ == Form.Haltestellen) "Umkreis" else "Radius", Format.entfernung(it)) },
                            d.zeit?.let { Kurzzeile("Gesehen", Format.vor(it, jetztMs)) },
                            d.ablauf?.let { Kurzzeile("Läuft ab", Format.ablauf(it, jetztMs)) },
                            Kurzzeile("Geändert", "${stand.name(m.updatedBy)}, ${Format.vor(m.updatedAt, jetztMs)}"),
                            entfernung(p),
                        ),
                        ort = p,
                        aktionen = listOfNotNull(
                            Kurzaktion.Hinfuehren,
                            Kurzaktion.Bearbeiten,
                            Kurzaktion.Verschieben.takeIf { !d.typ.istOepnv && !d.istStandortspur },
                        ),
                    )
                }

                else -> null
            }
        }
    }
}
