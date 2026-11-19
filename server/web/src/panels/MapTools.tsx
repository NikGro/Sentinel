import { useSignal } from '@preact/signals';
import { finishDrawing } from '../map';
import { canRedo, canUndo, deleteObject, isLocked, layers, nameOf, newId, put, redo, saveObject, selectedObject, tables, targetLayer, tool, undo, uploadFile } from '../store';
import { PALETTE, SHAPE_TITEL, ZIEL_TITEL, type Attachment, type MapObject, type Shape, type Target, type ZielArt } from '../types';
import { ago, dateTime, Field, TextInput } from '../ui';

const HINWEIS: Record<string, string> = {
  zielstandort: 'Standort des Ziels auf der Karte anklicken',
  verschieben: 'Neuen Ort auf der Karte anklicken',
};

const NEUES_ZIEL = (art: ZielArt): Target => ({
  art,
  bezeichnung: '',
  standort: null,
  vorname: '',
  nachname: '',
  geburtsdatum: null,
  geburtsort: '',
  staatsangehoerigkeit: '',
  anschrift: '',
  merkmale: '',
  fotoBlob: null,
  kennzeichen: '',
  fahrzeugBeschreibung: '',
  fahrzeugFotoBlob: null,
  sachverhalt: '',
  hinweise: '',
  massnahmen: '',
  trackerId: null,
});

/** Legt ein neues Ziel an und lässt seinen Standort auf der Karte setzen. Bearbeitet wird es danach unter Ziele. */
function placeTarget(art: ZielArt): void {
  const id = newId();
  if (put('target', id, NEUES_ZIEL(art))) tool.value = { kind: 'zielstandort', targetId: id };
}

/** Werkzeugleiste über der Karte: Markierungen zeichnen, Zielebene wählen, Rückgängig/Wiederholen. */
export function MapToolbar() {
  const current = tool.value;
  const drawing = current.kind === 'zeichnen' ? current : null;
  const multi = drawing && (drawing.shape === 'linie' || drawing.shape === 'pfeil' || drawing.shape === 'flaeche');
  const hint = drawing ? (multi ? `${SHAPE_TITEL[drawing.shape]}: Punkte anklicken, Doppelklick beendet (${drawing.punkte.length} gesetzt)` : `${SHAPE_TITEL[drawing.shape]}: Ort anklicken`) : HINWEIS[current.kind];

  return (
    <div class="toolbar">
      <div class="toolbar-row">
        {(Object.keys(SHAPE_TITEL) as Shape[]).filter((s) => s !== 'oepnvlinie' && s !== 'oepnvfahrzeug' && s !== 'haltestelle').map((shape) => (
          <button key={shape} class={drawing?.shape === shape ? 'active' : ''} onClick={() => (tool.value = drawing?.shape === shape ? { kind: 'auswahl' } : { kind: 'zeichnen', shape, punkte: [] })}>
            {SHAPE_TITEL[shape]}
          </button>
        ))}
        <span class="divider" />
        {(Object.keys(ZIEL_TITEL) as ZielArt[]).map((art) => (
          <button key={art} class={`ziel-${art}`} onClick={() => placeTarget(art)}>
            {ZIEL_TITEL[art]}
          </button>
        ))}
        <span class="divider" />
        <label class="inline">
          in Ebene
          <select value={targetLayer.value} onChange={(e) => (targetLayer.value = e.currentTarget.value)}>
            {layers.value
              .filter((l) => l.data.art !== 'argus' && !isLocked(l.id))
              .map((l) => (
                <option key={l.id} value={l.id}>
                  {l.data.name}
                  {l.data.status === 'entwurf' ? ' (Entwurf)' : ''}
                </option>
              ))}
          </select>
        </label>
        <span class="divider" />
        <button disabled={!canUndo.value} onClick={undo} title="Eigene Bearbeitung rückgängig machen">
          ↶ Rückgängig
        </button>
        <button disabled={!canRedo.value} onClick={redo} title="Wiederholen">
          ↷ Wiederholen
        </button>
      </div>
      {hint && (
        <div class="toolbar-hint">
          <span>{hint}</span>
          {multi && (
            <button class="primary" onClick={() => finishDrawing(drawing.shape, drawing.punkte)}>
              Fertig
            </button>
          )}
          <button class="quiet" onClick={() => (tool.value = { kind: 'auswahl' })}>
            Abbrechen
          </button>
        </div>
      )}
    </div>
  );
}

