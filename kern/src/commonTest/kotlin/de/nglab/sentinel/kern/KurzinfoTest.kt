package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.Kurzaktion
import de.nglab.sentinel.kern.lage.Kurzinfo
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.ZeitPunkt
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielart
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class KurzinfoTest {
    private val stand = LageStand(
        markierungen = mapOf("m" to Versioniert("m", data = Markierung(layerId = "lage", typ = Form.Kreis, punkte = listOf(GeoPunkt(53.0, 10.0)), radius = 150.0))),
        ziele = mapOf("z" to Versioniert("z", data = Ziel(art = Zielart.Fahrzeug, kennzeichen = "HH AB 1", standort = ZeitPunkt(53.0, 10.01, 0)))),
    )

    @Test
    fun markierungMitRadiusUndAktionen() {
        val k = Kurzinfo.fuer(stand, KartenObjekt(Objektart.Markierung, "m"), 60_000, GeoPunkt(53.0, 10.0))!!
        assertEquals("Kreis", k.titel)
        assertTrue(k.zeilen.any { it.titel == "Radius" && it.wert == "150 m" })
        assertEquals(listOf(Kurzaktion.Hinfuehren, Kurzaktion.Bearbeiten, Kurzaktion.Verschieben), k.aktionen)
    }

    @Test
    fun zielMitEntfernung() {
        val k = Kurzinfo.fuer(stand, KartenObjekt(Objektart.Ziel, "z"), 60_000, GeoPunkt(53.0, 10.0))!!
        assertEquals("HH AB 1", k.titel)
        assertTrue(k.zeilen.any { it.titel == "Entfernung" })
        assertNull(Kurzinfo.fuer(stand, KartenObjekt(Objektart.Ziel, "weg"), 0, null))
    }
}
