import { useSignal } from '@preact/signals';
import { useEffect } from 'preact/hooks';
import { adminStatus, api, attempt, authed, nameOf, refreshStatus, tables } from '../store';
import { ago, dateTime, Field, Section, TextInput } from '../ui';

/** Zugang, Geräte, App-Verteilung und Protokoll. */
export function SystemPanel() {
  const status = adminStatus.value;
  const showCode = useSignal(false);
  const current = useSignal('');
  const next = useSignal('');
  const audit = useSignal<{ ts: number; actor: string; action: string; detail: string }[]>([]);

  useEffect(() => {
    void refreshStatus();
    void api('/admin/protokoll').then((r) => (audit.value = r.eintraege)).catch(() => undefined);
  }, []);

  if (!status) return <p class="hint">Lade …</p>;
  const devices = status.geraete.filter((d) => !d.revoked);

  return (
    <>
      <Section title="Zugangscode für Fahnder" hint="Mit diesem Code meldet sich ein Gerät einmalig an. Nach dem Erneuern bleiben bereits angemeldete Geräte verbunden.">
        <div class="row between">
          <code class="code">{showCode.value ? status.zugangscode : '••••••••••'}</code>
          <div class="row">
            <button onClick={() => (showCode.value = !showCode.value)}>{showCode.value ? 'Verbergen' : 'Anzeigen'}</button>
            <button
              class="quiet"
              onClick={() => {
                if (confirm('Neuen Zugangscode erzeugen? Der bisherige wird ungültig.')) void attempt(() => api('/admin/zugangscode', { method: 'POST' }).then(refreshStatus), 'Neuer Zugangscode erzeugt.');
              }}
            >
              Erneuern
            </button>
          </div>
        </div>
      </Section>

      <Section title="Angemeldete Geräte" hint="Sperren trennt das Gerät sofort und entfernt dessen Profil aus der Lage.">
        {devices.length === 0 && <p class="hint">Noch kein Gerät angemeldet.</p>}
        <ul class="list">
          {devices.map((d) => (
            <li key={d.id}>
              <div class="grow">
                <b>{tables.member.value[d.id]?.data.spitzname ?? 'Ohne Profil'}</b>
                <small>
                  {d.name}, zuletzt {ago(d.lastSeen)}
                </small>
              </div>
              <button
                class="danger"
                onClick={() => {
                  if (confirm('Dieses Gerät sperren?')) void attempt(() => api(`/admin/geraete/${d.id}/sperren`, { method: 'POST' }).then(refreshStatus), 'Gerät gesperrt.');
                }}
              >
                Sperren
              </button>
            </li>
          ))}
        </ul>
      </Section>

      <Section title="App-Verteilung (SideStore)" hint="Diese Adresse in SideStore unter „Quellen“ hinzufügen. Neue Versionen erscheinen dort automatisch.">
        <code class="code small">{status.sidestoreQuelle}</code>
        <p>
          {status.release ? (
            <>
              Aktuell: Version {status.release.version} ({status.release.build}), {dateTime(Date.parse(status.release.datum))}, {(status.release.groesse / 1_048_576).toFixed(1)} MB
            </>
          ) : (
            'Noch keine App-Version veröffentlicht.'
          )}
        </p>
      </Section>

      <Section title="Dienste">
        <p>Karte: {status.karte === 'apple' ? 'Apple Maps' : 'OpenStreetMap (kein Apple-Maps-Schlüssel hinterlegt)'}</p>
        <p>Weg-Zeit-Berechnung: {status.routing ? 'Wegenetz (Valhalla) für Fuß und Kfz, ÖPNV als Näherung' : 'Näherungsmodell'}</p>
        <p>Tracker-Empfang: {status.tracker.h02Port ? `TCP-Port ${status.tracker.h02Port}` : 'abgeschaltet'}</p>
        <p>
          ÖPNV-Linien: {status.oepnv.linien > 0 ? `${status.oepnv.linien} Fahrtrichtungen, Stand ${status.oepnv.stand ? new Date(status.oepnv.stand).toLocaleDateString('de-DE') : '–'}` : status.oepnv.fehler ? `nicht geladen (${status.oepnv.fehler})` : 'werden geladen'}
        </p>
        <p>Argus Predict: {status.argus.verfuegbar ? `${status.argus.projekte.length} Projekte` : 'nicht eingebunden'}</p>
      </Section>

      <Section title="Verwaltungspasswort ändern">
        <Field label="Aktuelles Passwort">
          <TextInput type="password" value={current.value} onInput={(v) => (current.value = v)} />
        </Field>
        <Field label="Neues Passwort (mindestens 12 Zeichen)">
          <TextInput type="password" value={next.value} onInput={(v) => (next.value = v)} />
        </Field>
        <button
          class="primary"
          disabled={!current.value || next.value.length < 12}
          onClick={() =>
            attempt(async () => {
              await api('/admin/passwort', { method: 'POST', body: { aktuell: current.value, neu: next.value } });
              authed.value = false;
            }, 'Passwort geändert. Bitte neu anmelden.')
          }
        >
          Ändern
        </button>
      </Section>

      <Section title="Protokoll">
        <ul class="audit">
          {audit.value.map((entry, i) => (
            <li key={i}>
              <span class="mono">{dateTime(entry.ts)}</span> <b>{nameOf(entry.actor)}</b> {entry.action} {entry.detail}
            </li>
          ))}
        </ul>
      </Section>
    </>
  );
}
