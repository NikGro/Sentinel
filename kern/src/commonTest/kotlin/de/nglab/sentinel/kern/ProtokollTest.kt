package de.nglab.sentinel.kern

import de.nglab.sentinel.kern.lage.Lage
import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Fahnder
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.protokoll.Protokoll
import de.nglab.sentinel.kern.protokoll.ServerNachricht
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ProtokollTest {
    private val schnappschuss = """
        {"t":"snapshot","self":{"id":"m1","role":"fahnder"},"server":{"version":"1.0.0","routing":true},"online":["m1"],
         "members":[{"id":"m1","rev":1,"updatedAt":1,"updatedBy":"m1","data":{"name":"Max Muster","spitzname":"Max","dienststelle":"LKA","fortbewegung":"fuss"}},
                    {"id":"kaputt","rev":1,"updatedAt":1,"updatedBy":"x","data":{"name":5}}],
         "vehicles":[],"annotations":[{"id":"a1","rev":1,"updatedAt":1,"updatedBy":"m1","data":{"layerId":"lage","typ":"marker","punkte":[{"lat":53.5,"lon":10.0}],"neuesFeld":true}}],
         "targets":[],"trackers":[],"layers":[{"id":"lage","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Lage","art":"lage","status":"live"}}],
         "messages":[],"operation":{"funkkanal":"412","titel":"Test","hinweise":"","a":{"memberId":"m1","seit":5},"ueberschlagen":{"teilnehmer":[],"zuweisungen":{},"naechste":[]},"sos":null,"fahrzeuge":[],"ziele":[],"gruppenAus":[],"rev":3},
         "positions":[{"id":"m1","p":{"lat":53.55,"lon":10.0,"ts":1000}}],"trackerPositions":[],"instanz":"haupt","instances":[]}
    """.trimIndent()

    @Test
    fun schnappschussWirdGelesenUndFehlerhaftesUebersprungen() {
        val n = Protokoll.lesen(schnappschuss)
        assertIs<ServerNachricht.Stand>(n)
        assertEquals(1, n.schnappschuss.objekte[Art.Fahnder]!!.size)
        assertEquals("412", n.schnappschuss.einsatz.funkkanal)
    }

    @Test
    fun lageUebernimmtStandUndAenderungen() {
        val lage = Lage()
        lage.empfangen(schnappschuss)
        val stand = lage.stand.value
        assertTrue(stand.hatStand)
        assertTrue(stand.haeltA)
        assertEquals("Max", stand.ich?.data?.spitzname)
        assertEquals(1, stand.sichtbareMarkierungen(0).size)
        lage.empfangen("""{"t":"del","kind":"annotation","id":"a1"}""")
        assertEquals(0, lage.stand.value.markierungen.size)
        lage.empfangen("""{"t":"pos","id":"m1","p":{"lat":53.6,"lon":10.1,"ts":2000}}""")
        assertEquals(53.6, lage.stand.value.eigenePosition?.lat)
    }

    @Test
    fun setzenErzeugtServerFormat() {
        val text = Protokoll.setzen(Art.Markierung, "x1", Markierung(layerId = "lage", typ = Form.Marker, punkte = listOf(GeoPunkt(1.0, 2.0))), "r1")
        assertTrue(text.contains("\"kind\":\"annotation\""))
        assertTrue(text.contains("\"typ\":\"marker\""))
        val fahnder = Protokoll.setzen(Art.Fahnder, "m1", Fahnder("A", "B", "C"), "r2")
        assertTrue(fahnder.contains("\"fortbewegung\":\"fuss\""))
        assertNotNull(fahnder)
    }
}
