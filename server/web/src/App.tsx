import { useSignal } from '@preact/signals';
import { useEffect, useRef } from 'preact/hooks';
import { createMap, dreiD, grundkarte, hiddenTargetGroups, hiddenTargetKinds, trafficVisible } from './map';
import { ChatPanel } from './panels/ChatPanel';
import { InstancesPanel } from './panels/InstancesPanel';
import { LagePanel } from './panels/LagePanel';
import { LayersPanel } from './panels/LayersPanel';
import { MapToolbar, ObjectEditor } from './panels/MapTools';
import { SystemPanel } from './panels/SystemPanel';
import { TargetsPanel } from './panels/TargetsPanel';
import { TeamPanel } from './panels/TeamPanel';
import { TrackersPanel } from './panels/TrackersPanel';
import { api, attempt, authed, command, connect, connected, disconnect, focusRequest, hiddenLayers, loadCoverage, loadReach, memberLabel, messages, notice, online, operation, positions, reachModes, refreshStatus, membersHere, showCoverage, tables, instanz, currentInstance } from './store';
import { FORTBEWEGUNG_TITEL } from './types';
import { ago } from './ui';

/** Chat vorerst ausgeblendet; auf `true` setzen, um ihn wieder anzuzeigen. */
const CHAT_SICHTBAR = false;

const SECTIONS = [
  { id: 'instanzen', title: 'Instanzen', panel: InstancesPanel },
  { id: 'lage', title: 'Lage', panel: LagePanel },
  { id: 'ziele', title: 'Ziele', panel: TargetsPanel },
  { id: 'kraefte', title: 'Kräfte', panel: TeamPanel },
  { id: 'ebenen', title: 'Ebenen', panel: LayersPanel },
  { id: 'tracker', title: 'Tracker', panel: TrackersPanel },
  // Chat vorerst ausgeblendet (Code bleibt, siehe CHAT_SICHTBAR).
  ...(CHAT_SICHTBAR ? [{ id: 'chat', title: 'Chat', panel: ChatPanel } as const] : []),
  { id: 'system', title: 'System', panel: SystemPanel },
] as const;
type SectionId = (typeof SECTIONS)[number]['id'];

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
        <p>Web</p>
        <label class="field">
          <span>Zugangscode</span>
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

  useEffect(() => {
    connect();
    const statusTimer = window.setInterval(() => void refreshStatus(), 30_000);
    return () => {
      window.clearInterval(statusTimer);
      disconnect();
    };
  }, []);

  useEffect(() => createMap(mapRef.current!), []);

  // Weg-Zeit-Flächen aktuell halten: sofort bei Änderungen, danach regelmäßig.
  const rooms = Object.values(tables.annotation.value).filter((a) => a.data.typ === 'fahndungsraum');
  const reachKey = `${rooms.map((r) => `${r.id}:${r.rev}`).join(',')}:${JSON.stringify(reachModes.value)}:${[...hiddenLayers.value].join(',')}`;
  useEffect(() => {
    void loadReach();
    const timer = window.setInterval(() => void loadReach(), 45_000);
    return () => window.clearInterval(timer);
  }, [reachKey]);

  // Bestreifung regelmäßig nachladen, solange sie angezeigt wird.
  useEffect(() => {
    void loadCoverage();
    if (!showCoverage.value) return;
    const timer = window.setInterval(() => void loadCoverage(), 30_000);
    return () => window.clearInterval(timer);
  }, [showCoverage.value, instanz.value]);

  useEffect(() => {
    if (section.value === 'chat') chatSeen.value = Date.now();
  }, [section.value, messages.value.length]);

  const unread = section.value === 'chat' ? 0 : messages.value.filter((m) => m.updatedAt > chatSeen.value && m.updatedBy !== 'zentrale').length;
  const active = SECTIONS.find((s) => s.id === section.value);
  const Panel = active?.panel;

  return (
    <div class={`console ${active ? '' : 'eingeklappt'}`}>
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
        <MapLayers />
        <ObjectEditor />
        <MapToolbar />
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

/** Lageband: Funkkanal, A-Position und Kräfte, in jeder Ansicht sichtbar. */
function SituationBand() {
  const op = operation.value;
  const clock = useSignal(new Date());
  useEffect(() => {
    const timer = window.setInterval(() => (clock.value = new Date()), 10_000);
    return () => window.clearInterval(timer);
  }, []);
  const activeMembers = membersHere.value.filter((m) => m.data.aktiv && online.value.has(m.id)).length;
  const aHolder = op.a ? tables.member.value[op.a.memberId] : null;
  const aLine = aHolder?.data.fortbewegung === 'oepnv' ? aHolder.data.oepnv : null;

  const sosMember = op.sos ? tables.member.value[op.sos.memberId] : null;
  const sosPosition = op.sos ? positions.value[op.sos.memberId] : null;

  return (
    <>
    {op.sos && (
      <div class="sos-band" role="alert">
        <strong>SOS</strong>
        <span>
          Notruf von {sosMember?.data.spitzname ?? 'unbekannt'} seit{' '}
          {new Date(op.sos.seit).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })} Uhr. Alle Kräfte werden mit Sonderrechten hingeführt.
        </span>
        {sosPosition && (
          <button class="quiet" onClick={() => (focusRequest.value = { ...sosPosition, at: Date.now() })}>
            Auf der Karte zeigen
          </button>
        )}
        <button class="danger" onClick={() => command('sos.beenden')}>
          Notruf beenden
        </button>
      </div>
    )}
    <header class={`band ${aHolder ? 'mit-a' : ''}`}>
      <div class="brand">
        <img src="/icon.svg" alt="" width="26" height="26" />
        <strong>SENTINEL</strong>
      </div>

      <dl class="facts">
        <div>
          <dt>{currentInstance.value?.data.art === 'paket' ? 'Paket' : 'Instanz'}</dt>
          <dd>{currentInstance.value?.data.name ?? 'KSOD'}</dd>
        </div>
        <div>
          <dt>Funkkanal</dt>
          <dd class="mono">{op.funkkanal ?? 'nicht gesetzt'}</dd>
        </div>
        <div class="a-fact">
          <dt>A-Position</dt>
          <dd>
            {aHolder ? memberLabel(aHolder.data) : 'frei'}
            {aLine && <span class="sub">, {aLine.linie} Richtung {aLine.richtung}</span>}
          </dd>
        </div>
        {op.ueberschlagen.naechste.length > 0 && (
          <div>
            <dt>Nächster Halt der A</dt>
            <dd>{op.ueberschlagen.naechste[0]!.name}</dd>
          </div>
        )}
        <div>
          <dt>Kräfte verbunden</dt>
          <dd class="mono">{activeMembers}</dd>
        </div>
      </dl>

      <div class="band-end">
        {!connected.value && <span class="offline">Keine Verbindung zum Server</span>}
        {op.a && (
          <button class="quiet" onClick={() => command('a.freigeben')} title="A-Position für alle freigeben">
            A freigeben
          </button>
        )}
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
    </>
  );
}

