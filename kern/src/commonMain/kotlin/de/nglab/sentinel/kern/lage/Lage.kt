package de.nglab.sentinel.kern.lage

import de.nglab.sentinel.kern.modell.Art
import de.nglab.sentinel.kern.modell.Einsatzzustand
import de.nglab.sentinel.kern.modell.Fortbewegung
import de.nglab.sentinel.kern.modell.Markierung
import de.nglab.sentinel.kern.modell.Nachricht
import de.nglab.sentinel.kern.modell.OepnvFahrt
import de.nglab.sentinel.kern.modell.Position
import de.nglab.sentinel.kern.modell.UeberschlagKurs
import de.nglab.sentinel.kern.modell.Versioniert
import de.nglab.sentinel.kern.protokoll.GeofenceAlarm
import de.nglab.sentinel.kern.protokoll.InstanzHinweis
import de.nglab.sentinel.kern.protokoll.Protokoll
import de.nglab.sentinel.kern.protokoll.ServerNachricht
import de.nglab.sentinel.kern.protokoll.json
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.random.Random

/** Bemerkenswerte Änderung der Lage, aus der ein Hinweis wird. */
sealed interface LageEreignis {
    data class AUebernommen(val fahnderId: String, val eigen: Boolean) : LageEreignis
    data class AFrei(val vorherId: String) : LageEreignis
    data class NotrufBegonnen(val fahnderId: String, val eigen: Boolean) : LageEreignis
    data class NotrufBeendet(val fahnderId: String) : LageEreignis
    data class NeueNachricht(val nachricht: Versioniert<Nachricht>) : LageEreignis
    data class Instanzhinweis(val hinweis: InstanzHinweis) : LageEreignis
    data class Geofence(val alarm: GeofenceAlarm) : LageEreignis
    data class Fehler(val meldung: String) : LageEreignis
    data class Position(val fahnderId: String, val position: de.nglab.sentinel.kern.modell.Position) : LageEreignis
}

/** Sendet Text an den Server; `false`, wenn gerade keine Verbindung besteht. */
fun interface Sender {
    fun senden(text: String): Boolean
}

/**
 * Die laufende Lage: wendet Nachrichten des Servers auf den Stand an und schickt Änderungswünsche. Schreibzugriffe
 * gehen immer über den Server und kommen als Ereignis zurück (der Server ist die einzige Quelle der Wahrheit).
 */
class Lage(private var sender: Sender = Sender { false }) {
    private val _stand = MutableStateFlow(LageStand())
    val stand: StateFlow<LageStand> = _stand.asStateFlow()

    /** Empfänger für Ereignisse (Hinweise, Vibration, Bestreifung). */
    var beiEreignis: (LageEreignis) -> Unit = {}

    fun verbinden(ichId: String, sender: Sender) {
        this.sender = sender
        _stand.value = _stand.value.copy(ichId = ichId)
    }

    fun trennen() {
        sender = Sender { false }
        _stand.value = LageStand()
    }

    // Empfang

    fun empfangen(text: String) = anwenden(Protokoll.lesen(text))

