import { useSignal } from '@preact/signals';
import { del, focusRequest, newId, online, operation, positions, put, tables, trackerPoint, vehicleOf } from '../store';
import { FORTBEWEGUNG_TITEL, type Vehicle } from '../types';
import { ago, Field, ImageField, Section, TextInput } from '../ui';

const LEERES_FAHRZEUG: Vehicle = { funkrufname: '', bezeichnung: '', kennzeichen: '', beschreibung: '', fotoBlob: null, trackerId: null, aktiv: true, abgestellt: null };

/** Kräfte im Einsatz und die Fahrzeugflotte. Fahnder schalten sich in der App selbst aktiv, Fahrzeuge kann jeder schalten. */
export function TeamPanel() {
  const editing = useSignal<{ id: string; data: Vehicle; neu: boolean } | null>(null);
  const members = Object.values(tables.member.value).sort((a, b) => Number(b.data.aktiv) - Number(a.data.aktiv) || a.data.spitzname.localeCompare(b.data.spitzname, 'de'));
  const vehicles = Object.values(tables.vehicle.value).sort((a, b) => Number(b.data.aktiv) - Number(a.data.aktiv) || a.data.funkrufname.localeCompare(b.data.funkrufname, 'de', { numeric: true }));

  if (editing.value) {
    const { id, data, neu } = editing.value;
    const set = (patch: Partial<Vehicle>) => (editing.value = { id, neu, data: { ...data, ...patch } });
    return (
      <Section
        title={neu ? 'Neues Fahrzeug' : data.funkrufname}
        actions={
          <button class="quiet" onClick={() => (editing.value = null)}>
            Zurück
          </button>
        }
      >
        <Field label="Funkrufname (z. B. P 35/24)">
          <TextInput value={data.funkrufname} onInput={(funkrufname) => set({ funkrufname })} maxLength={20} />
        </Field>
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
        <label class="check">
          <input type="checkbox" checked={data.aktiv} onChange={() => set({ aktiv: !data.aktiv })} />
          Im heutigen Einsatz aktiv
        </label>
        <div class="row">
          <button
            class="primary"
            disabled={!data.funkrufname.trim()}
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
      <Section title="Fahnder" hint="Jeder Fahnder legt sich in der App selbst an und schaltet dort Ruhemodus und Fortbewegung.">
        {members.length === 0 && <p class="hint">Noch niemand angemeldet. Den Zugangscode finden Sie unter System.</p>}
        <ul class="list">
          {members.map((m) => {
            const position = positions.value[m.id];
            const vehicle = vehicleOf(m.data);
            return (
              <li key={m.id} class={m.data.aktiv ? '' : 'ruhend'}>
                <span class={`presence ${online.value.has(m.id) && m.data.aktiv ? 'on' : ''}`} />
                <div class="grow">
                  <b>
                    {m.data.spitzname}
                    {operation.value.a?.memberId === m.id && <span class="badge-a">A</span>}
                  </b>
                  <small>
                    {m.data.name}, {m.data.dienststelle}
                  </small>
                  <small class="hint">
                    {m.data.aktiv
                      ? [
                          vehicle ? `im Fahrzeug ${vehicle.data.funkrufname}` : m.data.fortbewegung === 'oepnv' && m.data.oepnv ? `${m.data.oepnv.linie} Richtung ${m.data.oepnv.richtung}` : FORTBEWEGUNG_TITEL[m.data.fortbewegung],
                          m.data.telefon,
                          position ? `Position ${ago(position.ts)}` : 'keine Position',
                        ]
                          .filter(Boolean)
                          .join(', ')
                      : 'Ruhemodus'}
                  </small>
                </div>
                {position && m.data.aktiv && (
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
        hint="Fahrzeuge bleiben dauerhaft angelegt und werden für den Einsatz aktiv geschaltet. Steigt der letzte Insasse aus, bleibt das Fahrzeug an Ort und Stelle; mit Tracker meldet es seinen Standort selbst."
        actions={
          <button class="primary" onClick={() => (editing.value = { id: newId(), neu: true, data: { ...LEERES_FAHRZEUG } })}>
            Anlegen
          </button>
        }
      >
        <ul class="list">
          {vehicles.map((v) => {
            const crew = members.filter((m) => m.data.aktiv && vehicleOf(m.data)?.id === v.id).map((m) => m.data.spitzname);
            const tracked = trackerPoint(v.data.trackerId);
            const point = tracked ?? v.data.abgestellt ?? undefined;
            return (
              <li key={v.id} class={v.data.aktiv ? '' : 'ruhend'}>
                <input type="checkbox" title="Im Einsatz aktiv" checked={v.data.aktiv} onChange={() => put('vehicle', v.id, { ...v.data, aktiv: !v.data.aktiv })} />
                <div class="grow">
                  <b>{v.data.funkrufname}</b>
                  <small>{[v.data.bezeichnung, v.data.kennzeichen].filter(Boolean).join(', ') || 'ohne Beschreibung'}</small>
                  <small class="hint">
                    {[v.data.aktiv ? (crew.length ? `Besetzt: ${crew.join(', ')}` : 'Unbesetzt') : 'Nicht im Einsatz', tracked ? `Tracker ${ago(tracked.ts)}` : ''].filter(Boolean).join(', ')}
                  </small>
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
