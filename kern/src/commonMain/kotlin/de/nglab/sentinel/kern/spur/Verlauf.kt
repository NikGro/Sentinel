package de.nglab.sentinel.kern.spur

import de.nglab.sentinel.kern.format.Format
import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.lage.LageStand
import de.nglab.sentinel.kern.modell.Ebene
import de.nglab.sentinel.kern.modell.Form
import de.nglab.sentinel.kern.modell.GeoPunkt
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.SpurVerweis
import de.nglab.sentinel.kern.netz.Api
import kotlinx.serialization.json.JsonObject

/** Zeitraum eines Verlaufs. */
data class Zeitraum(val titel: String, val vonMs: Long, val bisMs: Long)

/**
 * Verlauf eines Objekts (Fahnder, Fahrzeug, Ziel, Tracker) im gewählten Zeitraum, gemeinsam für alle Plattformen:
 * Laden, Darstellung, Zeitregler und Zusammenfassung. Die Plattform zeigt die Leiste unten und den Punkt zur gewählten
 * Zeit (`ort`), die Linie kommt über `geoJson` in die Quelle `s-spuren`.
 */
class Verlauf(val objekt: KartenObjekt, val titel: String) {
    var spur: Spur? = null
        private set
    var zeitraum: Zeitraum? = null
        private set
    var fehler: String? = null
        private set

    /** Art für `GET /api/v1/spur`; `null`, wenn das Objekt keinen Verlauf hat. */
    val art: String? get() = artFuer(objekt)

    suspend fun laden(api: Api, z: Zeitraum) {
        val a = art ?: return
        zeitraum = z
        fehler = null
        spur = runCatching { Spur.ausAntwort(a, objekt.id, api.spur(a, objekt.id, z.vonMs, z.bisMs)) }
            .onFailure { fehler = "Verlauf konnte nicht geladen werden." }
            .getOrNull()
    }

    fun merkmale(): List<JsonObject> = spur?.let { Spurszene.merkmale(it, "verlauf:${objekt.schluessel}") } ?: emptyList()

    /** Ort zur Zeit des Reglers (0…1 über den Zeitraum der Spur). */
    fun zeitBei(anteil: Double): Long? {
        val p = spur?.punkte ?: return null
        if (p.isEmpty()) return null
        return p.first().zeitMs + ((p.last().zeitMs - p.first().zeitMs) * anteil.coerceIn(0.0, 1.0)).toLong()
    }

    fun ort(zeitMs: Long): GeoPunkt? = spur?.ort(zeitMs)

    /** „12,4 km · 3 Standzeiten · 214 Punkte“ bzw. Hinweis ohne Daten. */
    fun zusammenfassung(): String {
        val s = spur ?: return fehler ?: "Wird geladen …"
        if (s.punkte.size < 2) return "Keine Positionen in diesem Zeitraum."
        var meter = 0.0
        for (i in 1 until s.punkte.size) if (!s.luecke(i - 1)) meter += s.punkte[i - 1].punkt.distanz(s.punkte[i].punkt)
        val stand = s.standzeiten.size
        return listOf(Format.entfernung(meter), if (stand == 1) "1 Standzeit" else "$stand Standzeiten", "${s.punkte.size} Punkte").joinToString(" · ")
    }

    /** Rahmen aller Punkte (Süd, West, Nord, Ost) zum Einpassen der Karte. */
    fun rahmen(): DoubleArray? {
        val p = spur?.punkte?.map { it.punkt } ?: return null
        if (p.isEmpty()) return null
        return doubleArrayOf(p.minOf { it.lat }, p.minOf { it.lon }, p.maxOf { it.lat }, p.maxOf { it.lon })
    }

    /** Diesen Verlauf als Spur-Markierung in die Lage übernehmen (bleibt sichtbar, für alle). */
    fun alsMarkierung(): Markierung? {
        val a = art ?: return null
        val z = zeitraum ?: return null
        val start = spur?.punkte?.firstOrNull()?.punkt ?: return null
        return Markierung(
            layerId = Ebene.LAGE, typ = Form.Verlauf, titel = "Verlauf $titel", farbe = "#0A84FF", punkte = listOf(start),
            spuren = listOf(SpurVerweis(a, objekt.id)), zeitVon = z.vonMs, zeitBis = z.bisMs,
        )
    }

