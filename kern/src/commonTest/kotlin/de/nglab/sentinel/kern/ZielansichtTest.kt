package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.lage.Bindungsziel
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.lage.Zieleditor
import de.nglab.sentinel.kern.modell.BindungsArt
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.ZeitPunkt
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielart
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class ZielansichtTest {
    @Test
    fun geburtsdatumWirdGeprueftUndUmgewandelt() {
        assertEquals("1990-05-03", Zieleditor.datumSpeichern("3.5.1990"))
        assertNull(Zieleditor.datumSpeichern("31.02.1990"))
        assertEquals("03.05.1990", Zieleditor.datumAnzeigen("1990-05-03"))
        assertEquals(36, Zieleditor.alter("1990-05-03", 2026, 5, 3))
        assertEquals(35, Zieleditor.alter("1990-05-03", 2026, 5, 2))
        val z = Zieleditor.setzen(Ziel(), "geburtsdatum", "40.1.2000")
        assertNotNull(Zieleditor.fehlt(z))
        assertEquals("2000-01-04", Zieleditor.fertig(Zieleditor.setzen(Ziel(), "geburtsdatum", "4.1.2000")).geburtsdatum)
    }

    @Test
    fun einsteigenUndAussteigenAmOrtDesFahrzeugs() {
        val stand = LageStand(
            ziele = mapOf(
                "p" to Versioniert("p", data = Ziel(art = Zielart.Person, standort = ZeitPunkt(53.0, 10.0, 0))),
                "f" to Versioniert("f", data = Ziel(art = Zielart.Fahrzeug, kennzeichen = "HH X 1", standort = ZeitPunkt(54.0, 11.0, 0))),
            ),
        )
        val ziele = Zieleditor.bindungsziele(stand, "p")
        assertEquals(listOf(BindungsArt.Fuss, BindungsArt.Fahrzeug), ziele.map { it.art })
        val drin = Zieleditor.binden(stand, "p", ziele[1], 5)!!
        assertEquals("f", drin.bindung?.zielId)
        val neu = stand.copy(ziele = stand.ziele + ("p" to Versioniert("p", data = drin)))
        val raus = Zieleditor.binden(neu, "p", Bindungsziel(BindungsArt.Fuss, null, ""), 9)!!
        assertNull(raus.bindung)
        assertEquals(54.0, raus.standort?.lat)
    }
}
