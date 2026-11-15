import { useSignal } from '@preact/signals';
import { useEffect, useRef } from 'preact/hooks';
import { createMap, mapProvider } from './map';
import { ChatPanel } from './panels/ChatPanel';
import { LagePanel } from './panels/LagePanel';
import { LayersPanel } from './panels/LayersPanel';
import { MapToolbar, ObjectEditor } from './panels/MapTools';
import { SystemPanel } from './panels/SystemPanel';
import { TargetsPanel } from './panels/TargetsPanel';
import { TeamPanel } from './panels/TeamPanel';
import { TrackersPanel } from './panels/TrackersPanel';
import { adminStatus, api, attempt, authed, command, connect, connected, disconnect, focusRequest, loadReach, messages, notice, online, operation, positions, reachModes, refreshStatus, tables } from './store';
import { MODUS_TITEL, type Modus } from './types';
import { ago } from './ui';

const SECTIONS = [
  { id: 'lage', title: 'Lage', panel: LagePanel },
  { id: 'ziele', title: 'Ziele', panel: TargetsPanel },
  { id: 'kraefte', title: 'Kräfte', panel: TeamPanel },
  { id: 'ebenen', title: 'Ebenen', panel: LayersPanel },
  { id: 'tracker', title: 'Tracker', panel: TrackersPanel },
  { id: 'chat', title: 'Chat', panel: ChatPanel },
  { id: 'system', title: 'System', panel: SystemPanel },
] as const;
type SectionId = (typeof SECTIONS)[number]['id'];

const MODUS_HINWEIS: Record<Modus, string> = {
  observation: 'A-Position, Navigation zur A, Zielperson im Blick',
  fahndung: 'Bestreifung, letzter Standort, Weg-Zeit-Berechnung',
  oberflaeche: 'Nur Kräfte und Markierungen',
};

export function App() {
  useEffect(() => void refreshStatus(), []);
  if (authed.value === null) return <div class="splash">SENTINEL</div>;
  return authed.value ? <Console /> : <Login />;
}

function Login() {
  const password = useSignal('');
  const busy = useSignal(false);
  const error = useSignal('');
  const submit = async (event: Event) => {
    event.preventDefault();
    busy.value = true;
    error.value = '';
    try {
      await api('/admin/login', { method: 'POST', body: { passwort: password.value } });
      await refreshStatus();
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Anmeldung fehlgeschlagen';
    }
    busy.value = false;
  };
  return (
    <main class="login">
      <form onSubmit={submit}>
        <img src="/icon.svg" alt="" width="64" height="64" />
        <h1>SENTINEL</h1>
        <p>Kommandozentrale</p>
        <label class="field">
          <span>Verwaltungspasswort</span>
          <input type="password" autocomplete="current-password" value={password.value} onInput={(e) => (password.value = e.currentTarget.value)} autofocus />
        </label>
        {error.value && (
          <div class="error" role="alert">
            {error.value}
          </div>
        )}
        <button class="primary" disabled={busy.value || !password.value}>
          Anmelden
        </button>
      </form>
    </main>
  );
}

function Console() {
  // `null` = Arbeitsbereich eingeklappt, die Karte bekommt den Platz.
  const section = useSignal<SectionId | null>('lage');
  const chatSeen = useSignal(Date.now());
  const mapRef = useRef<HTMLDivElement>(null);
  const provider = adminStatus.value?.karte ?? 'osm';

  useEffect(() => {
    connect();
    const statusTimer = window.setInterval(() => void refreshStatus(), 30_000);
    return () => {
      window.clearInterval(statusTimer);
      disconnect();
    };
  }, []);

  useEffect(() => createMap(mapRef.current!, provider), [provider]);

  // Weg-Zeit-Flächen aktuell halten: sofort bei Änderungen, danach regelmäßig.
  const lkp = operation.value.lkp;
  const reachKey = `${operation.value.modus}:${lkp?.lat}:${lkp?.lon}:${lkp?.ts}:${JSON.stringify(reachModes.value)}`;
  useEffect(() => {
    void loadReach();
    const timer = window.setInterval(() => void loadReach(), 45_000);
    return () => window.clearInterval(timer);
  }, [reachKey]);

  useEffect(() => {
    if (section.value === 'chat') chatSeen.value = Date.now();
  }, [section.value, messages.value.length]);

  const unread = section.value === 'chat' ? 0 : messages.value.filter((m) => m.updatedAt > chatSeen.value && m.updatedBy !== 'zentrale').length;
  const active = SECTIONS.find((s) => s.id === section.value);
  const Panel = active?.panel;

  return (
    <div class={`console modus-${operation.value.modus} ${active ? '' : 'eingeklappt'}`}>
      <SituationBand />

      <nav class="rail" aria-label="Bereiche">
        {SECTIONS.map((s) => (
          <button key={s.id} class={section.value === s.id ? 'active' : ''} aria-pressed={section.value === s.id} onClick={() => (section.value = section.value === s.id ? null : s.id)}>
            {s.title}
            {s.id === 'chat' && unread > 0 && <span class="count">{unread}</span>}
          </button>
        ))}
      </nav>

      {Panel && (
        <aside class="panel" aria-label={active.title}>
          <Panel />
        </aside>
      )}

      <main class="map-area">
        <div ref={mapRef} class="map" />
        <ObjectEditor />
        <MapToolbar />
        {mapProvider.value === 'osm' && provider === 'apple' && <div class="map-note">Apple Maps nicht erreichbar, Anzeige über OpenStreetMap</div>}
        {notice.value && (
          <div class="notice" role="status">
            <span>{notice.value}</span>
            <button class="quiet" onClick={() => (notice.value = null)}>
              Schließen
            </button>
          </div>
        )}
      </main>

      <Roster />
    </div>
  );
}

