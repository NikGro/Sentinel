import { useSignal } from '@preact/signals';
import { useEffect } from 'preact/hooks';
import { command, focusRequest, memberLabel, operation, permanentUnlocked, reach, reachModes, saveObject, selectedObject, showCoverage, tables, toggleCoverage } from '../store';
import type { ReachMode } from '../types';
import { ago, Field, Section, TextInput, time } from '../ui';

const REACH_TITEL: Record<ReachMode, string> = { fuss: 'Zu Fuß', kfz: 'Kfz', oepnv: 'ÖPNV' };

/** Einsatzinformationen, Funkkanal, A-Position, Fahndungsräume und Bestreifung. */
export function LagePanel() {
  const op = operation.value;
  const titel = useSignal(op.titel);
  const hinweise = useSignal(op.hinweise);
  const kanal = useSignal(op.funkkanal ?? '');
  const resetZiele = useSignal(false);

  // Eingabefelder folgen Änderungen, die von anderen kommen.
  useEffect(() => {
    titel.value = op.titel;
    hinweise.value = op.hinweise;
    kanal.value = op.funkkanal ?? '';
  }, [op.titel, op.hinweise, op.funkkanal]);

  const dirty = titel.value !== op.titel || hinweise.value !== op.hinweise;
  const kanalValid = kanal.value === '' || /^\d{1,5}$/.test(kanal.value);
  const aHolder = op.a ? tables.member.value[op.a.memberId] : null;
  const fahndungsraeume = Object.values(tables.annotation.value).filter((a) => a.data.typ === 'fahndungsraum');

  return (
    <>
      <Section title="Funkkanal">
        <div class="row">
          <input class="mono" inputMode="numeric" maxLength={5} placeholder="1 bis 5 Ziffern" value={kanal.value} onInput={(e) => (kanal.value = e.currentTarget.value.replace(/\D/g, ''))} />
          <button class="primary" disabled={!kanalValid || kanal.value === (op.funkkanal ?? '')} onClick={() => command('funkkanal.setzen', { kanal: kanal.value || null })}>
            Setzen
          </button>
        </div>
      </Section>

      <Section title="Einsatzinformationen">
        <Field label="Titel">
          <TextInput value={titel.value} onInput={(v) => (titel.value = v)} placeholder="z. B. Observation Musterstraße" maxLength={80} />
        </Field>
        <Field label="Hinweise">
          <TextInput value={hinweise.value} onInput={(v) => (hinweise.value = v)} rows={6} placeholder="Auftrag, Treffpunkt, Eigensicherung …" maxLength={4000} />
        </Field>
        <button class="primary" disabled={!dirty} onClick={() => command('lage.setzen', { titel: titel.value, hinweise: hinweise.value })}>
          Für alle übernehmen
        </button>
      </Section>

      <Section title="A-Position" hint="Übernommen wird die A-Position in der App. Hier lässt sie sich freigeben.">
        {aHolder && op.a ? (
          <div class="row between">
            <span>
              <b>{memberLabel(aHolder.data)}</b> seit {time(op.a.seit)}
            </span>
            <button class="quiet" onClick={() => command('a.freigeben')}>
              Freigeben
            </button>
          </div>
        ) : (
          <p class="hint">Niemand hält die A-Position.</p>
        )}
        {aHolder?.data.fortbewegung === 'oepnv' && aHolder.data.oepnv && (
          <>
            <p>
              Im ÖPNV: <b>{aHolder.data.oepnv.linie}</b> Richtung {aHolder.data.oepnv.richtung}
            </p>
            {op.ueberschlagen.naechste.length > 0 && (
              <ol class="stops">
                {op.ueberschlagen.naechste.map((stop) => {
                  const assigned = Object.entries(op.ueberschlagen.zuweisungen)
                    .filter(([, s]) => s.name === stop.name && s.lat === stop.lat)
                    .map(([id]) => tables.member.value[id]?.data.spitzname ?? 'Unbekannt');
                  return (
                    <li key={`${stop.name}-${stop.lat}`}>
                      <button class="quiet" onClick={() => (focusRequest.value = { ...stop, at: Date.now() })}>
                        {stop.name}
                      </button>
                      {assigned.length > 0 && <small>besetzt von {assigned.join(', ')}</small>}
                    </li>
                  );
                })}
              </ol>
            )}
          </>
        )}
      </Section>

      <Section title="Fahndungsräume" hint="Ein Fahndungsraum zeigt, wo sich die Zielperson seit dem angegebenen Zeitpunkt befinden kann. Neu anlegen über die Werkzeugleiste der Karte.">
        <div class="row">
          {(Object.keys(REACH_TITEL) as ReachMode[]).map((mode) => (
            <label key={mode} class={`chip reach-${mode} ${reachModes.value[mode] ? 'on' : ''}`}>
              <input type="checkbox" checked={reachModes.value[mode]} onChange={() => (reachModes.value = { ...reachModes.value, [mode]: !reachModes.value[mode] })} />
              {REACH_TITEL[mode]}
            </label>
          ))}
        </div>
        {fahndungsraeume.length === 0 && <p class="hint">Kein Fahndungsraum angelegt.</p>}
        <ul class="list">
          {fahndungsraeume.map((room) => (
            <li key={room.id}>
              <div class="grow">
                <b>{room.data.titel || 'Fahndungsraum'}</b>
                <small>
                  seit {room.data.zeit ? time(room.data.zeit) : '–'} ({room.data.zeit ? ago(room.data.zeit) : ''})
                  {(reach.value[room.id] ?? []).some((a) => a.quelle === 'modell') ? ', teils Näherung' : ''}
                </small>
              </div>
              <button
                class="quiet"
                onClick={() => {
                  focusRequest.value = { ...room.data.punkte[0]!, at: Date.now() };
                  selectedObject.value = room.id;
                }}
              >
                Zeigen
              </button>
              <button onClick={() => saveObject(room.id, { ...room.data, zeit: Date.now() })} title="Zeitpunkt auf jetzt setzen">
                Jetzt
              </button>
            </li>
          ))}
        </ul>
      </Section>

      <Section title="Bestreifung" hint="Aufgezeichnet wird immer. Die Anzeige auf dieser Karte schaltet jeder für sich ein.">
        <label class="check">
          <input type="checkbox" checked={showCoverage.value} onChange={toggleCoverage} />
          Bestreifte Wege anzeigen
        </label>
        <button
          class="quiet"
          onClick={() => {
            if (confirm('Bisherige Bestreifung für alle löschen?')) command('bestreifung.zuruecksetzen');
          }}
        >
          Bestreifung zurücksetzen
        </button>
      </Section>

      <Section title="Dauerhafte Orte" hint="Die Ebene ist gegen versehentliches Bearbeiten gesperrt. Ausblenden geht unter Ebenen.">
        <label class="check">
          <input type="checkbox" checked={permanentUnlocked.value} onChange={() => (permanentUnlocked.value = !permanentUnlocked.value)} />
          Zum Bearbeiten entsperren
        </label>
      </Section>

      <Section title="Lage abschließen" hint="Entfernt Markierungen der laufenden Lage, geladene Pakete, Chatnachrichten und Bestreifung. Dauerhafte Orte, Profile, Fahrzeuge, Tracker und Chaträume bleiben.">
        <a class="button" href="/api/v1/admin/export" download>
          Lage vorher sichern (JSON)
        </a>
        <label class="check">
          <input type="checkbox" checked={resetZiele.value} onChange={() => (resetZiele.value = !resetZiele.value)} />
          Zielpersonen ebenfalls löschen
        </label>
        <button
          class="danger"
          onClick={() => {
            if (confirm('Lage für alle zurücksetzen? Das kann nicht rückgängig gemacht werden.')) command('lage.zuruecksetzen', { ziele: resetZiele.value });
          }}
        >
          Lage zurücksetzen
        </button>
      </Section>
    </>
  );
}
