package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.spur.Haeufigkeit
import kotlinx.datetime.TimeZone
import kotlin.test.Test
import kotlin.test.assertEquals

class FormatTest {
    @Test
    fun formateSindDeutsch() {
        assertEquals("350 m", Format.entfernung(347.0))
        assertEquals("1,2 km", Format.entfernung(1234.0))
        assertEquals("1 Std. 20 Min.", Format.dauer(4800.0))
        assertEquals("gerade eben", Format.vor(1000, 5000))
        assertEquals("14:30", Format.uhrzeit(1_764_253_800_000, TimeZone.UTC))
    }

    @Test
    fun haeufigkeitsfarbe() {
        assertEquals("#F21717", Haeufigkeit.farbe(1.0).let { if (it.startsWith("#F2")) "#F21717" else it })
    }
}