/** Lageband: Modus, Funkkanal, A-Position und Kräfte, in jeder Ansicht sichtbar und in der Modusfarbe hinterlegt. */
function SituationBand() {
  const op = operation.value;
  const clock = useSignal(new Date());
  useEffect(() => {
    const timer = window.setInterval(() => (clock.value = new Date()), 10_000);
    return () => window.clearInterval(timer);
  }, []);
  const onlineCount = Object.keys(tables.member.value).filter((id) => online.value.has(id)).length;
  const aHolder = op.a ? tables.member.value[op.a.memberId]?.data.funkrufname : null;

  return (
    <header class="band">
      <div class="brand">
        <img src="/icon.svg" alt="" width="26" height="26" />
        <strong>SENTINEL</strong>
      </div>

      <div class="modes" role="group" aria-label="Modus">
        {(Object.keys(MODUS_TITEL) as Modus[]).map((modus) => (
          <button
            key={modus}
            class={op.modus === modus ? 'active' : ''}
            aria-pressed={op.modus === modus}
            title={MODUS_HINWEIS[modus]}
            onClick={() => {
              if (op.modus !== modus && confirm(`Modus für alle auf „${MODUS_TITEL[modus]}“ ändern?\n\n${MODUS_HINWEIS[modus]}`)) command('modus.setzen', { modus });
            }}
          >
            {MODUS_TITEL[modus]}
          </button>
        ))}
      </div>

      <dl class="facts">
        <div>
          <dt>Funkkanal</dt>
          <dd class="mono">{op.funkkanal ?? 'nicht gesetzt'}</dd>
        </div>
        {op.modus === 'observation' && (
          <div>
            <dt>A-Position</dt>
            <dd>{aHolder ?? 'frei'}</dd>
          </div>
        )}
        {op.modus === 'fahndung' && (
          <div>
            <dt>Letzter Standort</dt>
            <dd>{op.lkp ? ago(op.lkp.ts) : 'nicht gesetzt'}</dd>
          </div>
        )}
        <div>
          <dt>Kräfte verbunden</dt>
          <dd class="mono">{onlineCount}</dd>
        </div>
      </dl>

      <div class="band-end">
        {!connected.value && <span class="offline">Keine Verbindung zum Server</span>}
        <time>{clock.value.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}</time>
        <button
          class="quiet"
          onClick={() =>
            attempt(async () => {
              await api('/admin/logout', { method: 'POST' });
              authed.value = false;
            })
          }
        >
          Abmelden
        </button>
      </div>
    </header>
  );
}

/** Kräfteliste am rechten Rand: wer ist verbunden, wer hält die A, wie alt ist die Position. Ein Klick zeigt die Kraft auf der Karte. */
function Roster() {
  const members = Object.values(tables.member.value).sort((a, b) => a.data.funkrufname.localeCompare(b.data.funkrufname, 'de', { numeric: true }));
  const a = operation.value.modus === 'observation' ? operation.value.a?.memberId : undefined;
  return (
    <aside class="roster" aria-label="Kräfte">
      <h2>Kräfte</h2>
      {members.length === 0 && <p class="hint">Noch niemand angemeldet. Den Zugangscode finden Sie unter System.</p>}
      <ul>
        {members.map((m) => {
          const position = positions.value[m.id];
          const isOnline = online.value.has(m.id);
          return (
            <li key={m.id}>
              <button disabled={!position} onClick={() => position && (focusRequest.value = { ...position, at: Date.now() })} title={position ? 'Auf der Karte zeigen' : 'Keine Position bekannt'}>
                <span class={`presence ${isOnline ? 'on' : ''}`} aria-label={isOnline ? 'verbunden' : 'nicht verbunden'} />
                <span class="who">
                  <b>{m.data.funkrufname}</b>
                  <small>{position ? ago(position.ts) : 'keine Position'}</small>
                </span>
                {a === m.id && <span class="badge-a">A</span>}
              </button>
            </li>
          );
        })}
      </ul>
    </aside>
  );
}
