package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.lage.Zieleditor
import de.nglab.sentinel.kern.lage.Zielgruppen
import de.nglab.sentinel.kern.lage.Zielverzeichnis
import de.nglab.sentinel.kern.modell.Bindung
import de.nglab.sentinel.kern.modell.BindungsArt
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.modell.Ziel
import de.nglab.sentinel.kern.modell.Zielart
import de.nglab.sentinel.kern.modell.Zielgruppe
import de.nglab.sentinel.kern.netz.Suchtreffer
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ZiellisteTest {
    private fun <T : Any> v(id: String, d: T) = Versioniert(id, data = d)

    private val stand = LageStand(
        ziele = mapOf(
            "p" to v("p", Ziel(vorname = "Max", nachname = "Müller", gruppeId = "g", bindung = Bindung(BindungsArt.Fahrzeug, "f"))),
            "f" to v("f", Ziel(art = Zielart.Fahrzeug, kennzeichen = "B-XY 123")),
            "o" to v("o", Ziel(art = Zielart.Objekt, bezeichnung = "Lager", anschrift = "Hafenstraße 1")),
        ),
        zielgruppen = mapOf("g" to v("g", Zielgruppe("Bande")), "leer" to v("leer", Zielgruppe("Leer"))),
    )

    @Test
    fun sucheUeberNameKennzeichenAnschrift() {
        assertTrue(Zielverzeichnis.trifft(stand.ziele["p"]!!.data, "mull"))
        assertTrue(Zielverzeichnis.trifft(stand.ziele["f"]!!.data, "bxy123"))
        assertTrue(Zielverzeichnis.trifft(stand.ziele["o"]!!.data, "hafen"))
        assertFalse(Zielverzeichnis.trifft(stand.ziele["o"]!!.data, "max"))
    }

    @Test
    fun abschnitteZeigenLeereGruppenNurOhneSuche() {
        assertEquals(listOf("Bande", "Leer", "Ohne Gruppe"), Zielverzeichnis.abschnitte(stand).map { it.titel })
        assertEquals(listOf("Ohne Gruppe"), Zielverzeichnis.abschnitte(stand, "lager").map { it.titel })
    }

    @Test
    fun insassenUndZuordnen() {
        assertEquals(listOf("p"), Zielverzeichnis.insassen(stand, "f").map { it.id })
        val aenderungen = Zielverzeichnis.zuordnen(stand, listOf("p", "f"), "g")
        assertEquals(listOf("f"), aenderungen.map { it.first })
        assertEquals(listOf("p"), Zielverzeichnis.gruppeLoesen(stand, "g").map { it.first })
        assertEquals(Zielgruppen.farben[1], Zielgruppen.vorschlag(stand))
    }

    @Test
    fun anschriftSetztStandort() {
        val z = Zieleditor.anschriftUebernehmen(Ziel(), Suchtreffer("1", "Hafenstraße 1", "20457 Hamburg", GeoPunkt(53.5, 9.9), "anschrift"), 5)
        assertEquals("Hafenstraße 1, 20457 Hamburg", z.anschrift)
        assertEquals(53.5, z.standort?.lat)
        assertFalse(Zieleditor.mitAufzeichnung(z, false).aufzeichnung)
    }
}

class FahrzeugeditorTest {
    @Test
    fun fahrzeugBearbeitenUndSuchen() {
        var v = de.nglab.sentinel.kern.lage.Fahrzeugeditor.neu()
        kotlin.test.assertNotNull(de.nglab.sentinel.kern.lage.Fahrzeugeditor.fehlt(v))
        v = de.nglab.sentinel.kern.lage.Fahrzeugeditor.setzen(v, "funkrufname", " Adler 21 ")
        v = de.nglab.sentinel.kern.lage.Fahrzeugeditor.setzen(v, "kennzeichen", "hh-ab 12")
        v = de.nglab.sentinel.kern.lage.Fahrzeugeditor.fertig(v)
        assertEquals("Adler 21", v.funkrufname)
        assertEquals("HH-AB 12", v.kennzeichen)
        assertTrue(de.nglab.sentinel.kern.lage.Kraeftesuche.fahrzeug(v, "hhab12"))
        assertTrue(de.nglab.sentinel.kern.lage.Kraeftesuche.fahrzeug(v, "adler"))
        assertFalse(de.nglab.sentinel.kern.lage.Kraeftesuche.fahrzeug(v, "bär"))
    }
}

class KartenstilTest {
    @Test
    fun stilUndAusblenden() {
        val e = de.nglab.sentinel.kern.karte.Kartenebenen.standard
        assertEquals("https://s/karte/stil/dunkel.json", e.stilAdresse("https://s", true))
        val sat = e.mitGrundkarte(de.nglab.sentinel.kern.karte.Kartenebenen.SATELLIT).mitDreiD(false)
        assertEquals("https://s/karte/stil/satellit-flach.json", sat.stilAdresse("https://s", false))
        assertTrue(sat.veraendert)
        val aus = e.mitZielart(Zielart.Fahrzeug, false).mitGruppe("g", false)
        assertTrue(aus.anzeige.zielAusgeblendet(Ziel(art = Zielart.Fahrzeug)))
        assertTrue(aus.anzeige.zielAusgeblendet(Ziel(gruppeId = "g")))
        assertFalse(aus.anzeige.zielAusgeblendet(Ziel()))
        assertTrue(aus.mitGruppe("g", true).gruppeAn("g"))
    }
}