/** Bearbeitung der ausgewählten Markierung. Jeder darf jede Markierung ändern. */
export function ObjectEditor() {
  const id = selectedObject.value;
  const entity = id ? tables.annotation.value[id] : undefined;
  if (!id || !entity) return null;
  // Der Schlüssel sorgt dafür, dass das Formular bei Auswahlwechsel oder fremder Änderung neu aufgebaut wird.
  return <ObjectForm key={`${id}:${entity.rev}`} id={id} initial={entity.data} updatedBy={entity.updatedBy} updatedAt={entity.updatedAt} />;
}

function ObjectForm(props: { id: string; initial: MapObject; updatedBy: string; updatedAt: number }) {
  const { id } = props;
  const draft = useSignal<MapObject>(props.initial);
  const object = draft.value;
  const change = (patch: Partial<MapObject>) => (draft.value = { ...object, ...patch });
  const dirty = JSON.stringify(object) !== JSON.stringify(props.initial);
  const locked = isLocked(props.initial.layerId);
  if (locked) {
    return (
      <div class="object-editor">
        <header>
          <strong>{object.titel || SHAPE_TITEL[object.typ]}</strong>
          <button class="quiet" onClick={() => (selectedObject.value = null)}>
            Schließen
          </button>
        </header>
        {object.notiz && <p>{object.notiz}</p>}
        <p class="hint">Gehört zu den dauerhaften Orten und ist gesperrt. Entsperren unter Lage, Dauerhafte Orte.</p>
      </div>
    );
  }

  return (
    <div class="object-editor">
      <header>
        <strong>{SHAPE_TITEL[object.typ]}</strong>
        <button class="quiet" onClick={() => (selectedObject.value = null)}>
          Schließen
        </button>
      </header>
      <Field label={object.typ === 'text' ? 'Text' : 'Bezeichnung'}>
        <TextInput value={object.titel} onInput={(titel) => change({ titel })} maxLength={80} />
      </Field>
      <Field label="Notiz">
        <TextInput value={object.notiz} onInput={(notiz) => change({ notiz })} rows={2} maxLength={1000} />
      </Field>
      <div class="swatches">
        {PALETTE.map((farbe) => (
          <button key={farbe} class={object.farbe.toUpperCase() === farbe ? 'active' : ''} style={{ background: farbe }} title={farbe} onClick={() => change({ farbe })} />
        ))}
      </div>
      {object.typ === 'fahndungsraum' && (
        <Field label="Seit (letzte bekannte Sichtung)">
          <input
            type="datetime-local"
            value={object.zeit ? toLocalInput(object.zeit) : ''}
            max={toLocalInput(Date.now())}
            onInput={(e) => {
              const ts = new Date(e.currentTarget.value).getTime();
              if (Number.isFinite(ts)) change({ zeit: Math.min(ts, Date.now()) });
            }}
          />
        </Field>
      )}
      {object.typ === 'marker' && (
        <Field label="Standort von Tracker">
          <select value={object.trackerId ?? ''} onChange={(e) => change({ trackerId: e.currentTarget.value || null })}>
            <option value="">Von Hand gesetzt</option>
            {Object.values(tables.tracker.value).map((t) => (
              <option key={t.id} value={t.id}>
                {t.data.name}
              </option>
            ))}
          </select>
        </Field>
      )}
      {(object.typ === 'kreis' || object.typ === 'haltestellen') && (
        <Field label="Radius in Metern">
          <input type="number" min={5} max={100000} value={object.radius ?? 150} onInput={(e) => change({ radius: Math.min(Math.max(Number(e.currentTarget.value) || 150, 5), 100000) })} />
        </Field>
      )}
      <Field label="Lebensdauer">
        <select
          value={object.ablauf ? 'gesetzt' : ''}
          onChange={(e) => {
            const value = e.currentTarget.value;
            if (value === '') change({ ablauf: null });
            else if (value !== 'gesetzt') change({ ablauf: Date.now() + Number(value) * 1000 });
          }}
        >
          <option value="">Unbegrenzt</option>
          {object.ablauf && <option value="gesetzt">Bis {dateTime(object.ablauf)}</option>}
          {LIFETIMES.map(([seconds, label]) => (
            <option key={seconds} value={String(seconds)}>
              {label}
            </option>
          ))}
        </select>
      </Field>
      {object.typ !== 'haltestelle' && object.typ !== 'fahndungsraum' && (
        <PhotoList value={object.anhaenge ?? []} onChange={(anhaenge) => change({ anhaenge })} />
      )}
      <Field label="Ebene">
        <select value={object.layerId} onChange={(e) => change({ layerId: e.currentTarget.value })}>
          {layers.value
            .filter((l) => l.data.art !== 'argus' && !isLocked(l.id))
            .map((l) => (
              <option key={l.id} value={l.id}>
                {l.data.name}
              </option>
            ))}
        </select>
      </Field>
      <div class="row">
        <button class="primary" disabled={!dirty} onClick={() => saveObject(id, object)}>
          Sichern
        </button>
        <button onClick={() => (tool.value = { kind: 'verschieben', id })}>Verschieben</button>
        <button
          class="danger"
          onClick={() => {
            deleteObject(id);
            selectedObject.value = null;
          }}
        >
          Löschen
        </button>
      </div>
      <small class="hint">
        Zuletzt geändert von {nameOf(props.updatedBy)}, {ago(props.updatedAt)}
      </small>
    </div>
  );
}

