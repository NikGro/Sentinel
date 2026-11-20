import { useSignal } from '@preact/signals';
import { del, focusRequest, nameOf, newId, put, setTargetShown, tables, targetShown, tool, trackerPoint } from '../store';
import { ZIEL_TITEL, type Target, type ZielArt } from '../types';
import { ageOf, ago, Field, ImageField, Section, TextInput } from '../ui';

const LEER: Target = {
  art: 'person',
  bezeichnung: '',
  standort: null,
  vorname: '', nachname: '', geburtsdatum: null, geburtsort: '', staatsangehoerigkeit: '', anschrift: '', merkmale: '', fotoBlob: null,
  kennzeichen: '', fahrzeugBeschreibung: '', fahrzeugFotoBlob: null, sachverhalt: '', hinweise: '', massnahmen: '', trackerId: null,
};

const anzeigename = (t: Target) => {
  if (t.art === 'fahrzeug') return t.kennzeichen || t.bezeichnung || 'Zielfahrzeug';
  if (t.art === 'objekt') return t.bezeichnung || t.anschrift || 'Zielobjekt';
  return [t.vorname, t.nachname].filter(Boolean).join(' ') || 'Unbekannte Person';
};

/** Zielpersonen anlegen und pflegen. Alle Kräfte sehen und bearbeiten dieselben Angaben. */
export function TargetsPanel() {
  const editing = useSignal<{ id: string; data: Target; neu: boolean } | null>(null);
  const targets = Object.values(tables.target.value).sort((a, b) => anzeigename(a.data).localeCompare(anzeigename(b.data)));

  if (editing.value) {
    const { id, data, neu } = editing.value;
    const set = (patch: Partial<Target>) => (editing.value = { id, neu, data: { ...data, ...patch } });
    const text = (key: keyof Target, label: string, rows?: number) => (
      <Field label={label}>
        <TextInput value={(data[key] as string) ?? ''} onInput={(v) => set({ [key]: v })} rows={rows} />
      </Field>
    );
    return (
      <Section
        title={neu ? `Neu: ${ZIEL_TITEL[data.art]}` : anzeigename(data)}
        actions={
          <button class="quiet" onClick={() => (editing.value = null)}>
            Zurück
          </button>
        }
      >
        <Field label="Art">
          <select value={data.art} onChange={(e) => set({ art: e.currentTarget.value as ZielArt })}>
            {(Object.keys(ZIEL_TITEL) as ZielArt[]).map((art) => (
              <option key={art} value={art}>
                {ZIEL_TITEL[art]}
              </option>
            ))}
          </select>
        </Field>
        {data.art !== 'person' && text('bezeichnung', data.art === 'fahrzeug' ? 'Bezeichnung, z. B. BMW 3er dunkelblau' : 'Bezeichnung, z. B. Wohnung Musterstraße')}
        <div class="field">
          <span>Standort</span>
          <div class="row">
            <span class="hint">{data.trackerId ? 'vom Tracker' : data.standort ? `von Hand gesetzt, ${new Date(data.standort.ts).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' })}` : 'nicht gesetzt'}</span>
            {!neu && (
              <button
                onClick={() => {
                  put('target', id, data);
                  tool.value = { kind: 'zielstandort', targetId: id };
                }}
              >
                Auf Karte setzen
              </button>
            )}
            {data.standort && (
              <button class="quiet" onClick={() => set({ standort: null })}>
                Entfernen
              </button>
            )}
          </div>
        </div>
        <div class="grid2">
          {text('vorname', 'Vorname')}
          {text('nachname', 'Nachname')}
          <Field label={`Geburtsdatum${ageOf(data.geburtsdatum) !== null ? ` (${ageOf(data.geburtsdatum)} Jahre)` : ''}`}>
            <input type="date" value={data.geburtsdatum ?? ''} onInput={(e) => set({ geburtsdatum: e.currentTarget.value || null })} />
          </Field>
          {text('geburtsort', 'Geburtsort')}
        </div>
        {text('staatsangehoerigkeit', 'Staatsangehörigkeit')}
        {text('anschrift', 'Anschrift', 2)}
        {text('kennzeichen', 'Kennzeichen')}
        <ImageField label="Titelbild (weitere Fotos in der App)" blobId={data.fotoBlob} onChange={(fotoBlob) => set({ fotoBlob })} />
        {text('hinweise', 'Notizen: Merkmale, Sachverhalt, Hinweise, Maßnahmen', 10)}
        <Field label="GPS-Tracker">
          <select value={data.trackerId ?? ''} onChange={(e) => set({ trackerId: e.currentTarget.value || null })}>
            <option value="">Keiner</option>
            {Object.values(tables.tracker.value).map((t) => (
              <option key={t.id} value={t.id}>
                {t.data.name}
              </option>
            ))}
          </select>
        </Field>
        <div class="row">
          <button
            class="primary"
            onClick={() => {
              if (put('target', id, data)) editing.value = null;
            }}
          >
            Sichern
          </button>
          {!neu && (
            <button
              class="danger"
              onClick={() => {
                if (confirm('Ziel für alle löschen?') && del('target', id)) editing.value = null;
              }}
            >
              Löschen
            </button>
          )}
        </div>
      </Section>
    );
  }

  return (
    <Section
      title="Ziele"
      actions={
        <button class="primary" onClick={() => (editing.value = { id: newId(), data: { ...LEER }, neu: true })}>
          Anlegen
        </button>
      }
    >
      {targets.length === 0 && <p class="hint">Noch kein Ziel angelegt. Zielpersonen, Zielfahrzeuge und Zielobjekte lassen sich hier oder über die Werkzeugleiste der Karte anlegen.</p>}
      <ul class="list">
        {targets.map((t) => {
          const position = trackerPoint(t.data.trackerId) ?? t.data.standort ?? undefined;
          const age = ageOf(t.data.geburtsdatum);
          return (
            <li key={t.id} class={targetShown(t.id) ? '' : 'ruhend'}>
              <input type="checkbox" title="In dieser Instanz für alle sichtbar" checked={targetShown(t.id)} onChange={() => setTargetShown(t.id, !targetShown(t.id))} />
              {t.data.fotoBlob ? <img class="thumb" src={`/api/v1/blobs/${t.data.fotoBlob}`} alt="" /> : <div class="thumb empty">{t.data.art === 'fahrzeug' ? 'ZF' : t.data.art === 'objekt' ? 'ZO' : 'ZP'}</div>}
              <div class="grow">
                <b>{anzeigename(t.data)}</b>
                <small>
                  {[ZIEL_TITEL[t.data.art], age !== null ? `${age} Jahre` : '', t.data.kennzeichen].filter(Boolean).join(', ')}
                  {position ? `, Standort ${ago(position.ts)}` : ''}
                </small>
                <small class="hint">Geändert von {nameOf(t.updatedBy)}</small>
              </div>
              {position && (
                <button class="quiet" onClick={() => (focusRequest.value = { ...position, at: Date.now() })}>
                  Zeigen
                </button>
              )}
              <button onClick={() => (editing.value = { id: t.id, data: { ...t.data }, neu: false })}>Bearbeiten</button>
            </li>
          );
        })}
      </ul>
    </Section>
  );
}
