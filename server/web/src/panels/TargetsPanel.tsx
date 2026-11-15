import { useSignal } from '@preact/signals';
import { del, focusRequest, nameOf, newId, put, tables, trackerPositions } from '../store';
import type { Target } from '../types';
import { ageOf, ago, Field, ImageField, Section, TextInput } from '../ui';

const LEER: Target = {
  vorname: '', nachname: '', geburtsdatum: null, geburtsort: '', staatsangehoerigkeit: '', anschrift: '', merkmale: '', fotoBlob: null,
  kennzeichen: '', fahrzeugBeschreibung: '', fahrzeugFotoBlob: null, sachverhalt: '', hinweise: '', massnahmen: '', trackerId: null,
};

const anzeigename = (t: Target) => [t.vorname, t.nachname].filter(Boolean).join(' ') || 'Unbekannte Person';

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
        title={neu ? 'Neue Zielperson' : anzeigename(data)}
        actions={
          <button class="quiet" onClick={() => (editing.value = null)}>
            Zurück
          </button>
        }
      >
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
        {text('merkmale', 'Optische Merkmale', 3)}
        <ImageField label="Bild" blobId={data.fotoBlob} onChange={(fotoBlob) => set({ fotoBlob })} />
        <div class="grid2">
          {text('kennzeichen', 'Kennzeichen')}
          {text('fahrzeugBeschreibung', 'Fahrzeug')}
        </div>
        <ImageField label="Fahrzeugbild" blobId={data.fahrzeugFotoBlob} onChange={(fahrzeugFotoBlob) => set({ fahrzeugFotoBlob })} />
        {text('sachverhalt', 'Sachverhalt', 4)}
        {text('hinweise', 'Hinweise', 3)}
        {text('massnahmen', 'Zu treffende Maßnahmen', 3)}
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
                if (confirm('Zielperson für alle löschen?') && del('target', id)) editing.value = null;
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
      title="Zielpersonen"
      actions={
        <button class="primary" onClick={() => (editing.value = { id: newId(), data: { ...LEER }, neu: true })}>
          Anlegen
        </button>
      }
    >
      {targets.length === 0 && <p class="hint">Noch keine Zielperson angelegt.</p>}
      <ul class="list">
        {targets.map((t) => {
          const position = t.data.trackerId ? trackerPositions.value[t.data.trackerId] : undefined;
          const age = ageOf(t.data.geburtsdatum);
          return (
            <li key={t.id}>
              {t.data.fotoBlob ? <img class="thumb" src={`/api/v1/blobs/${t.data.fotoBlob}`} alt="" /> : <div class="thumb empty">ZP</div>}
              <div class="grow">
                <b>{anzeigename(t.data)}</b>
                <small>
                  {[age !== null ? `${age} Jahre` : '', t.data.kennzeichen].filter(Boolean).join(', ') || 'keine Angaben'}
                  {position ? `, Tracker ${ago(position.ts)}` : ''}
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
