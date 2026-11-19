import { useSignal } from '@preact/signals';
import { adminStatus, api, attempt, command, del, focusRequest, newId, put, refreshStatus, tables, trackerPositions } from '../store';
import type { Tracker } from '../types';
import { ago, Field, Section, TextInput } from '../ui';

/** GPS-Tracker: eigene Geräte (SinoTrack/H02, ohne Hersteller-Server) und PAJ-Geräte über das PAJ-Portal. */
export function TrackersPanel() {
  const status = adminStatus.value;
  const name = useSignal('');
  const anbieter = useSignal<Tracker['anbieter']>('sinotrack');
  const kennung = useSignal('');
  const pajEmail = useSignal('');
  const pajPassword = useSignal('');
  const ownEmail = useSignal('');
  const ownPassword = useSignal('');
  const pajDevices = useSignal<{ kennung: string; name: string }[] | null>(null);
  const trackers = Object.values(tables.tracker.value).sort((a, b) => a.data.name.localeCompare(b.data.name));
  const host = location.hostname;

  const usage = (id: string) => {
    const target = Object.values(tables.target.value).find((t) => t.data.trackerId === id);
    if (target) return `Ziel ${[target.data.vorname, target.data.nachname, target.data.bezeichnung].filter(Boolean).join(' ')}`;
    const vehicle = Object.values(tables.vehicle.value).find((v) => v.data.trackerId === id);
    if (vehicle) return `Fahrzeug ${vehicle.data.funkrufname}`;
    const marker = Object.values(tables.annotation.value).find((a) => a.data.trackerId === id);
    return marker ? `Marker ${marker.data.titel || ''}`.trim() : 'nicht zugeordnet';
  };

  const add = (data: Omit<Tracker, 'intervall' | 'kontoEmail'>) => {
    if (put('tracker', newId(), { ...data, intervall: null })) {
      name.value = '';
      kennung.value = '';
      window.setTimeout(() => void refreshStatus(), 500);
    }
  };

  return (
    <>
      <Section title="Tracker" hint="Zugeordnet werden Tracker beim Ziel, beim Fahrzeug oder bei einem Marker. Das Sendeintervall lässt sich bei SinoTrack-Geräten hier ändern; PAJ-Geräte stellt man im PAJ-Portal ein.">
        {trackers.length === 0 && <p class="hint">Noch kein Tracker angelegt.</p>}
        <ul class="list">
          {trackers.map((t) => {
            const position = trackerPositions.value[t.id];
            return (
              <li key={t.id}>
                <span class={`presence ${position && Date.now() - position.ts < 10 * 60_000 ? 'on' : ''}`} />
                <div class="grow">
                  <b>{t.data.name}</b>
                  <small>
                    {t.data.anbieter === 'paj' ? 'PAJ' : 'SinoTrack'}, <span class="mono">{t.data.kennung}</span>, {t.data.kontoEmail ? `, Konto ${t.data.kontoEmail}` : ''}, {usage(t.id)}
                  </small>
                  <small class="hint">{position ? `Letzte Position ${ago(position.ts)}` : 'Noch keine Position empfangen'}</small>
                </div>
                {position && (
                  <button class="quiet" onClick={() => (focusRequest.value = { ...position, at: Date.now() })}>
                    Zeigen
                  </button>
                )}
                <button
                  class="quiet"
                  onClick={() => {
                    const name = prompt('Neuer Name des Trackers', t.data.name)?.trim();
                    if (name) put('tracker', t.id, { ...t.data, name: name.slice(0, 60) });
                  }}
                >
                  Umbenennen
                </button>
                {t.data.anbieter === 'sinotrack' && (
                  <select
                    title="Sendeintervall (wird an das Gerät geschickt)"
                    value={String(t.data.intervall ?? '')}
                    onChange={(e) => {
                      const sekunden = Number(e.currentTarget.value);
                      if (sekunden) command('tracker.intervall', { trackerId: t.id, sekunden });
                    }}
                  >
                    <option value="">Intervall</option>
                    {[10, 20, 30, 60, 120, 300, 600].map((sek) => (
                      <option key={sek} value={sek}>
                        {sek < 60 ? `${sek} s` : `${sek / 60} min`}
                      </option>
                    ))}
                  </select>
                )}
                <button
                  class="quiet"
                  title="Löschen"
                  onClick={() => {
                    if (confirm(`Tracker „${t.data.name}“ löschen?`)) del('tracker', t.id);
                  }}
                >
                  Löschen
                </button>
              </li>
            );
          })}
        </ul>
      </Section>

      <Section title="Tracker anlegen">
        <div class="grid2">
          <Field label="Name">
            <TextInput value={name.value} onInput={(v) => (name.value = v)} placeholder="z. B. ST-901 Nr. 3" maxLength={60} />
          </Field>
          <Field label="Anbieter">
            <select value={anbieter.value} onChange={(e) => (anbieter.value = e.currentTarget.value as Tracker['anbieter'])}>
              <option value="sinotrack">SinoTrack (direkt)</option>
              <option value="paj">PAJ</option>
            </select>
          </Field>
        </div>
        <Field label={anbieter.value === 'paj' ? 'Geräte-ID im PAJ-Portal' : 'Geräte-ID (auf dem Tracker aufgedruckt)'}>
          <TextInput value={kennung.value} onInput={(v) => (kennung.value = v.trim())} maxLength={32} />
        </Field>
        {anbieter.value === 'paj' && (
          <>
            <div class="grid2">
              <Field label="E-Mail des PAJ-Kontos">
                <TextInput type="email" value={ownEmail.value} onInput={(v) => (ownEmail.value = v.trim())} maxLength={120} />
              </Field>
              <Field label="Passwort des PAJ-Kontos">
                <TextInput type="password" value={ownPassword.value} onInput={(v) => (ownPassword.value = v)} maxLength={200} />
              </Field>
            </div>
            <p class="hint">Jeder PAJ-Tracker kann zu einem eigenen Konto gehören. Die Zugangsdaten gelten nur für diesen Tracker und werden verschlüsselt gespeichert; vorher wird geprüft, ob das Gerät zum Konto gehört. Leer lassen, um das zentrale PAJ-Konto unten zu nutzen.</p>
          </>
        )}
        <button
          class="primary"
          disabled={!name.value.trim() || !/^[0-9A-Za-z-]{4,32}$/.test(kennung.value) || (anbieter.value === 'paj' && (ownEmail.value !== '') !== (ownPassword.value !== ''))}
          onClick={() => {
            if (anbieter.value === 'paj' && ownEmail.value) {
              void attempt(async () => {
                await api('/trackers/paj', { method: 'POST', body: { id: newId(), name: name.value.trim(), kennung: kennung.value, email: ownEmail.value, passwort: ownPassword.value } });
                name.value = '';
                kennung.value = '';
                ownPassword.value = '';
              }, 'PAJ-Tracker angelegt.');
            } else {
              add({ name: name.value.trim(), anbieter: anbieter.value, kennung: kennung.value });
            }
          }}
        >
          {anbieter.value === 'paj' && ownEmail.value ? 'Prüfen und anlegen' : 'Anlegen'}
        </button>
      </Section>

      <Section title="SinoTrack direkt anbinden" hint="Die Tracker senden direkt an diesen Server, der Hersteller-Server in China ist nicht beteiligt.">
        {status?.tracker.h02Port ? (
          <>
            <p>Per SMS an die SIM des Trackers (Standardpasswort 0000):</p>
            <pre class="mono">
              8040000 {host} {status.tracker.h02Port}
              {'\n'}8030000 &lt;APN des Mobilfunkanbieters&gt;
              {'\n'}8050000 20
            </pre>
            <p class="hint">Voraussetzung: Am Router ist TCP-Port {status.tracker.h02Port} auf die Synology weitergeleitet. Die dritte Zeile stellt das Sendeintervall auf 20 Sekunden.</p>
            {status.tracker.unbekannt.length > 0 && (
              <>
                <p>Unbekannte Tracker, die sich gemeldet haben:</p>
                <ul class="list">
                  {status.tracker.unbekannt.map((u) => (
                    <li key={u.kennung}>
                      <div class="grow">
                        <b class="mono">{u.kennung}</b>
                        <small>{ago(u.zuletzt)}</small>
                      </div>
                      <button onClick={() => add({ name: `SinoTrack ${u.kennung.slice(-4)}`, anbieter: 'sinotrack', kennung: u.kennung })}>Übernehmen</button>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </>
        ) : (
          <p class="hint">Der Tracker-Empfang ist auf diesem Server abgeschaltet (SENTINEL_TRACKER_PORT).</p>
        )}
      </Section>

      <Section title="PAJ-Portal" hint="PAJ-Tracker melden sich nur beim Hersteller. Sentinel holt die Positionen dort alle 20 Sekunden ab. Die Zugangsdaten werden verschlüsselt gespeichert.">
        {status?.tracker.paj.aktiv ? (
          <>
            <p>
              Verbunden.{status.tracker.paj.fehler ? <span class="error"> Letzter Fehler: {status.tracker.paj.fehler}</span> : ''}
            </p>
            <div class="row">
              <button onClick={() => attempt(async () => void (pajDevices.value = (await api('/admin/paj/geraete')).geraete))}>Geräte abrufen</button>
              <button class="quiet" onClick={() => attempt(() => api('/admin/paj', { method: 'DELETE' }).then(refreshStatus), 'PAJ-Zugang entfernt.')}>
                Zugang entfernen
              </button>
            </div>
            {pajDevices.value && (
              <ul class="list">
                {pajDevices.value.map((d) => (
                  <li key={d.kennung}>
                    <div class="grow">
                      <b>{d.name}</b>
                      <small class="mono">{d.kennung}</small>
                    </div>
                    {!trackers.some((t) => t.data.anbieter === 'paj' && t.data.kennung === d.kennung) && (
                      <button onClick={() => add({ name: d.name.slice(0, 60), anbieter: 'paj', kennung: d.kennung })}>Übernehmen</button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </>
        ) : (
          <>
            <Field label="E-Mail des PAJ-Kontos">
              <TextInput type="email" value={pajEmail.value} onInput={(v) => (pajEmail.value = v)} />
            </Field>
            <Field label="Passwort">
              <TextInput type="password" value={pajPassword.value} onInput={(v) => (pajPassword.value = v)} />
            </Field>
            <button
              class="primary"
              disabled={!pajEmail.value || !pajPassword.value}
              onClick={() =>
                attempt(async () => {
                  await api('/admin/paj', { method: 'PUT', body: { email: pajEmail.value, passwort: pajPassword.value } });
                  pajPassword.value = '';
                  await refreshStatus();
                }, 'PAJ-Zugang gespeichert.')
              }
            >
              Verbinden
            </button>
          </>
        )}
      </Section>
    </>
  );
}