/** Zeitpunkt als Wert für ein datetime-local-Feld in lokaler Zeit. */
function toLocalInput(ts: number): string {
  const d = new Date(ts - new Date(ts).getTimezoneOffset() * 60_000);
  return d.toISOString().slice(0, 16);
}

/** Auswahl der Lebensdauer wie in der App. */
const LIFETIMES: [number, string][] = [
  [900, '15 Minuten'],
  [1800, '30 Minuten'],
  [3600, '1 Stunde'],
  [7200, '2 Stunden'],
  [14_400, '4 Stunden'],
  [28_800, '8 Stunden'],
  [43_200, '12 Stunden'],
  [86_400, '24 Stunden'],
  [259_200, '3 Tage'],
  [604_800, '7 Tage'],
];

/** Fotos und Dateien einer Markierung: anzeigen, hinzufügen, entfernen. */
function PhotoList(props: { value: Attachment[]; onChange: (value: Attachment[]) => void }) {
  return (
    <div class="field">
      <span>Fotos und Dateien</span>
      <div class="photo-list">
        {props.value.map((a) => (
          <div key={a.blobId} class="photo">
            {a.art === 'bild' ? (
              <a href={`/api/v1/blobs/${a.blobId}`} target="_blank" rel="noreferrer">
                <img src={`/api/v1/blobs/${a.blobId}`} alt={a.name} />
              </a>
            ) : (
              <a class="file" href={`/api/v1/blobs/${a.blobId}?name=${encodeURIComponent(a.name)}`}>
                {a.name || 'Datei'}
              </a>
            )}
            <button class="quiet" title="Entfernen" onClick={() => props.onChange(props.value.filter((x) => x.blobId !== a.blobId))}>
              ✕
            </button>
          </div>
        ))}
        <label class="button">
          Hinzufügen
          <input
            type="file"
            multiple
            hidden
            onChange={async (e) => {
              const files = [...(e.currentTarget.files ?? [])];
              const added: Attachment[] = [];
              for (const file of files) {
                const uploaded = await uploadFile(file);
                if (!uploaded) continue;
                const art = uploaded.mime.startsWith('image/') ? 'bild' : uploaded.mime.startsWith('audio/') ? 'audio' : 'datei';
                added.push({ blobId: uploaded.id, art, name: file.name.slice(0, 120), mime: uploaded.mime, groesse: uploaded.groesse, dauer: null, wellenform: null });
              }
              if (added.length) props.onChange([...props.value, ...added].slice(0, 100));
            }}
          />
        </label>
      </div>
    </div>
  );
}
