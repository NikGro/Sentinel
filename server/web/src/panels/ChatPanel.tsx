import { useSignal } from '@preact/signals';
import { useEffect, useRef } from 'preact/hooks';
import { messages, nameOf, newId, put } from '../store';
import { time } from '../ui';

/** Einsatz-Chat mit allen Kräften. */
export function ChatPanel() {
  const draft = useSignal('');
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => end.current?.scrollIntoView({ block: 'end' }), [messages.value.length]);

  const send = (event: Event) => {
    event.preventDefault();
    const text = draft.value.trim();
    if (text && put('message', newId(), { text })) draft.value = '';
  };

  return (
    <div class="chat">
      <div class="chat-log">
        {messages.value.length === 0 && <p class="hint">Noch keine Nachrichten. Der Chat wird beim Zurücksetzen der Lage geleert.</p>}
        {messages.value.map((m) => (
          <div key={m.id} class={`bubble ${m.updatedBy === 'zentrale' ? 'mine' : ''}`}>
            <small>
              {nameOf(m.updatedBy)} · {time(m.updatedAt)}
            </small>
            <div>{m.data.text}</div>
          </div>
        ))}
        <div ref={end} />
      </div>
      <form class="row" onSubmit={send}>
        <input placeholder="Nachricht an alle" maxLength={1000} value={draft.value} onInput={(e) => (draft.value = e.currentTarget.value)} />
        <button class="primary" disabled={!draft.value.trim()}>
          Senden
        </button>
      </form>
    </div>
  );
}
