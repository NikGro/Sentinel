import { useSignal } from '@preact/signals';
import { useEffect, useRef } from 'preact/hooks';
import { activeRoom, del, messages, nameOf, newId, put, tables, uploadFile } from '../store';
import type { Attachment } from '../types';
import { time } from '../ui';

const kind = (mime: string): Attachment['art'] => (mime.startsWith('image/') ? 'bild' : mime.startsWith('audio/') ? 'audio' : 'datei');
const size = (bytes: number) => (bytes > 1_048_576 ? `${(bytes / 1_048_576).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`);

/** Einsatz-Chat in mehreren Räumen. Jeder kann Räume anlegen, betreten und löschen. */
export function ChatPanel() {
  const draft = useSignal('');
  const busy = useSignal(false);
  const end = useRef<HTMLDivElement>(null);
  const rooms = Object.values(tables.room.value).sort((a, b) => (a.id === 'allgemein' ? -1 : b.id === 'allgemein' ? 1 : a.data.name.localeCompare(b.data.name, 'de')));
  const room = tables.room.value[activeRoom.value] ? activeRoom.value : 'allgemein';
  const list = messages.value.filter((m) => m.data.roomId === room);
  useEffect(() => end.current?.scrollIntoView({ block: 'end' }), [list.length, room]);

  const send = (event: Event) => {
    event.preventDefault();
    const text = draft.value.trim();
    if (text && put('message', newId(), { roomId: room, text, anhang: null })) draft.value = '';
  };

  const attach = async (file: File) => {
    busy.value = true;
    const blob = await uploadFile(file);
    busy.value = false;
    if (!blob) return;
    const anhang: Attachment = { blobId: blob.id, art: kind(blob.mime), name: file.name.slice(0, 120), mime: blob.mime, groesse: blob.groesse, dauer: null };
    put('message', newId(), { roomId: room, text: draft.value.trim().slice(0, 1000), anhang });
    draft.value = '';
  };

  return (
    <div class="chat">
      <div class="row rooms">
        <select value={room} onChange={(e) => (activeRoom.value = e.currentTarget.value)} aria-label="Chatraum">
          {rooms.map((r) => (
            <option key={r.id} value={r.id}>
              {r.data.name}
            </option>
          ))}
        </select>
        <button
          onClick={() => {
            const name = prompt('Name des neuen Chatraums')?.trim();
            if (!name) return;
            const id = newId();
            if (put('room', id, { name: name.slice(0, 40) })) activeRoom.value = id;
          }}
        >
          Neuer Raum
        </button>
        {room !== 'allgemein' && (
          <button
            class="danger"
            onClick={() => {
              if (confirm(`Chatraum „${tables.room.value[room]?.data.name}“ samt Nachrichten für alle löschen?`) && del('room', room)) activeRoom.value = 'allgemein';
            }}
          >
            Raum löschen
          </button>
        )}
      </div>
      <div class="chat-log">
        {list.length === 0 && <p class="hint">Noch keine Nachrichten in diesem Raum. Nachrichten werden beim Zurücksetzen der Lage geleert.</p>}
        {list.map((m) => (
          <div key={m.id} class={`bubble ${m.updatedBy === 'zentrale' ? 'mine' : ''}`}>
            <small>
              {nameOf(m.updatedBy)}, {time(m.updatedAt)}
            </small>
            {m.data.anhang && <AttachmentView anhang={m.data.anhang} />}
            {m.data.text && <div>{m.data.text}</div>}
          </div>
        ))}
        <div ref={end} />
      </div>
      <form class="row" onSubmit={send}>
        <label class="button" title="Foto oder Datei anhängen">
          {busy.value ? 'Lädt …' : 'Anhang'}
          <input
            type="file"
            hidden
            disabled={busy.value}
            onChange={(e) => {
              const file = e.currentTarget.files?.[0];
              if (file) void attach(file);
              e.currentTarget.value = '';
            }}
          />
        </label>
        <input placeholder="Nachricht" maxLength={1000} value={draft.value} onInput={(e) => (draft.value = e.currentTarget.value)} />
        <button class="primary" disabled={!draft.value.trim()}>
          Senden
        </button>
      </form>
    </div>
  );
}

function AttachmentView({ anhang }: { anhang: Attachment }) {
  const url = `/api/v1/blobs/${anhang.blobId}?name=${encodeURIComponent(anhang.name || 'datei')}`;
  if (anhang.art === 'bild' && (anhang.mime === 'image/jpeg' || anhang.mime === 'image/png')) {
    return (
      <a href={url} target="_blank" rel="noopener">
        <img class="chat-image" src={url} alt={anhang.name || 'Bild'} />
      </a>
    );
  }
  if (anhang.art === 'audio') {
    return (
      <div class="chat-audio">
        <span>Sprachnachricht{anhang.dauer ? `, ${Math.round(anhang.dauer)} s` : ''}</span>
        <audio controls preload="none" src={url} />
      </div>
    );
  }
  return (
    <a class="chat-file" href={url} download={anhang.name || 'datei'}>
      {anhang.name || 'Datei'} ({size(anhang.groesse)})
    </a>
  );
}
