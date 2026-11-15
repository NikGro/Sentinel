import { useSignal } from '@preact/signals';
import { useEffect, useRef } from 'preact/hooks';
import { createMap } from './map';
import { MapToolbar, ObjectEditor } from './panels/MapTools';
import { ChatPanel } from './panels/ChatPanel';
import { LagePanel } from './panels/LagePanel';
import { LayersPanel } from './panels/LayersPanel';
import { SystemPanel } from './panels/SystemPanel';
import { TargetsPanel } from './panels/TargetsPanel';
import { TeamPanel } from './panels/TeamPanel';
import { TrackersPanel } from './panels/TrackersPanel';
import { api, attempt, authed, connect, connected, disconnect, loadReach, notice, online, operation, reachModes, refreshStatus, tables } from './store';
import { MODUS_TITEL } from './types';

const TABS = [
  { id: 'lage', title: 'Lage', panel: LagePanel },
  { id: 'ziele', title: 'Ziele', panel: TargetsPanel },
  { id: 'kraefte', title: 'Kräfte', panel: TeamPanel },
  { id: 'ebenen', title: 'Ebenen', panel: LayersPanel },
  { id: 'tracker', title: 'Tracker', panel: TrackersPanel },
  { id: 'chat', title: 'Chat', panel: ChatPanel },
  { id: 'system', title: 'System', panel: SystemPanel },
] as const;

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
    <form class="login" onSubmit={submit}>
      <img src="/icon.svg" alt="" width="72" height="72" />
      <h1>SENTINEL</h1>
      <p>Kommandozentrale</p>
      <input type="password" autocomplete="current-password" placeholder="Verwaltungspasswort" value={password.value} onInput={(e) => (password.value = e.currentTarget.value)} autofocus />
      {error.value && <div class="error">{error.value}</div>}
      <button class="primary" disabled={busy.value || !password.value}>
        Anmelden
      </button>
    </form>
  );
}

function Console() {
  const tab = useSignal<(typeof TABS)[number]['id']>('lage');
  const mapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    connect();
    const dispose = createMap(mapRef.current!);
    const statusTimer = window.setInterval(() => void refreshStatus(), 30_000);
    return () => {
      window.clearInterval(statusTimer);
      dispose();
      disconnect();
    };
  }, []);

  // Weg-Zeit-Flächen aktuell halten: sofort bei Änderungen, danach im Minutentakt.
  const lkp = operation.value.lkp;
  const reachKey = `${operation.value.modus}:${lkp?.lat}:${lkp?.lon}:${lkp?.ts}:${JSON.stringify(reachModes.value)}`;
  useEffect(() => {
    void loadReach();
    const timer = window.setInterval(() => void loadReach(), 45_000);
    return () => window.clearInterval(timer);
  }, [reachKey]);

  const Panel = TABS.find((t) => t.id === tab.value)!.panel;
  const op = operation.value;
  const onlineCount = Object.keys(tables.member.value).filter((id) => online.value.has(id)).length;
  const aHolder = op.a ? tables.member.value[op.a.memberId]?.data.funkrufname : null;

  return (
    <div class="console">
      <aside class="sidebar">
        <header class="brand">
          <img src="/icon.svg" alt="" width="28" height="28" />
          <strong>SENTINEL</strong>
          <span class={`status ${connected.value ? 'ok' : 'down'}`}>{connected.value ? 'Verbunden' : 'Getrennt'}</span>
          <button
            class="quiet"
            title="Abmelden"
            onClick={() =>
              attempt(async () => {
                await api('/admin/logout', { method: 'POST' });
                authed.value = false;
              })
            }
          >
            Abmelden
          </button>
        </header>

        <div class={`situation modus-${op.modus}`}>
          <div>
            <small>Modus</small>
            <b>{MODUS_TITEL[op.modus]}</b>
          </div>
          <div>
            <small>Funkkanal</small>
            <b class="mono">{op.funkkanal ?? '–'}</b>
          </div>
          {op.modus === 'observation' && (
            <div>
              <small>A-Position</small>
              <b>{aHolder ?? 'frei'}</b>
            </div>
          )}
          <div>
            <small>Kräfte</small>
            <b class="mono">{onlineCount}</b>
          </div>
        </div>

        <nav class="tabs">
          {TABS.map((t) => (
            <button key={t.id} class={tab.value === t.id ? 'active' : ''} onClick={() => (tab.value = t.id)}>
              {t.title}
            </button>
          ))}
        </nav>

        <div class="panel">
          <Panel />
        </div>
      </aside>

      <main class="map-area">
        <div ref={mapRef} class="map" />
        <MapToolbar />
        <ObjectEditor />
        {notice.value && (
          <div class="notice" role="status" onClick={() => (notice.value = null)}>
            {notice.value}
          </div>
        )}
      </main>
    </div>
  );
}
