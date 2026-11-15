import { useSignal } from '@preact/signals';
import { useEffect } from 'preact/hooks';
import { command, operation, reach, reachModes, tables, tool } from '../store';
import { MODUS_TITEL, type Modus, type ReachMode } from '../types';
import { ago, Field, Section, TextInput, time } from '../ui';

const MODUS_HINWEIS: Record<Modus, string> = {
  observation: 'A-Position, Navigation zur A, Zielperson im Blick',
  fahndung: 'Bestreifung, letzter Standort, Weg-Zeit-Berechnung',
  oberflaeche: 'Nur Kräfte und Markierungen',
};
const REACH_TITEL: Record<ReachMode, string> = { fuss: 'Zu Fuß', kfz: 'Kfz', oepnv: 'ÖPNV' };

/** Einsatzinformationen, Modus, Funkkanal und die Werkzeuge der Fahndung. */
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

  return (
    <>
      <Section title="Modus" hint="Gilt für alle. Beim Wechsel geht nichts verloren: Die A-Position wird in der Fahndung zum letzten bekannten Standort.">
        <div class="segmented">
          {(Object.keys(MODUS_TITEL) as Modus[]).map((modus) => (
            <button
              key={modus}
              class={op.modus === modus ? 'active' : ''}
              title={MODUS_HINWEIS[modus]}
              onClick={() => {
                if (op.modus !== modus && confirm(`Modus für alle auf „${MODUS_TITEL[modus]}“ ändern?`)) command('modus.setzen', { modus });
              }}
            >
              {MODUS_TITEL[modus]}
            </button>
          ))}
        </div>
        <p class="hint">{MODUS_HINWEIS[op.modus]}</p>
      </Section>

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

      {op.modus === 'observation' && (
        <Section title="A-Position">
          {aHolder && op.a ? (
            <div class="row between">
              <span>
                <b>{aHolder.data.funkrufname}</b> seit {time(op.a.seit)}
              </span>
              <button class="quiet" onClick={() => command('a.freigeben')}>
                Freigeben
              </button>
            </div>
          ) : (
            <p class="hint">Niemand hält die A-Position. Übernommen wird sie in der App.</p>
          )}
        </Section>
      )}

      {op.modus !== 'oberflaeche' && (
        <Section title="Letzter bekannter Standort">
          {op.lkp ? (
            <p>
              {time(op.lkp.ts)} ({ago(op.lkp.ts)}) · {op.lkp.quelle === 'a' ? 'aus A-Position' : op.lkp.quelle === 'tracker' ? 'vom Tracker' : 'manuell'}
            </p>
          ) : (
            <p class="hint">Nicht gesetzt.</p>
          )}
          <div class="row">
            <button class={tool.value.kind === 'lkp' ? 'active' : ''} onClick={() => (tool.value = tool.value.kind === 'lkp' ? { kind: 'auswahl' } : { kind: 'lkp' })}>
              Auf Karte setzen
            </button>
            {op.lkp && (
              <>
                <button onClick={() => command('lkp.setzen', { lat: op.lkp!.lat, lon: op.lkp!.lon, targetId: op.lkp!.targetId })}>Zeit auf jetzt</button>
                <button class="quiet" onClick={() => command('lkp.loeschen')}>
                  Entfernen
                </button>
              </>
            )}
          </div>
        </Section>
      )}

      {op.modus === 'fahndung' && (
        <Section title="Fahndung" hint="Die Flächen zeigen, wo sich die Zielperson seit dem letzten Standort befinden kann, und wachsen mit der Zeit.">
          <div class="row">
            {(Object.keys(REACH_TITEL) as ReachMode[]).map((mode) => (
              <label key={mode} class={`chip reach-${mode} ${reachModes.value[mode] ? 'on' : ''}`}>
                <input type="checkbox" checked={reachModes.value[mode]} onChange={() => (reachModes.value = { ...reachModes.value, [mode]: !reachModes.value[mode] })} />
                {REACH_TITEL[mode]}
              </label>
            ))}
          </div>
          {reach.value.some((a) => a.quelle === 'modell') && <p class="hint">Teilweise Näherungsmodell (ÖPNV sowie lange Zeiträume).</p>}
          <button
            class="quiet"
            onClick={() => {
              if (confirm('Bisherige Bestreifung für alle löschen?')) command('bestreifung.zuruecksetzen');
            }}
          >
            Bestreifung zurücksetzen
          </button>
        </Section>
      )}

      <Section title="Lage abschließen" hint="Entfernt Markierungen der laufenden Lage, geladene Pakete, Chat, Bestreifung und letzten Standort. Dauerhafte Orte, Profile, Fahrzeuge und Tracker bleiben.">
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
