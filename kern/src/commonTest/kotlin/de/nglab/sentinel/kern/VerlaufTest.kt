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
