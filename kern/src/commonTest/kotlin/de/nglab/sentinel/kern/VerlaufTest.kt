package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Fahnder
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.spur.Verlauf
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class VerlaufTest {
    @Test
    fun standortspurLaeuftAbJetzt() {
        val stand = LageStand(ichId = "ich", fahnder = mapOf("ich" to Versioniert("ich", data = Fahnder("Max", "Adler", "PK 1"))))
        val m = Verlauf.standortspur(stand, GeoPunkt(53.0, 10.0), 1000)!!
        assertEquals(Form.Verlauf, m.typ)
        assertTrue(m.istStandortspur && m.standortspurNachHaeufigkeit)
        assertEquals(1000L, m.zeitVon)
        assertNull(m.zeitBis)
        assertEquals("member", m.spuren.first().art)
        assertNull(Verlauf.standortspur(LageStand(), GeoPunkt(53.0, 10.0), 0))
    }

    @Test
    fun zeitraeumeEndenJetzt() {
        val z = Verlauf.zeitraeume(10_000_000, 9_000_000)
        assertEquals(5, z.size)
        assertEquals(9_000_000L, z[2].vonMs)
        assertTrue(z.all { it.bisMs == 10_000_000L })
    }
}

class KartenebenenTest {
    @Test
    fun umschaltenUndModi() {
        val e = de.nglab.sentinel.kern.karte.Kartenebenen()
        assertEquals(listOf("fuss", "kfz"), e.wegZeitModi)
        val f = e.mit("wegZeitOepnv", true).mit("wegZeitFuss", false)
        assertEquals(listOf("kfz", "oepnv"), f.wegZeitModi)
        assertTrue(f.mit("verkehr", true).an("verkehr"))
    }
}

class VerwaltungTest {
    @Test
    fun nurErstellerBearbeitetHauptinstanzBleibt() {
        val stand = LageStand(ichId = "ich", instanz = "x")
        val eigene = Versioniert("x", data = de.nglab.sentinel.kern.modell.Instanz("Einsatz", mitglieder = listOf("ich", "b"), erstelltVon = "ich"))
        val fremde = Versioniert("y", data = de.nglab.sentinel.kern.modell.Instanz("Andere", erstelltVon = "b"))
        val haupt = Versioniert("haupt", data = de.nglab.sentinel.kern.modell.Instanz("KSOD"))
        assertTrue(de.nglab.sentinel.kern.lage.Verwaltung.darfBearbeiten(stand, eigene))
        assertTrue(!de.nglab.sentinel.kern.lage.Verwaltung.darfBearbeiten(stand, fremde))
        assertTrue(!de.nglab.sentinel.kern.lage.Verwaltung.darfBearbeiten(stand, haupt))
        assertEquals("2 Mitglieder", de.nglab.sentinel.kern.lage.Verwaltung.beschreibung(stand, eigene))
    }
}

class MeldungenTest {
    @Test
    fun fremderNotrufIstAlarm() {
        val stand = LageStand(fahnder = mapOf("b" to Versioniert("b", data = Fahnder("B", "Bär", "PK"))))
        val m = de.nglab.sentinel.kern.lage.Meldungen.aus(de.nglab.sentinel.kern.lage.LageEreignis.NotrufBegonnen("b", false), stand)!!
        assertEquals(de.nglab.sentinel.kern.lage.Dringlichkeit.Alarm, m.dringlichkeit)
        assertTrue(m.systemmitteilung)
        assertNull(de.nglab.sentinel.kern.lage.Meldungen.anzeigedauerMs(m))
    }
}

class AppSperreTest {
    @Test
    fun sperrtNachFrist() {
        val s = de.nglab.sentinel.kern.lage.AppSperre
        assertTrue(s.sperren(true, 0, 1000, 1000))
        assertTrue(!s.sperren(true, 60, 0, 30_000))
        assertTrue(s.sperren(true, 60, 0, 60_000))
        assertTrue(!s.sperren(false, 0, 0, 99_999))
        assertTrue(!s.sperren(true, 0, null, 5))
    }
}
