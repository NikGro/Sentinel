import { useSignal } from '@preact/signals';
import { useEffect, useRef } from 'preact/hooks';
import { Field, Section, TextInput } from '../ui';

/**
 * SinoTrack per USB einrichten (Chrome/Edge, Web Serial): Der Browser fragt nach dem Zugriff auf das angesteckte
 * Gerät; danach gehen die Einstellbefehle direkt an den Tracker statt per SMS. Die Befehle folgen der
 * SinoTrack-Syntax (Kennziffer, Geräte-PIN, Wert); was das Gerät antwortet, steht im Protokoll darunter.
 */

interface SerialPortLike {
  open(options: { baudRate: number }): Promise<void>;
  close(): Promise<void>;
  readable: ReadableStream<Uint8Array> | null;
  writable: WritableStream<Uint8Array> | null;
}

interface SerialLike {
  requestPort(): Promise<SerialPortLike>;
}

const serial = (): SerialLike | null => ((navigator as unknown as { serial?: SerialLike }).serial ?? null);

export function UsbSetup({ host, port }: { host: string; port: number }) {
  const connected = useSignal(false);
  const busy = useSignal(false);
  const baud = useSignal(115200);
  const pin = useSignal('0000');
  const apn = useSignal('');
  const interval = useSignal(20);
  const custom = useSignal('');
  const log = useSignal<{ dir: 'aus' | 'ein' | 'info'; text: string }[]>([]);
  const portRef = useRef<SerialPortLike | null>(null);
  const writerRef = useRef<WritableStreamDefaultWriter<Uint8Array> | null>(null);
  const readerRef = useRef<ReadableStreamDefaultReader<Uint8Array> | null>(null);

  const append = (dir: 'aus' | 'ein' | 'info', text: string) => (log.value = [...log.value.slice(-200), { dir, text }]);

  const disconnect = async () => {
    try {
      await readerRef.current?.cancel();
      readerRef.current?.releaseLock();
      writerRef.current?.releaseLock();
      await portRef.current?.close();
    } catch {
      // Schon getrennt.
    }
    portRef.current = null;
    readerRef.current = null;
    writerRef.current = null;
    connected.value = false;
  };

  useEffect(() => () => void disconnect(), []);

  const connect = async () => {
    const api = serial();
    if (!api) {
      append('info', 'Dieser Browser kann nicht auf USB-Geräte zugreifen. Bitte Chrome oder Edge am PC verwenden.');
      return;
    }
    try {
      const port = await api.requestPort();
      await port.open({ baudRate: baud.value });
      portRef.current = port;
      writerRef.current = port.writable!.getWriter();
      connected.value = true;
      append('info', `Verbunden (${baud.value} Baud).`);
      void readLoop(port);
    } catch (error) {
      append('info', error instanceof Error ? error.message : 'Verbindung fehlgeschlagen');
    }
  };

  const readLoop = async (port: SerialPortLike) => {
    const decoder = new TextDecoder();
    let buffer = '';
    while (port.readable && portRef.current === port) {
      const reader = port.readable.getReader();
      readerRef.current = reader;
      try {
        for (;;) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split(/\r?\n/);
          buffer = lines.pop() ?? '';
          for (const line of lines) if (line.trim()) append('ein', line.trim());
        }
      } catch {
        break;
      } finally {
        reader.releaseLock();
      }
    }
  };

  const send = async (text: string) => {
    if (!writerRef.current) return;
    append('aus', text);
    await writerRef.current.write(new TextEncoder().encode(`${text}\r\n`));
  };

  /** Mehrere Befehle nacheinander, mit Pause, damit das Gerät jeden einzeln quittieren kann. */
  const sendAll = async (commands: string[]) => {
    busy.value = true;
    try {
      for (const text of commands) {
        await send(text);
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }
    } finally {
      busy.value = false;
    }
  };

  const setupCommands = () => {
    const p = pin.value.trim() || '0000';
    const list = [`804${p} ${host} ${port}`, `710${p}`, `805${p} ${Math.max(10, Math.round(interval.value))}`];
    if (apn.value.trim()) list.splice(1, 0, `803${p} ${apn.value.trim()}`);
    return list;
  };

  return (
    <Section title="SinoTrack per USB einrichten" hint="Tracker per USB-Kabel an diesen PC anschließen. Funktioniert in Chrome und Edge.">
      {!connected.value ? (
        <>
          <Field label="Geschwindigkeit">
            <select value={baud.value} onChange={(e) => (baud.value = Number(e.currentTarget.value))}>
              {[9600, 19200, 38400, 57600, 115200].map((b) => (
                <option key={b} value={b}>
                  {b} Baud
                </option>
              ))}
            </select>
          </Field>
          <button class="primary" onClick={() => void connect()}>
            Tracker verbinden
          </button>
        </>
      ) : (
        <>
          <Field label="APN der SIM-Karte">
            <TextInput value={apn.value} onInput={(v) => (apn.value = v)} placeholder="APN der Beach SIM" maxLength={60} />
          </Field>
          <Field label="Sendeintervall (Sekunden)">
            <TextInput value={String(interval.value)} onInput={(v) => (interval.value = Number(v) || 20)} maxLength={4} />
          </Field>
          <Field label="Geräte-PIN">
            <TextInput value={pin.value} onInput={(v) => (pin.value = v)} maxLength={8} />
          </Field>
          <p class="hint">
            Schickt: Server {host}, Port {port}
            {apn.value.trim() ? `, APN ${apn.value.trim()}` : ''}, Datenverbindung an, Intervall {interval.value} s.
          </p>
          <div class="row">
            <button class="primary" disabled={busy.value} onClick={() => void sendAll(setupCommands())}>
              Auf Sentinel einrichten
            </button>
            <button disabled={busy.value} onClick={() => void send('RCONF')}>
              Einstellungen abfragen
            </button>
            <button class="quiet" onClick={() => void disconnect()}>
              Trennen
            </button>
          </div>
          <Field label="Eigener Befehl">
            <TextInput value={custom.value} onInput={(v) => (custom.value = v)} placeholder="z. B. RCONF" maxLength={160} />
          </Field>
          <button disabled={busy.value || !custom.value.trim()} onClick={() => void send(custom.value.trim())}>
            Senden
          </button>
        </>
      )}
      {log.value.length > 0 && (
        <pre class="mono usb-log">
          {log.value.map((entry, i) => (
            <div key={i} class={`usb-${entry.dir}`}>
              {entry.dir === 'aus' ? '→ ' : entry.dir === 'ein' ? '← ' : '· '}
              {entry.text}
            </div>
          ))}
        </pre>
      )}
    </Section>
  );
}