    fun anwenden(n: ServerNachricht) {
        val alt = _stand.value
        when (n) {
            is ServerNachricht.Stand -> {
                val s = n.schnappschuss
                @Suppress("UNCHECKED_CAST")
                fun <T> liste(art: Art) = (s.objekte[art] ?: emptyList()).associateBy { it.id } as Map<String, Versioniert<T>>
                _stand.value = LageStand(
                    ichId = s.ich.id,
                    hatStand = true,
                    serverVersion = s.server.version,
                    routing = s.server.routing,
                    instanz = s.instanz,
                    fahnder = liste(Art.Fahnder),
                    fahrzeuge = liste(Art.Fahrzeug),
                    markierungen = liste(Art.Markierung),
                    ziele = liste(Art.Ziel),
                    beziehungen = liste(Art.Beziehung),
                    zielgruppen = liste(Art.Zielgruppe),
                    tracker = liste(Art.Tracker),
                    ebenen = liste(Art.Ebene),
                    raeume = liste(Art.Raum),
                    nachrichten = liste<Nachricht>(Art.Nachricht).values.toList(),
                    instanzen = liste(Art.Instanz),
                    einsatz = s.einsatz,
                    positionen = s.positionen.associate { it.id to it.p },
                    trackerPositionen = s.trackerPositionen.associate { it.id to it.p },
                    online = s.online.toSet(),
                    bestreifungStand = alt.bestreifungStand + 1,
                )
                // Läuft beim Verbinden bereits ein Notruf, gilt er als neu (nicht erneut nach einem Wiederverbinden).
                val notruf = s.einsatz.sos
                if (notruf != null && notruf.memberId != alt.einsatz.sos?.memberId) {
                    beiEreignis(LageEreignis.NotrufBegonnen(notruf.memberId, notruf.memberId == s.ich.id))
                }
            }
            is ServerNachricht.Gesetzt -> {
                if (n.art == Art.Nachricht) {
                    @Suppress("UNCHECKED_CAST")
                    val nachricht = n.objekt as Versioniert<Nachricht>
                    val neu = alt.nachrichten.none { it.id == nachricht.id }
                    _stand.value = alt.mitObjekt(n.art, n.objekt)
                    if (neu && alt.hatStand && nachricht.updatedBy != alt.ichId) beiEreignis(LageEreignis.NeueNachricht(nachricht))
                } else {
                    _stand.value = alt.mitObjekt(n.art, n.objekt)
                }
            }
            is ServerNachricht.Geloescht -> _stand.value = alt.ohneObjekt(n.art, n.id)
            is ServerNachricht.Einsatz -> {
                ankuendigen(alt, n.zustand)
                _stand.value = alt.copy(einsatz = n.zustand)
            }
            is ServerNachricht.Ort -> {
                _stand.value = alt.copy(positionen = alt.positionen + (n.id to n.position))
                beiEreignis(LageEreignis.Position(n.id, n.position))
            }
            is ServerNachricht.TrackerOrt -> _stand.value = alt.copy(trackerPositionen = alt.trackerPositionen + (n.id to n.position))
            is ServerNachricht.Online -> _stand.value = alt.copy(online = n.ids.toSet())
            is ServerNachricht.Hinweis -> beiEreignis(LageEreignis.Instanzhinweis(n.hinweis))
            is ServerNachricht.Geofence -> beiEreignis(LageEreignis.Geofence(n.alarm))
            ServerNachricht.BestreifungZurueckgesetzt -> _stand.value = alt.copy(bestreifungStand = alt.bestreifungStand + 1)
            is ServerNachricht.Fehler -> beiEreignis(LageEreignis.Fehler(n.meldung))
            is ServerNachricht.Bestaetigt, ServerNachricht.Pong, ServerNachricht.Unbekannt -> Unit
        }
    }

    private fun ankuendigen(alt: LageStand, neu: Einsatzzustand) {
        if (!alt.hatStand) return
        if (alt.einsatz.sos?.memberId != neu.sos?.memberId) {
            val sos = neu.sos
            val vorher = alt.einsatz.sos
            if (sos != null) beiEreignis(LageEreignis.NotrufBegonnen(sos.memberId, sos.memberId == alt.ichId))
            else if (vorher != null) beiEreignis(LageEreignis.NotrufBeendet(vorher.memberId))
        }
        if (alt.einsatz.a?.memberId != neu.a?.memberId) {
            val a = neu.a
            val vorher = alt.einsatz.a
            if (a != null) beiEreignis(LageEreignis.AUebernommen(a.memberId, a.memberId == alt.ichId))
            else if (vorher != null) beiEreignis(LageEreignis.AFrei(vorher.memberId))
        }
    }

    // Schreiben

    private fun ref(): String = neueId()

    private fun melden(gesendet: Boolean): Boolean {
        if (!gesendet) beiEreignis(LageEreignis.Fehler("Keine Verbindung zum Server. Die Änderung wurde nicht übernommen."))
        return gesendet
    }

    fun setzen(art: Art, id: String, daten: Any): Boolean = melden(sender.senden(Protokoll.setzen(art, id, daten, ref())))

    fun loeschen(art: Art, id: String): Boolean {
        val ok = melden(sender.senden(Protokoll.loeschen(art, id, ref())))
        // Markierungen sofort ausblenden, nicht erst mit der Bestätigung (sonst bleibt die Ansicht kurz leer offen).
        if (ok && art == Art.Markierung) _stand.value = _stand.value.ohneObjekt(art, id)
        return ok
    }

    fun kommando(name: String, argumente: JsonObject = JsonObject(emptyMap())): Boolean =
        melden(sender.senden(Protokoll.kommando(name, argumente, ref())))

    fun positionSenden(p: Position) {
        sender.senden(Protokoll.position(p))
    }

    // Einsatz-Kommandos (Namen und Argumente wie auf dem Server)