/** Kräfteliste am rechten Rand: wer ist verbunden, wie unterwegs, wer hält die A. Ein Klick zeigt die Kraft auf der Karte. */
function Roster() {
  const members = [...membersHere.value].sort((a, b) => Number(b.data.aktiv) - Number(a.data.aktiv) || a.data.spitzname.localeCompare(b.data.spitzname, 'de', { numeric: true }));
  const a = operation.value.a?.memberId;
  return (
    <aside class="roster" aria-label="Kräfte">
      <h2>Kräfte</h2>
      {members.length === 0 && <p class="hint">Noch niemand angemeldet. Den Zugangscode finden Sie unter System.</p>}
      <ul>
        {members.map((m) => {
          const position = positions.value[m.id];
          const isOnline = online.value.has(m.id) && m.data.aktiv;
          return (
            <li key={m.id} class={m.data.aktiv ? '' : 'ruhend'}>
              <button disabled={!position} onClick={() => position && (focusRequest.value = { ...position, at: Date.now() })} title={position ? 'Auf der Karte zeigen' : 'Keine Position bekannt'}>
                <span class={`presence ${isOnline ? 'on' : ''}`} aria-label={isOnline ? 'verbunden' : 'nicht verbunden'} />
                <span class="who">
                  <b>{m.data.spitzname}</b>
                  <small>{m.data.aktiv ? `${m.data.fortbewegung === 'fuss' ? FORTBEWEGUNG_TITEL.fuss : memberLabel(m.data)}, ${position ? ago(position.ts) : 'keine Position'}` : 'Ruhemodus'}</small>
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

const ZIELARTEN: [string, string][] = [['person', 'Personen'], ['fahrzeug', 'Fahrzeuge'], ['objekt', 'Objekte']];

const umschalten = (menge: Set<string>, wert: string): Set<string> => {
  const neu = new Set(menge);
  if (neu.has(wert)) neu.delete(wert);
  else neu.add(wert);
  return neu;
};

/** Kartenebenen wie in den Apps: Grundkarte, 3D, Verkehr, Zielarten und Zielgruppen ausblenden. */
function MapLayers() {
  const offen = useSignal(false);
  const veraendert = trafficVisible.value || grundkarte.value !== 'standard' || !dreiD.value || hiddenTargetKinds.value.size > 0 || hiddenTargetGroups.value.size > 0;
  const gruppen = Object.values(tables.targetGroup.value).sort((a, b) => a.data.name.localeCompare(b.data.name, 'de'));
  return (
    <div class="map-layers">
      <button class={`map-traffic${veraendert ? ' active' : ''}`} aria-expanded={offen.value} onClick={() => (offen.value = !offen.value)}>
        Karte
      </button>
      {offen.value && (
        <div class="map-layers-menu" role="group" aria-label="Kartenebenen">
          <div class="segmented" role="radiogroup" aria-label="Grundkarte">
            <button role="radio" aria-checked={grundkarte.value === 'standard'} class={grundkarte.value === 'standard' ? 'active' : ''} onClick={() => (grundkarte.value = 'standard')}>Karte</button>
            <button role="radio" aria-checked={grundkarte.value === 'satellit'} class={grundkarte.value === 'satellit' ? 'active' : ''} onClick={() => (grundkarte.value = 'satellit')}>Satellit</button>
          </div>
          <label><input type="checkbox" checked={dreiD.value} onChange={() => (dreiD.value = !dreiD.value)} /> Gebäude in 3D</label>
          <label><input type="checkbox" checked={trafficVisible.value} onChange={() => (trafficVisible.value = !trafficVisible.value)} /> Verkehr und Sperrungen</label>
          <p class="map-layers-title">Ziele auf der Karte</p>
          {ZIELARTEN.map(([art, titel]) => (
            <label key={art}><input type="checkbox" checked={!hiddenTargetKinds.value.has(art)} onChange={() => (hiddenTargetKinds.value = umschalten(hiddenTargetKinds.value, art))} /> {titel}</label>
          ))}
          {gruppen.map((g) => (
            <label key={g.id}><input type="checkbox" checked={!hiddenTargetGroups.value.has(g.id)} onChange={() => (hiddenTargetGroups.value = umschalten(hiddenTargetGroups.value, g.id))} /> {g.data.name}</label>
          ))}
        </div>
      )}
    </div>
  );
}