    companion object {
        fun artFuer(o: KartenObjekt): String? = when (o.art) {
            Objektart.Kraft -> "member"
            Objektart.Fahrzeug -> "vehicle"
            Objektart.Ziel -> "target"
            else -> null
        }

        /** Vorgaben für den Zeitraum (bis jetzt); „Heute“ ab Mitternacht (`mitternachtMs` von der Plattform). */
        fun zeitraeume(jetztMs: Long, mitternachtMs: Long): List<Zeitraum> = listOf(
            Zeitraum("1 Std.", jetztMs - 3_600_000, jetztMs),
            Zeitraum("4 Std.", jetztMs - 4 * 3_600_000, jetztMs),
            Zeitraum("Heute", mitternachtMs, jetztMs),
            Zeitraum("24 Std.", jetztMs - 24 * 3_600_000, jetztMs),
            Zeitraum("7 Tage", jetztMs - 7 * 24 * 3_600_000, jetztMs),
        )

        /**
         * Standortspur (Pinsel): zeigt ab jetzt den eigenen Weg als Objekt auf der Karte, läuft mit, bis jemand sie
         * löscht; standardmäßig nach Häufigkeit eingefärbt.
         */
        fun standortspur(stand: LageStand, ort: GeoPunkt, jetztMs: Long): Markierung? {
            val ich = stand.ich ?: return null
            return Markierung(
                layerId = Ebene.LAGE, typ = Form.Verlauf, titel = "Standortspur ${stand.beschriftung(ich.data)}", farbe = "#FF375F",
                punkte = listOf(ort), spuren = listOf(SpurVerweis("member", ich.id)), zeitVon = jetztMs, zeitBis = null,
                symbol = Markierung.STANDORTSPUR_HAEUFIGKEIT,
            )
        }
    }
}

/**
 * Lädt die Spuren aller Spur-Markierungen der Lage (Verlauf, Standortspur) und hält sie aktuell: laufende Spuren
 * (ohne Ende) alle 30 s, feste einmal. Ergebnis als Merkmale für `s-spuren`.
 */
class Spurenlader {
    private data class Eintrag(val spur: Spur, val geladenMs: Long, val schluessel: String)
    private val geladen = HashMap<String, Eintrag>()

    /** Lädt nach, was fehlt oder veraltet ist. Gibt `true` zurück, wenn sich etwas geändert hat. */
    suspend fun aktualisieren(api: Api, stand: LageStand, jetztMs: Long): Boolean {
        var geaendert = false
        val markierungen = stand.sichtbareMarkierungen(jetztMs).filter { it.data.typ == Form.Verlauf && it.data.spuren.isNotEmpty() }
        val ids = markierungen.map { it.id }.toSet()
        if (geladen.keys.retainAll(ids)) geaendert = true
        for (m in markierungen) {
            val d = m.data
            val ref = d.spuren.first()
            val schluessel = "${ref.art}:${ref.id}:${d.zeitVon}:${d.zeitBis}"
            val alt = geladen[m.id]
            val laufend = d.zeitBis == null
            if (alt != null && alt.schluessel == schluessel && (!laufend || jetztMs - alt.geladenMs < AKTUALISIEREN_MS)) continue
            val von = d.zeitVon ?: (jetztMs - 3_600_000)
            val bis = d.zeitBis ?: jetztMs
            runCatching { Spur.ausAntwort(ref.art, ref.id, api.spur(ref.art, ref.id, von, bis)) }.onSuccess {
                geladen[m.id] = Eintrag(it, jetztMs, schluessel)
                geaendert = true
            }
        }
        return geaendert
    }

    fun merkmale(stand: LageStand): List<JsonObject> = geladen.flatMap { (id, e) ->
        val d = stand.markierungen[id]?.data ?: return@flatMap emptyList()
        val haeufigkeit = if (d.standortspurNachHaeufigkeit) Haeufigkeit.durchfahrten(e.spur.punkte.map { it.punkt }) else null
        Spurszene.merkmale(e.spur, id, standortspur = d.istStandortspur, haeufigkeit = haeufigkeit)
    }

    /** Spuren und ein offener Verlauf zusammen als GeoJSON für `s-spuren`. */
    fun geoJson(stand: LageStand, verlauf: Verlauf?): String = Spurszene.sammlung(merkmale(stand) + (verlauf?.merkmale() ?: emptyList()))

    companion object {
        const val AKTUALISIEREN_MS = 30_000L
    }
}