    fun aUebernehmen() = kommando("a.uebernehmen")
    fun aFreigeben() = kommando("a.freigeben")
    fun notrufAusloesen() = kommando("sos.ausloesen")
    fun notrufBeenden() = kommando("sos.beenden")
    fun funkkanalSetzen(kanal: String?) = kommando("funkkanal.setzen", buildJsonObject { put("kanal", kanal?.let(::JsonPrimitive) ?: JsonNull) })
    fun lageSetzen(titel: String, hinweise: String) = kommando("lage.setzen", buildJsonObject { put("titel", titel); put("hinweise", hinweise) })
    fun bestreifungZuruecksetzen() = kommando("bestreifung.zuruecksetzen")
    fun lageZuruecksetzen(mitZielen: Boolean) = kommando("lage.zuruecksetzen", buildJsonObject { put("ziele", mitZielen) })
    fun lageLeeren() = kommando("lage.leeren")
    fun aktivSetzen(aktiv: Boolean) = kommando("aktiv.setzen", buildJsonObject { put("aktiv", aktiv) })

    fun ueberschlagenBeitreten(kurs: UeberschlagKurs? = null) = kommando("ueberschlagen.beitreten", buildJsonObject {
        put("kurs", kurs?.let { json.encodeToJsonElement(UeberschlagKurs.serializer(), it) } ?: JsonNull)
    })
    fun ueberschlagenVerlassen() = kommando("ueberschlagen.verlassen")

    fun fortbewegungSetzen(art: Fortbewegung, fahrzeugId: String? = null, oepnv: OepnvFahrt? = null) = kommando("fortbewegung.setzen", buildJsonObject {
        put("art", json.encodeToJsonElement(Fortbewegung.serializer(), art))
        put("fahrzeugId", fahrzeugId?.let(::JsonPrimitive) ?: JsonNull)
        put("oepnv", oepnv?.let { json.encodeToJsonElement(OepnvFahrt.serializer(), it) } ?: JsonNull)
    })

    fun fahrzeugImEinsatz(fahrzeugId: String, aktiv: Boolean) = kommando("fahrzeug.aktivieren", buildJsonObject { put("fahrzeugId", fahrzeugId); put("aktiv", aktiv) })
    fun trackerIntervall(trackerId: String, sekunden: Int) = kommando("tracker.intervall", buildJsonObject { put("trackerId", trackerId); put("sekunden", sekunden) })
    fun zielEinblenden(zielId: String, sichtbar: Boolean) = kommando("ziel.sichtbar", buildJsonObject { put("zielId", zielId); put("sichtbar", sichtbar) })
    fun gruppeEinblenden(gruppeId: String, sichtbar: Boolean) = kommando("gruppe.sichtbar", buildJsonObject { put("gruppeId", gruppeId); put("sichtbar", sichtbar) })

    fun instanzErstellen(name: String, beschreibung: String = "", paket: Boolean) = kommando("instanz.erstellen", buildJsonObject {
        put("id", neueId()); put("name", name); put("beschreibung", beschreibung); put("art", if (paket) "paket" else "einsatz")
    })
    fun instanzBearbeiten(id: String, name: String, beschreibung: String) = kommando("instanz.bearbeiten", buildJsonObject { put("id", id); put("name", name); put("beschreibung", beschreibung) })
    fun instanzLoeschen(id: String) = kommando("instanz.loeschen", buildJsonObject { put("id", id) })
    fun instanzBeitreten(id: String) = kommando("instanz.beitreten", buildJsonObject { put("id", id) })
    fun instanzVerlassen(id: String) = kommando("instanz.verlassen", buildJsonObject { put("id", id) })
    fun instanzWechseln(id: String) = kommando("instanz.wechseln", buildJsonObject { put("id", id) })
    fun paketUebernehmen(paketId: String) = kommando("paket.importieren", buildJsonObject { put("paketId", paketId) })

    fun nachrichtSenden(text: String, raumId: String, anhang: de.nglab.sentinel.kern.modell.Anhang? = null): Boolean {
        val t = text.trim()
        if (t.isEmpty() && anhang == null) return false
        return setzen(Art.Nachricht, neueId(), Nachricht(raumId, t.take(1000), anhang))
    }

    fun markierungSichern(m: Markierung, id: String) = setzen(Art.Markierung, id, m)

    fun zielGruppieren(zielId: String, gruppeId: String?): Boolean {
        val ziel = _stand.value.ziele[zielId]?.data ?: return false
        return setzen(Art.Ziel, zielId, ziel.copy(gruppeId = gruppeId))
    }

    companion object {
        /** Neue Kennung (32 Hex-Zeichen, wie bisher). */
        fun neueId(): String = buildString { repeat(32) { append("0123456789abcdef"[Random.nextInt(16)]) } }
    }
}
