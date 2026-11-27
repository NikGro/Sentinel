import { useSignal } from '@preact/signals';
import { del, focusRequest, groupShown, nameOf, newId, put, setGroupShown, setTargetShown, tables, targetShown, tool, trackerPoint } from '../store';
import { ZIEL_TITEL, type Entity, type Relation, type Target, type ZielArt } from '../types';
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
  const groups = Object.values(tables.targetGroup.value).sort((a, b) => a.data.name.localeCompare(b.data.name, 'de'));
  const edit = (t: (typeof targets)[number]) => (editing.value = { id: t.id, data: { ...t.data }, neu: false });

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
        <Field label="Gruppe">
          <select value={data.gruppeId ?? ''} onChange={(e) => set({ gruppeId: e.currentTarget.value || null })}>
            <option value="">Keine</option>
            {Object.values(tables.targetGroup.value).map((g) => (
              <option key={g.id} value={g.id}>
                {g.data.name}
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
        {data.art === 'person' && (
          <>
            <div class="grid2">
              {text('vorname', 'Vorname')}
              {text('nachname', 'Nachname')}
              <Field label={`Geburtsdatum${ageOf(data.geburtsdatum) !== null ? ` (${ageOf(data.geburtsdatum)} Jahre)` : ''}`}>
                <input type="date" value={data.geburtsdatum ?? ''} onInput={(e) => set({ geburtsdatum: e.currentTarget.value || null })} />
              </Field>
              {text('geburtsort', 'Geburtsort')}
            </div>
            {text('staatsangehoerigkeit', 'Staatsangehörigkeit')}
          </>
        )}
        {data.art === 'objekt' && text('anschrift', 'Anschrift', 2)}
        {data.art === 'fahrzeug' && text('kennzeichen', 'Kennzeichen')}
        {/* Frühere Freitextangaben (Halter, Wohnanschrift, genutztes Fahrzeug) bleiben lesbar, bis sie als Beziehung angelegt sind. */}
        {data.art !== 'objekt' && data.anschrift && text('anschrift', 'Frühere Angabe Anschrift (bitte als Beziehung zu einem Zielobjekt anlegen)', 2)}
        {data.art !== 'person' && (data.vorname || data.nachname) && (
          <p class="hint">Frühere Angabe Person: {[data.vorname, data.nachname].filter(Boolean).join(' ')}. Bitte als Zielperson anlegen und verbinden.</p>
        )}
        {data.art === 'person' && data.kennzeichen && text('kennzeichen', 'Frühere Angabe Kennzeichen (bitte als Zielfahrzeug anlegen und verbinden)')}
        {neu ? <p class="hint">Beziehungen zu anderen Zielen lassen sich nach dem Sichern herstellen.</p> : <Relations targetId={id} />}
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
      <div class="row">
        <button
          onClick={() => {
            const name = prompt('Name der Gruppe');
            if (name?.trim()) put('targetGroup', newId(), { name: name.trim() });
          }}
        >
          Gruppe anlegen
        </button>
      </div>
      {groups.map((g) => (
        <div key={g.id} class={groupShown(g.id) ? '' : 'ruhend'}>
          <div class="row">
            <input type="checkbox" title="Gruppe in dieser Instanz einblenden" checked={groupShown(g.id)} onChange={() => setGroupShown(g.id, !groupShown(g.id))} />
            <span class="thumb empty" style={{ background: g.data.farbe ?? '#0A84FF', color: '#fff', width: '28px', height: '28px' }}>{g.data.name.slice(0, 1)}</span>
            <b class="grow">{g.data.name}</b>
            <button
              class="quiet"
              onClick={() => {
                const name = prompt('Gruppe umbenennen', g.data.name);
                if (name?.trim()) put('targetGroup', g.id, { name: name.trim() });
              }}
            >
              Umbenennen
            </button>
            <button class="quiet" onClick={() => confirm(`Gruppe „${g.data.name}“ auflösen? Die Ziele bleiben erhalten.`) && del('targetGroup', g.id)}>
              Auflösen
            </button>
          </div>
          <TargetList items={targets.filter((t) => t.data.gruppeId === g.id)} onEdit={edit} />
        </div>
      ))}
      <TargetList items={targets.filter((t) => !t.data.gruppeId || !tables.targetGroup.value[t.data.gruppeId])} onEdit={edit} />
    </Section>
  );
}

/** Beziehungen eines Ziels zu anderen Zielen, von beiden Seiten gleich sichtbar und bearbeitbar. */
function Relations(props: { targetId: string }) {
  const editing = useSignal<{ id: string; data: Relation; neu: boolean } | null>(null);
  const relations = Object.values(tables.relation.value).filter((r) => r.data.von === props.targetId || r.data.nach === props.targetId);
  const others = Object.values(tables.target.value).filter((t) => t.id !== props.targetId).sort((a, b) => anzeigename(a.data).localeCompare(anzeigename(b.data)));
  const otherOf = (r: Relation) => tables.target.value[r.von === props.targetId ? r.nach : r.von];

  if (editing.value) {
    const { id, data, neu } = editing.value;
    const set = (patch: Partial<Relation>) => (editing.value = { id, neu, data: { ...data, ...patch } });
    const other = data.von === props.targetId ? data.nach : data.von;
    return (
      <div class="field">
        <span>{neu ? 'Neue Beziehung' : 'Beziehung bearbeiten'}</span>
        <Field label="Verbunden mit">
          <select value={other} onChange={(e) => set({ nach: e.currentTarget.value, von: props.targetId })}>
            <option value="">Ziel wählen</option>
            {others.map((t) => (
              <option key={t.id} value={t.id}>{`${ZIEL_TITEL[t.data.art]}: ${anzeigename(t.data)}`}</option>
            ))}
          </select>
        </Field>
        <Field label="Art der Beziehung, z. B. Halter, Fahrer, Bewohner">
          <TextInput value={data.bezeichnung} maxLength={200} onInput={(v) => set({ bezeichnung: v })} />
        </Field>
        <div class="row">
          <button class="primary" disabled={!other} onClick={() => { if (put('relation', id, data)) editing.value = null; }}>Sichern</button>
          <button class="quiet" onClick={() => (editing.value = null)}>Abbrechen</button>
          {!neu && <button class="danger" onClick={() => { if (confirm('Beziehung löschen?') && del('relation', id)) editing.value = null; }}>Löschen</button>}
        </div>
      </div>
    );
  }

  return (
    <div class="field">
      <span>Beziehungen</span>
      {relations.length === 0 && <p class="hint">Nicht zugeordnet. Personen, Fahrzeuge und Objekte werden als eigene Ziele angelegt und hier verbunden.</p>}
      <ul class="list">
        {relations.map((r) => {
          const other = otherOf(r.data);
          return (
            <li key={r.id} class={r.data.status === 'beendet' ? 'ruhend' : ''}>
              <div class="grow">
                <b>{other ? anzeigename(other.data) : 'Unbekanntes Ziel'}</b>
                <small>{[r.data.bezeichnung || 'Verbunden', other ? ZIEL_TITEL[other.data.art] : ''].filter(Boolean).join(', ')}</small>
              </div>
              <button onClick={() => (editing.value = { id: r.id, data: { ...r.data }, neu: false })}>Bearbeiten</button>
            </li>
          );
        })}
      </ul>
      <div class="row">
        <button onClick={() => (editing.value = { id: newId(), neu: true, data: { von: props.targetId, nach: '', bezeichnung: '', notiz: '', status: 'vermutet', herkunft: '' } })}>Beziehung hinzufügen</button>
      </div>
    </div>
  );
}

/** Ziele einer Gruppe bzw. ungruppierte Ziele; der Haken blendet das einzelne Ziel ein und aus. */
function TargetList(props: { items: Entity<Target>[]; onEdit: (t: Entity<Target>) => void }) {
  return (
    <ul class="list">
      {props.items.map((t) => {
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
              <button onClick={() => props.onEdit(t)}>Bearbeiten</button>
            </li>
          );
        })}
    </ul>
  );
}
