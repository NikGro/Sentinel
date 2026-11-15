import type { ComponentChildren } from 'preact';
import { uploadImage } from './store';

/** Kleine, wiederverwendete Bausteine der Oberfläche. */

export function Section(props: { title: string; hint?: string; children: ComponentChildren; actions?: ComponentChildren }) {
  return (
    <section class="section">
      <header>
        <h2>{props.title}</h2>
        {props.actions}
      </header>
      {props.hint && <p class="hint">{props.hint}</p>}
      {props.children}
    </section>
  );
}

export function Field(props: { label: string; children: ComponentChildren }) {
  return (
    <label class="field">
      <span>{props.label}</span>
      {props.children}
    </label>
  );
}

export function TextInput(props: { value: string; onInput: (value: string) => void; placeholder?: string; rows?: number; maxLength?: number; type?: 'text' | 'number' | 'email' | 'password' }) {
  if (props.rows) {
    return <textarea rows={props.rows} value={props.value} placeholder={props.placeholder ?? ''} maxLength={props.maxLength ?? 4000} onInput={(e) => props.onInput(e.currentTarget.value)} />;
  }
  return <input type={(props.type ?? 'text') as 'text'} value={props.value} placeholder={props.placeholder ?? ''} maxLength={props.maxLength ?? 4000} onInput={(e) => props.onInput(e.currentTarget.value)} />;
}

export function ImageField(props: { label: string; blobId: string | null; onChange: (blobId: string | null) => void }) {
  return (
    <div class="field">
      <span>{props.label}</span>
      <div class="image-field">
        {props.blobId ? <img src={`/api/v1/blobs/${props.blobId}`} alt="" /> : <div class="image-empty">kein Bild</div>}
        <div class="row">
          <label class="button">
            Auswählen
            <input
              type="file"
              accept="image/jpeg,image/png"
              hidden
              onChange={async (e) => {
                const file = e.currentTarget.files?.[0];
                if (file) {
                  const id = await uploadImage(file);
                  if (id) props.onChange(id);
                }
              }}
            />
          </label>
          {props.blobId && (
            <button class="quiet" onClick={() => props.onChange(null)}>
              Entfernen
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

export const time = (ts: number) => new Date(ts).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
export const dateTime = (ts: number) => new Date(ts).toLocaleString('de-DE', { dateStyle: 'short', timeStyle: 'short' });

export function ago(ts: number): string {
  const seconds = (Date.now() - ts) / 1000;
  if (seconds < 20) return 'gerade eben';
  if (seconds < 3600) return `vor ${Math.max(1, Math.round(seconds / 60))} Min.`;
  if (seconds < 86400) return `vor ${Math.round(seconds / 3600)} Std.`;
  return dateTime(ts);
}

export function ageOf(geburtsdatum: string | null): number | null {
  if (!geburtsdatum) return null;
  const [y, m, d] = geburtsdatum.split('-').map(Number) as [number, number, number];
  const now = new Date();
  let age = now.getFullYear() - y;
  if (now.getMonth() + 1 < m || (now.getMonth() + 1 === m && now.getDate() < d)) age -= 1;
  return age;
}
