package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.karte.KartenObjekt
import de.nglab.sentinel.kern.karte.Objektart
import de.nglab.sentinel.kern.modell.GeoPunkt

/** Wie eine Meldung erscheint: Banner in der App; dringend zusätzlich als Systemmitteilung mit Ton bzw. Vibration. */
enum class Dringlichkeit { Hinweis, Wichtig, Alarm }

/** Meldung für Banner und Systemmitteilung, gleich auf allen Plattformen. */
data class Meldung(
    val titel: String,
    val text: String,
    val dringlichkeit: Dringlichkeit,
    /** Antippen zeigt dieses Objekt bzw. diesen Ort. */
    val objekt: KartenObjekt? = null,
    val ort: GeoPunkt? = null,
    /** Gleiche Kennung ersetzt eine frühere Systemmitteilung (z. B. Notruf beendet ersetzt Notruf). */
    val kennung: String,
) {
    val systemmitteilung: Boolean get() = dringlichkeit != Dringlichkeit.Hinweis
}

object Meldungen {
    /** Meldung zu einem Ereignis; `null`, wenn keine angezeigt wird (eigene Aktionen, Positionen). */
    fun aus(e: LageEreignis, stand: LageStand): Meldung? = when (e) {
        is LageEreignis.NotrufBegonnen -> if (e.eigen) Meldung("Notruf ausgelöst", "Alle Kräfte sind alarmiert.", Dringlichkeit.Wichtig, kennung = "sos")
        else Meldung("NOTRUF: ${stand.name(e.fahnderId)}", "Sofort Kontakt aufnehmen.", Dringlichkeit.Alarm,
            objekt = KartenObjekt(Objektart.Kraft, e.fahnderId), ort = stand.positionen[e.fahnderId]?.punkt, kennung = "sos")
        is LageEreignis.NotrufBeendet -> Meldung("Notruf beendet", stand.name(e.fahnderId), Dringlichkeit.Hinweis, kennung = "sos")
        is LageEreignis.AUebernommen -> if (e.eigen) Meldung("Sie haben die A", "Ihr Standort ist jetzt die A-Position.", Dringlichkeit.Hinweis, kennung = "a")
        else Meldung("A-Position: ${stand.name(e.fahnderId)}", "Hat die A übernommen.", Dringlichkeit.Wichtig, objekt = KartenObjekt(Objektart.Kraft, e.fahnderId), kennung = "a")
        is LageEreignis.AFrei -> Meldung("A-Position frei", "${stand.name(e.vorherId)} hat die A abgegeben.", Dringlichkeit.Wichtig, kennung = "a")
        is LageEreignis.Geofence -> {
            val a = e.alarm
            val was = if (a.art == "betreten") "hat „${a.titel}“ betreten" else "hat „${a.titel}“ verlassen"
            Meldung("Geofence: ${a.zielName}", was, Dringlichkeit.Alarm, objekt = KartenObjekt(Objektart.Ziel, a.zielId), ort = GeoPunkt(a.lat, a.lon), kennung = "geofence:${a.annotationId}:${a.zielId}")
        }
        is LageEreignis.Instanzhinweis -> Meldung(e.hinweis.name, "${e.hinweis.spitzname}: ${e.hinweis.art}", Dringlichkeit.Hinweis, kennung = "instanz:${e.hinweis.instanz}")
        is LageEreignis.Fehler -> Meldung("Hinweis", e.meldung, Dringlichkeit.Hinweis, kennung = "fehler")
        is LageEreignis.NeueNachricht, is LageEreignis.Position -> null
    }

    /** Wie lange das Banner stehen bleibt (Alarme bleiben, bis man sie wegtippt). */
    fun anzeigedauerMs(m: Meldung): Long? = when (m.dringlichkeit) {
        Dringlichkeit.Hinweis -> 4_000
        Dringlichkeit.Wichtig -> 8_000
        Dringlichkeit.Alarm -> null
    }
}
