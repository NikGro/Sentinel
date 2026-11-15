import { useSignal } from '@preact/signals';
import { adminStatus, api, attempt, del, hiddenLayers, layers, newId, put, tables, targetLayer } from '../store';
import { Field, Section, TextInput } from '../ui';

const ART_TITEL = { lage: 'Laufende Lage', dauerhaft: 'Dauerhaft', paket: 'Paket', argus: 'Argus Predict' } as const;

/** Ebenen und Pakete: vorbereiten, in die Lage laden, ein- und ausblenden, Argus-Prognosen importieren. */
export function LayersPanel() {
  const name = useSignal('');
  const counts = new Map<string, number>();
  for (const o of Object.values(tables.annotation.value)) counts.set(o.data.layerId, (counts.get(o.data.layerId) ?? 0) + 1);

  const toggleHidden = (id: string) => {
    const next = new Set(hiddenLayers.value);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    hiddenLayers.value = next;
  };

  const importFile = async (file: File) => {
    await attempt(async () => {
      const body = JSON.parse(await file.text());
      const result = await api('/admin/ebenen/import', { method: 'POST', body });
      targetLayer.value = result.layerId;
    }, 'Paket als Entwurf importiert.');
  };

  return (
    <>
      <Section title="Ebenen" hint="Entwürfe sieht nur die Kommandozentrale. „Laden“ macht ein Paket für alle im Einsatz sichtbar.">
        <ul class="list">
          {layers.value.map((layer) => {
            const draft = layer.data.status === 'entwurf';
            const fixed = layer.id === 'lage' || layer.id === 'dauerhaft';
            return (
              <li key={layer.id} class={draft ? 'entwurf' : ''}>
                <input type="checkbox" title="Auf dieser Karte anzeigen" checked={!hiddenLayers.value.has(layer.id)} onChange={() => toggleHidden(layer.id)} />
                <div class="grow">
                  <b>{layer.data.name}</b>
                  <small>
                    {ART_TITEL[layer.data.art]} · {counts.get(layer.id) ?? 0} Objekte{draft ? ' · Entwurf' : ''}
                  </small>
                </div>
                {!fixed && (
                  <>
                    <button class={draft ? 'primary' : ''} onClick={() => put('layer', layer.id, { ...layer.data, status: draft ? 'live' : 'entwurf' })}>
                      {draft ? 'Laden' : 'Zurückziehen'}
                    </button>
                    <a class="button quiet" href={`/api/v1/admin/ebenen/${layer.id}/export`} download title="Als Datei sichern">
                      ⭳
                    </a>
                    <button
                      class="quiet"
                      title="Löschen"
                      onClick={() => {
                        if (confirm(`Ebene „${layer.data.name}“ samt Inhalt löschen?`)) del('layer', layer.id);
                      }}
                    >
                      ✕
                    </button>
                  </>
                )}
              </li>
            );
          })}
        </ul>
      </Section>

      <Section title="Paket vorbereiten" hint="Neues Paket anlegen, dann über der Karte als Zielebene wählen und Marker setzen. Die Kräfte sehen es erst nach dem Laden.">
        <div class="row">
          <input placeholder="Name, z. B. Einsatz Dienstag" maxLength={60} value={name.value} onInput={(e) => (name.value = e.currentTarget.value)} />
          <button
            class="primary"
            disabled={!name.value.trim()}
            onClick={() => {
              const id = `paket-${newId().slice(0, 10)}`;
              if (put('layer', id, { name: name.value.trim(), art: 'paket', status: 'entwurf', beschreibung: '' })) {
                targetLayer.value = id;
                name.value = '';
              }
            }}
          >
            Anlegen
          </button>
        </div>
        <label class="button">
          Paketdatei importieren
          <input
            type="file"
            accept="application/json,.json"
            hidden
            onChange={(e) => {
              const file = e.currentTarget.files?.[0];
              if (file) void importFile(file);
              e.currentTarget.value = '';
            }}
          />
        </label>
      </Section>

      <ArgusImport />
    </>
  );
}

function ArgusImport() {
  const argus = adminStatus.value?.argus;
  const projekt = useSignal('');
  const datum = useSignal(new Date().toLocaleDateString('sv-SE'));
  const von = useSignal(String(new Date().getHours()));
  const bis = useSignal('23');
  const top = useSignal('40');
  const entwurf = useSignal(false);

  if (!argus?.verfuegbar) {
    return (
      <Section title="Argus Predict">
        <p class="hint">Der Argus-Datenordner ist auf diesem Server nicht eingebunden.</p>
      </Section>
    );
  }
  const selected = argus.projekte.find((p) => p.name === (projekt.value || argus.projekte[0]?.name));
  const available = selected?.tage.includes(datum.value) ?? false;

  return (
    <Section title="Argus Predict" hint="Lädt die auffälligsten Prognosezellen eines Tages als eigene Ebene, z. B. für die Oberflächenfahndung.">
      <div class="grid2">
        <Field label="Projekt">
          <select value={selected?.name ?? ''} onChange={(e) => (projekt.value = e.currentTarget.value)}>
            {argus.projekte.map((p) => (
              <option key={p.name} value={p.name}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Tag">
          <input type="date" value={datum.value} onInput={(e) => (datum.value = e.currentTarget.value)} />
        </Field>
        <Field label="Von Stunde">
          <TextInput type="number" value={von.value} onInput={(v) => (von.value = v)} />
        </Field>
        <Field label="Bis Stunde">
          <TextInput type="number" value={bis.value} onInput={(v) => (bis.value = v)} />
        </Field>
        <Field label="Anzahl Zellen">
          <TextInput type="number" value={top.value} onInput={(v) => (top.value = v)} />
        </Field>
      </div>
      {selected && !available && (
        <p class="hint">
          Für diesen Tag liegt keine Prognose vor (vorhanden: {selected.tage[0] ?? '–'} bis {selected.tage.at(-1) ?? '–'}). Bitte in Argus Predict eine Vorhersage erzeugen.
        </p>
      )}
      <label class="check">
        <input type="checkbox" checked={entwurf.value} onChange={() => (entwurf.value = !entwurf.value)} />
        Zunächst nur als Entwurf
      </label>
      <button
        class="primary"
        disabled={!selected || !available}
        onClick={() =>
          attempt(
            () =>
              api('/admin/argus/import', {
                method: 'POST',
                body: { projekt: selected!.name, datum: datum.value, vonStunde: Number(von.value), bisStunde: Number(bis.value), top: Number(top.value), alsEntwurf: entwurf.value },
              }),
            'Argus-Ebene importiert.',
          )
        }
      >
        Importieren
      </button>
    </Section>
  );
}
