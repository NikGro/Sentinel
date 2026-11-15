import { useSignal } from '@preact/signals';
import { del, focusRequest, newId, online, operation, positions, put, tables, trackerPositions } from '../store';
import type { Vehicle } from '../types';
import { ago, Field, ImageField, Section, TextInput } from '../ui';

/** Kräfte im Einsatz und die Fahrzeugflotte. */
export function TeamPanel() {
  const editing = useSignal<{ id: string; data: Vehicle; neu: boolean } | null>(null);
  const members = Object.values(tables.member.value).sort((a, b) => a.data.funkrufname.localeCompare(b.data.funkrufname, 'de', { numeric: true }));
  const vehicles = Object.values(tables.vehicle.value).sort((a, b) => a.data.bezeichnung.localeCompare(b.data.bezeichnung));

  if (editing.value) {
    const { id, data, neu } = editing.value;
    const set = (patch: Partial<Vehicle>) => (editing.value = { id, neu, data: { ...data, ...patch } });
    return (
      <Section
        title={neu ? 'Neues Fahrzeug' : data.bezeichnung}
        actions={
          <button class="quiet" onClick={() => (editing.value = null)}>
            Zurück
          </button>
        }
      >
        <Field label="Bezeichnung">
          <TextInput value={data.bezeichnung} onInput={(bezeichnung) => set({ bezeichnung })} placeholder="z. B. Golf grau" maxLength={60} />
        </Field>
        <Field label="Kennzeichen">
          <TextInput value={data.kennzeichen} onInput={(kennzeichen) => set({ kennzeichen })} maxLength={16} />
        </Field>
        <Field label="Beschreibung">
          <TextInput value={data.beschreibung} onInput={(beschreibung) => set({ beschreibung })} rows={2} maxLength={300} />
        </Field>
        <ImageField label="Fahrzeugbild" blobId={data.fotoBlob} onChange={(fotoBlob) => set({ fotoBlob })} />
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
            disabled={!data.bezeichnung.trim()}
            onClick={() => {
              if (put('vehicle', id, data)) editing.value = null;
            }}
          >
            Sichern
          </button>
          {!neu && (
            <button
              class="danger"
              onClick={() => {
                if (confirm('Fahrzeug für alle löschen?') && del('vehicle', id)) editing.value = null;
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
    <>
      <Section title="Kräfte">
        {members.length === 0 && <p class="hint">Noch niemand angemeldet. Den Zugangscode finden Sie unter „System“.</p>}
        <ul class="list">
          {members.map((m) => {
            const position = positions.value[m.id];
            const vehicle = m.data.fahrzeugId ? tables.vehicle.value[m.data.fahrzeugId] : undefined;
            return (
              <li key={m.id}>
                <span class={`presence ${online.value.has(m.id) ? 'on' : ''}`} />
                <div class="grow">
                  <b>
                    {m.data.funkrufname}
                    {operation.value.a?.memberId === m.id && <span class="badge-a">A</span>}
                  </b>
                  <small>
                    {m.data.name}, {m.data.dienststelle}
                  </small>
                  <small class="hint">
                    {[m.data.telefon, vehicle ? `in ${vehicle.data.bezeichnung}` : '', position ? `Position ${ago(position.ts)}` : 'keine Position'].filter(Boolean).join(', ')}
                  </small>
                </div>
                {position && (
                  <button class="quiet" onClick={() => (focusRequest.value = { ...position, at: Date.now() })}>
                    Zeigen
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      </Section>

      <Section
        title="Fahrzeuge"
        hint="Ein- und Ausgestiegen wird in der App. Mit Tracker meldet das Fahrzeug seinen Standort selbst."
        actions={
          <button
            class="primary"
            onClick={() => (editing.value = { id: newId(), neu: true, data: { bezeichnung: '', kennzeichen: '', beschreibung: '', fotoBlob: null, trackerId: null, abgestellt: null } })}
          >
            Anlegen
          </button>
        }
      >
        <ul class="list">
          {vehicles.map((v) => {
            const crew = members.filter((m) => m.data.fahrzeugId === v.id).map((m) => m.data.funkrufname);
            const tracked = v.data.trackerId ? trackerPositions.value[v.data.trackerId] : undefined;
            const point = tracked ?? v.data.abgestellt ?? undefined;
            return (
              <li key={v.id}>
                <div class="grow">
                  <b>{v.data.bezeichnung}</b>
                  <small>{[v.data.kennzeichen, crew.length ? `Besetzt: ${crew.join(', ')}` : 'Unbesetzt', tracked ? `Tracker ${ago(tracked.ts)}` : ''].filter(Boolean).join(', ')}</small>
                </div>
                {point && (
                  <button class="quiet" onClick={() => (focusRequest.value = { ...point, at: Date.now() })}>
                    Zeigen
                  </button>
                )}
                <button onClick={() => (editing.value = { id: v.id, data: { ...v.data }, neu: false })}>Bearbeiten</button>
              </li>
            );
          })}
        </ul>
      </Section>
    </>
  );
}
