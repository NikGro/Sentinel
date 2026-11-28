package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.navi.Anfrageoptionen
import de.nglab.sentinel.kern.navi.Manoever
import de.nglab.sentinel.kern.navi.Nachfuehrung
import de.nglab.sentinel.kern.navi.Routenanfrage
import de.nglab.sentinel.kern.navi.Routeninfo
import de.nglab.sentinel.kern.navi.Strassenname
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class NavigationTest {
    @Test
    fun strasseAusAnschrift() {
        assertEquals("Musterstraße", Strassenname.aus("Musterstraße 3, 22391 Hamburg"))
        assertEquals("Am Weiher", Strassenname.aus("Am Weiher 12a"))
        assertNull(Strassenname.aus("Hauptbahnhof"))
    }

    @Test
    fun anfrageWirdErgaenzt() {
        val body = """{"costing":"auto","locations":[{"lat":1,"lon":2},{"lat":3,"lon":4}]}"""
        val neu = Routenanfrage.anpassen(body, Anfrageoptionen(sonderrechte = true, zuFuss = false, zielstrasse = "Heegbarg"))
        assertTrue(neu.contains(""""sentinel":{"sonderrechte":true}"""))
        assertTrue(neu.contains(""""street":"Heegbarg""""))
        val fuss = Routenanfrage.anpassen(body, Anfrageoptionen(sonderrechte = true, zuFuss = true))
        assertTrue(fuss.contains(""""costing":"pedestrian""""))
        assertTrue(fuss.contains(""""sonderrechte":false"""))
    }

    @Test
    fun kopfzeilenUndManoever() {
        val k = mapOf("x-sentinel-verkehr" to "1", "x-sentinel-verkehrsfaktor" to "1.400")
        val info = Routeninfo.ausKopfzeilen { k[it] }
        assertTrue(info.verkehr)
        assertEquals(1.4, info.verkehrsfaktor)
        assertEquals(Manoever.Rechts, Manoever.von("turn", "right"))
        assertEquals(Manoever.Kreisverkehr, Manoever.von("roundabout", "left"))
        assertEquals(Manoever.LeichtLinks, Manoever.von("fork", "slight_left"))
        assertEquals(Manoever.LeichtRechts, Manoever.von("turn", "slightRight"))
        assertEquals(Manoever.Kreisverkehr, Manoever.von("ROUNDABOUT_TURN", null))
        assertEquals(Manoever.Wenden, Manoever.von("turn", "U_TURN"))
    }

    @Test
    fun nachfuehrungNurBeiBewegungUndMitAbstand() {
        val n = Nachfuehrung()
        val a = GeoPunkt(53.0, 10.0)
        assertTrue(n.faellig(a, 0))
        n.gerechnet(a, 0)
        assertFalse(n.faellig(GeoPunkt(53.0001, 10.0), 20_000))
        assertFalse(n.faellig(GeoPunkt(53.001, 10.0), 5_000))
        assertTrue(n.faellig(GeoPunkt(53.001, 10.0), 9_000))
    }
}

class RoutenrestTest {
    @Test
    fun restBeginntAmStandortUndLaeuftNurVorwaerts() {
        val route = (0..10).map { GeoPunkt(53.0, 10.0 + it * 0.001) }
        val r = de.nglab.sentinel.kern.navi.Routenrest()
        val rest = r.rest(route, GeoPunkt(53.0, 10.0035))
        assertEquals(GeoPunkt(53.0, 10.0035), rest.first())
        assertEquals(GeoPunkt(53.0, 10.004), rest[1])
        // Zurück am Anfang: bleibt beim erreichten Abschnitt
        assertEquals(GeoPunkt(53.0, 10.004), r.rest(route, GeoPunkt(53.0, 10.0))[1])
    }
}

class VorlaufTest {
    @Test
    fun naechsteKreuzungVorausInFahrtrichtung() {
        val von = GeoPunkt(53.0, 10.0)
        val kreuzungen = listOf(
            "Hinten" to listOf(GeoPunkt(52.998, 10.0)),
            "Vorn" to listOf(GeoPunkt(53.003, 10.0)),
            "Weit" to listOf(GeoPunkt(53.02, 10.0)),
        )
        val k = de.nglab.sentinel.kern.navi.Vorlaufplaner.naechste(kreuzungen, "Hauptstraße", von, 0.0)
        assertEquals("Vorn", k?.second)
        assertEquals(0.0, de.nglab.sentinel.kern.navi.Vorlaufplaner.kurs(listOf(GeoPunkt(53.0, 10.0), GeoPunkt(53.001, 10.0)))!!, 0.5)
    }

    @Test
    fun parallelGehtInDieAnfrage() {
        val body = """{"costing":"auto","locations":[{"lat":1,"lon":2},{"lat":3,"lon":4}]}"""
        val neu = Routenanfrage.anpassen(body, Anfrageoptionen(false, false, parallel = de.nglab.sentinel.kern.navi.Parallelhinweis(GeoPunkt(1.0, 2.0), 90.0, 400.0)))
        assertTrue(neu.contains(""""parallel":{"lat":1.0,"lon":2.0,"kurs":90.0,"meter":400.0}"""))
    }
}
