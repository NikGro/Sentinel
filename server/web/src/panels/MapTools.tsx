import { useSignal } from '@preact/signals';
import { finishDrawing } from '../map';
import { canRedo, canUndo, deleteObject, isLocked, layers, nameOf, newId, put, redo, saveObject, selectedObject, tables, targetLayer, tool, undo } from '../store';
import { PALETTE, SHAPE_TITEL, ZIEL_TITEL, type MapObject, type Shape, type Target, type ZielArt } from '../types';
import { ago, Field, TextInput } from '../ui';

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
  const multi = drawing && (drawing.shape === 'linie' || drawing.shape === 'flaeche');
  const hint = drawing ? (multi ? `${SHAPE_TITEL[drawing.shape]}: Punkte anklicken, Doppelklick beendet (${drawing.punkte.length} gesetzt)` : `${SHAPE_TITEL[drawing.shape]}: Ort anklicken`) : HINWEIS[current.kind];

  return (
    <div class="toolbar">
      <div class="toolbar-row">
        {(Object.keys(SHAPE_TITEL) as Shape[]).map((shape) => (
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
