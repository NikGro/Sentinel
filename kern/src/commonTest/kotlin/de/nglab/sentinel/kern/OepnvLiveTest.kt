package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.oepnv.Fahrt
import de.nglab.sentinel.kern.oepnv.FahrtHalt
import de.nglab.sentinel.kern.oepnv.LiveAbschnitt
import de.nglab.sentinel.kern.oepnv.LiveHalt
import de.nglab.sentinel.kern.oepnv.Linienart
import de.nglab.sentinel.kern.oepnv.OepnvLive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class OepnvLiveTest {
    @Test
    fun farbenUndArten() {
        assertEquals("subway", Linienart.typ("SUBWAY"))
        assertEquals("#FFDD00", Linienart.farbe("subway", "U3"))
        assertEquals("#00A651", Linienart.farbe("train", "S1"))
        assertEquals("#E2001A", Linienart.farbe("bus", "5", "FFFFFF"))
        assertEquals("+3 Min.", Linienart.verspaetung(170, true))
    }

    @Test
    fun fahrtWirdAlsStreckeUebernommen() {
        val f = Fahrt("t1", "U3", "SUBWAY", "Barmbek", null, listOf(FahrtHalt("A", "a", 53.0, 10.0, null, 1000), FahrtHalt("B", "b", 53.01, 10.0, 61_000, null)))
        val m = OepnvLive.alsStrecke(f, fahrzeug = true, strecke = false, halte = false, jetztMs = 0)!!
        assertEquals(Form.OepnvLinie, m.typ)
        assertEquals("U3 → Barmbek", m.titel)
        assertEquals(listOf(1000L, 61_000L), m.fahrt?.zeiten)
        assertEquals(361_000L, m.ablauf)
    }

    @Test
    fun positionNurImAbschnitt() {
        val live = OepnvLive()
        val a = LiveAbschnitt("t", "5", "BUS", LiveHalt("A", "a", 53.0, 10.0), LiveHalt("B", "b", 53.01, 10.0), 0, 120_000)
        val p = live.position(a, 60_000)
        assertNotNull(p)
        assertTrue(p.lat > 53.0 && p.lat < 53.01)
        assertNull(live.position(a, 500_000))
    }
}

class HalteVorausTest {
    @Test
    fun zweiHalteVorDemFahrzeug() {
        val halte = (0..4).map { de.nglab.sentinel.kern.modell.GeoPunkt(53.0 + it * 0.01, 10.0) }
        val zeiten = (0..4).map { (it * 120_000).toLong() as Long? }
        val m = de.nglab.sentinel.kern.modell.Markierung(
            layerId = "lage", typ = Form.OepnvLinie, punkte = halte, haltNamen = listOf("A", "B", "C", "D", "E"),
            linie = de.nglab.sentinel.kern.modell.Linienverweis("t", "U3", "subway"),
            fahrt = de.nglab.sentinel.kern.modell.OepnvFahrtDaten("t", zeiten),
        )
        // Zwischen A und B unterwegs: 1 voraus = B, 2 voraus = C
        assertEquals("B", de.nglab.sentinel.kern.oepnv.OepnvSimulation.haltVoraus(m, 60_000, 1)?.second)
        assertEquals("C", de.nglab.sentinel.kern.oepnv.OepnvSimulation.haltVoraus(m, 60_000, 2)?.second)
        assertNull(de.nglab.sentinel.kern.oepnv.OepnvSimulation.haltVoraus(m, 10_000_000, 1))
    }
}
