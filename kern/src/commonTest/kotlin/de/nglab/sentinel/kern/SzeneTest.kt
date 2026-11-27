package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.karte.Auffaechern
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.karte.Quellen
import de.nglab.sentinel.kern.karte.Szene
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.ZeitPunkt
import de.nglab.sentinel.kern.protokoll.json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SzeneTest {
    private val lage = LageStand(
        hatStand = true,
        ziele = mapOf("z1" to Versioniert("z1", data = Ziel(vorname = "Max", nachname = "Muster", standort = ZeitPunkt(53.5, 10.0, 1)))),
        markierungen = mapOf(
            "m1" to Versioniert("m1", data = Markierung(layerId = "lage", typ = Form.Marker, titel = "Treff", punkte = listOf(GeoPunkt(53.51, 10.01)))),
            "m2" to Versioniert("m2", data = Markierung(layerId = "lage", typ = Form.Pfeil, punkte = listOf(GeoPunkt(53.5, 10.0), GeoPunkt(53.51, 10.0)))),
            "alt" to Versioniert("alt", data = Markierung(layerId = "lage", typ = Form.Marker, punkte = listOf(GeoPunkt(53.5, 10.0)), ablauf = 5)),
        ),
    )

    @Test
    fun symboleUndLinienEntstehenAbgelaufeneNicht() {
        val q = Szene().aufbauen(lage, jetztMs = 1000)
        val symbole = json.parseToJsonElement(q[Quellen.SYMBOLE]!!).jsonObject["features"]!!.jsonArray
        val ids = symbole.map { it.jsonObject["properties"]!!.jsonObject["id"]!!.jsonPrimitive.content }.toSet()
        assertEquals(setOf("ziel:z1", "markierung:m1"), ids)
        val linien = json.parseToJsonElement(q[Quellen.LINIEN]!!).jsonObject["features"]!!.jsonArray
        assertEquals(2, linien.size, "Pfeil mit Spitze")
    }

    @Test
    fun kennungAusMerkmal() {
        assertEquals(KartenObjekt(Objektart.Ziel, "z1"), KartenObjekt.von("ziel:z1"))
    }

    @Test
    fun auffaechernNurNahUndStabil() {
        val punkte = listOf("b" to GeoPunkt(53.5, 10.0), "a" to GeoPunkt(53.50001, 10.00001), "c" to GeoPunkt(53.6, 10.0))
        assertTrue(Auffaechern.versatz(punkte, 12.0).isEmpty())
        val v = Auffaechern.versatz(punkte, 17.0)
        assertEquals(setOf("a", "b"), v.keys)
        assertTrue(v["a"]!!.second < v["b"]!!.second, "feste Reihenfolge nach Kennung")
    }
}
