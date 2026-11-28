@file:OptIn(kotlin.js.ExperimentalJsExport::class)

package de.nglab.sentinel.kern.web

import de.nglab.sentinel.kern.karte.Anzeige
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Quellen
import de.nglab.sentinel.kern.karte.Symbol
import de.nglab.sentinel.kern.karte.Szene
import de.nglab.sentinel.kern.lage.Kurzinfo
import de.nglab.sentinel.kern.lage.Lage
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Brücke für Sentinel Web: Das Web reicht jede Nachricht seiner Server-Verbindung unverändert hierher und erhält
 * dieselben Kartenquellen (GeoJSON für den gemeinsamen Stil) und Kurzübersichten wie die Apps. So zeigt das Web die
 * Lage genau wie iOS und Android, ohne die Regeln ein zweites Mal zu schreiben.
 */
@JsExport
class WebLage {
    private val lage = Lage()
    private val szene = Szene()

    /** Eine Nachricht vom Server (Schnappschuss, Änderung, Position …). */
    fun empfangen(text: String) {
        lage.empfangen(text)
    }

    private fun anzeige(ebenen: Array<String>, zielarten: Array<String>, gruppen: Array<String>) = Anzeige(
        ausgeblendeteEbenen = ebenen.toSet(),
        ausgeblendeteZielarten = de.nglab.sentinel.kern.modell.Zielart.entries.filter { it.name.lowercase() in zielarten }.toSet(),
        ausgeblendeteGruppen = gruppen.toSet(),
    )

    /**
     * Alle Kartenquellen als JSON-Objekt { "s-symbole": "<GeoJSON>", … }. Ausgeblendet: Ebenen, Zielarten
     * („person“, „fahrzeug“, „objekt“) und Zielgruppen.
     */
    fun quellen(jetztMs: Double, zoom: Double, ausgeblendeteEbenen: Array<String>, ausgeblendeteZielarten: Array<String>, ausgeblendeteGruppen: Array<String>): String = buildJsonObject {
        for ((id, json) in szene.aufbauen(lage.stand.value, jetztMs.toLong(), anzeige(ausgeblendeteEbenen, ausgeblendeteZielarten, ausgeblendeteGruppen), zoom)) put(id, json)
    }.toString()

    /** ÖPNV-Fahrzeuge zur Zeit `jetztMs` (für den schnellen Takt, Quelle `s-oepnv-fahrzeuge`). */
    fun oepnvFahrzeuge(jetztMs: Double, ausgeblendeteEbenen: Array<String>): String =
        szene.oepnvFahrzeuge(lage.stand.value, jetztMs.toLong(), Anzeige(ausgeblendeteEbenen.toSet()))

    /** Stiladresse (relativ zum Server) für Grundkarte („standard“, „satellit“), hell/dunkel und 3D. */
    fun stilAdresse(grundkarte: String, dunkel: Boolean, dreiD: Boolean): String =
        de.nglab.sentinel.kern.karte.Kartenebenen(grundkarte = grundkarte, dreiD = dreiD).stilAdresse("", dunkel)

    private val tippfolge = de.nglab.sentinel.kern.karte.Tippfolge()

    /** Getroffene Objekte (oberstes zuerst) → gewähltes; mehrfaches Tippen schaltet durch. */
    fun tippen(treffer: Array<String>, jetztMs: Double): String? = tippfolge.waehlen(treffer.toList(), jetztMs.toLong())?.schluessel

    /** Name der Quelle für ÖPNV-Fahrzeuge (damit das Web keine festen Namen braucht). */
    val quelleOepnvFahrzeuge: String get() = Quellen.OEPNV_FAHRZEUGE

    /**
     * Kurzübersicht eines angetippten Objekts (`schluessel` = „art:kennung“ aus dem Merkmal) als JSON:
     * { titel, untertitel, farbe, symbol (Material-Name), zeilen: [[titel, wert]], ort: [lat, lon] | null }.
     */
    fun kurzinfo(schluessel: String, jetztMs: Double): String? {
        val o = KartenObjekt.von(schluessel) ?: return null
        val k = Kurzinfo.fuer(lage.stand.value, o, jetztMs.toLong(), null) ?: return null
        return buildJsonObject {
            put("titel", k.titel)
            put("untertitel", k.untertitel)
            put("farbe", k.farbe)
            put("symbol", k.symbol.material)
            put("zeilen", buildJsonArray { k.zeilen.forEach { z -> add(buildJsonArray { add(JsonPrimitive(z.titel)); add(JsonPrimitive(z.wert)) }) } })
            put("ort", k.ort?.let { buildJsonArray { add(JsonPrimitive(it.lat)); add(JsonPrimitive(it.lon)) } } ?: kotlinx.serialization.json.JsonNull)
        }.toString()
    }

    /** Material-Symbolname zu einem Kartenbild `sym-<schlüssel>` (für die Bilder, die der Stil anfordert). */
    fun symbolFuerBild(bildname: String): String? = Symbol.entries.firstOrNull { it.bildname == bildname }?.material
}
