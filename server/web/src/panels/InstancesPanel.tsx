import { useSignal } from '@preact/signals';
import { command, currentInstance, instances, instanz, nameOf, newId, openInstance, tables } from '../store';
import { Field, Section, TextInput } from '../ui';

/**
 * Instanzen: Die Kommandozentrale schaut je Fenster in eine Instanz, ohne selbst Mitglied zu sein.
 * Pakete werden wie eine Instanz bearbeitet und in den geöffneten Einsatz übernommen.
 */
export function InstancesPanel() {
  const name = useSignal('');
  const paket = useSignal(false);
  const current = currentInstance.value;
  const einsaetze = instances.value.filter((i) => i.data.art === 'einsatz');
  const pakete = instances.value.filter((i) => i.data.art === 'paket');
  const target = current?.data.art === 'einsatz' ? current : null;

  const create = () => {
    const trimmed = name.value.trim();
    if (!trimmed) return;
    const id = newId();
    command('instanz.erstellen', { id, name: trimmed, art: paket.value ? 'paket' : 'einsatz' });
    // Die Zentrale wird nicht automatisch Mitglied; sie öffnet die neue Instanz selbst.
    window.setTimeout(() => openInstance(id), 300);
    name.value = '';
  };

  const members = (ids: string[]) => (ids.length === 0 ? 'keine Mitglieder' : ids.map(nameOf).join(', '));

  return (
    <>
      <Section title="Einsätze" hint="Jede Instanz hat ihre eigene Lage, Ziele, Chats, A-Position und Notrufe. Die dauerhaften Orte gelten in allen.">
        <ul class="list">
          {einsaetze.map((i) => {
            const open = i.id === instanz.value;
            const here = Object.values(tables.member.value).filter((m) => (m.data.instanz ?? 'haupt') === i.id).length;
            return (
              <li key={i.id}>
                <div class="grow">
                  <b>{i.data.name}</b>
                  <small>
                    {i.id === 'haupt' ? 'Alle Fahnder' : members(i.data.mitglieder)}, {here} geöffnet
                  </small>
                </div>
                {open ? <span class="tag">Geöffnet</span> : <button onClick={() => openInstance(i.id)}>Öffnen</button>}
                {i.id !== 'haupt' && (
                  <button
                    class="quiet"
                    title="Löschen"
                    onClick={() => {
                      if (confirm(`Instanz „${i.data.name}“ mit Lage, Zielen und Chats für alle löschen?`)) command('instanz.loeschen', { id: i.id });
                    }}
                  >
                    ✕
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      </Section>

      <Section title="Pakete" hint="Vorbereitete Objekte in einer Bibliothek auf dem Server. Übernehmen kopiert sie in den geöffneten Einsatz; danach sind sie eigenständig. Das lässt sich nicht rückgängig machen.">
        <ul class="list">
          {pakete.length === 0 && <li class="empty">Noch keine Pakete.</li>}
          {pakete.map((p) => (
            <li key={p.id}>
              <div class="grow">
                <b>{p.data.name}</b>
                {p.data.beschreibung && <small>{p.data.beschreibung}</small>}
              </div>
              {p.id === instanz.value ? <span class="tag">In Bearbeitung</span> : <button onClick={() => openInstance(p.id)}>Bearbeiten</button>}
              {target && (
                <button
                  class="primary"
                  onClick={() => {
                    if (confirm(`„${p.data.name}“ in „${target.data.name}“ übernehmen? Die Objekte werden kopiert und sind danach eigenständig. Das lässt sich nicht rückgängig machen.`)) {
                      command('paket.importieren', { paketId: p.id });
                    }
                  }}
                >
                  Übernehmen
                </button>
              )}
              <button
                class="quiet"
                title="Löschen"
                onClick={() => {
                  if (confirm(`Paket „${p.data.name}“ löschen? Bereits übernommene Objekte bleiben.`)) command('instanz.loeschen', { id: p.id });
                }}
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      </Section>

      <Section title="Neu anlegen">
        <Field label="Name">
          <TextInput value={name.value} onInput={(v) => (name.value = v)} maxLength={60} placeholder="z. B. Einsatz Nord" />
        </Field>
        <label class="check">
          <input type="checkbox" checked={paket.value} onChange={() => (paket.value = !paket.value)} /> Als Paket vorbereiten
        </label>
        <button class="primary" disabled={!name.value.trim()} onClick={create}>
          Anlegen und öffnen
        </button>
      </Section>
    </>
  );
}
