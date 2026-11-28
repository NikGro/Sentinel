package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.karte.Anlegbar
import de.nglab.sentinel.kern.karte.Markierungseditor
import de.nglab.sentinel.kern.karte.Platzierung
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Standortquelle
import de.nglab.sentinel.kern.modell.Zielart
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class PlatzierungTest {
    private val a = GeoPunkt(52.5, 13.4)
    private val b = GeoPunkt(52.51, 13.41)
    private val c = GeoPunkt(52.52, 13.39)

    @Test
    fun einzelpunktErsetztVorschau() {
        var p = Platzierung.anlegen(Anlegbar.NeueForm(Form.Marker))
        assertFalse(p.kannBestaetigen)
        p = p.tippen(a).tippen(b)
        assertEquals(listOf(b), p.punkte)
        val e = p.bestaetigen(1000) as Platzierung.Ergebnis.NeueMarkierung
        assertEquals(Form.Marker, e.markierung.typ)
        assertEquals("nadel", e.markierung.symbol)
    }

    @Test
    fun flaecheBrauchtDreiPunkte() {
        var p = Platzierung.anlegen(Anlegbar.NeueForm(Form.Flaeche)).tippen(a).tippen(b)
        assertTrue(p.mehrpunkt)
        assertFalse(p.kannBestaetigen)
        assertNull(p.bestaetigen(0))
        p = p.tippen(c)
        assertTrue(p.kannBestaetigen)
        assertEquals(2, p.zuruecknehmen().punkte.size)
        assertTrue(p.vorschau().contains("Polygon"))
    }

    @Test
    fun neuesZielVonHand() {
        val e = Platzierung.anlegen(Anlegbar.NeuesZiel(Zielart.Fahrzeug), a).bestaetigen(5) as Platzierung.Ergebnis.NeuesZiel
        assertEquals(Standortquelle.Hand, e.ziel.quelle)
        assertEquals(5, e.ziel.standort?.ts)
    }

    @Test
    fun verschiebenVersetztAllePunkte() {
        val m = Markierung(layerId = "lage", typ = Form.Linie, punkte = listOf(a, b))
        val neu = Platzierung.verschieben(m, GeoPunkt(53.5, 13.4))
        assertEquals(53.51, neu.punkte[1].lat, 1e-9)
    }

    @Test
    fun editorPrueftUndBereinigt() {
        val t = Markierung(layerId = "lage", typ = Form.Text, punkte = listOf(a))
        assertNotNull(Markierungseditor.fehlt(t))
        val k = Markierung(layerId = "lage", typ = Form.Kreis, punkte = listOf(a), radius = 1.0, titel = "  x  ")
        val s = Markierungseditor.sichern(k, 3600, 1000)
        assertEquals(5.0, s.radius)
        assertEquals("x", s.titel)
        assertEquals(1000 + 3_600_000L, s.ablauf)
        assertNull(Markierungseditor.sichern(k.copy(ablauf = 9), 0, 0).ablauf)
        assertEquals(9, Markierungseditor.sichern(k.copy(ablauf = 9), null, 0).ablauf)
    }
}
