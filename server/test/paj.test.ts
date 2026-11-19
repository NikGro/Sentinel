import assert from 'node:assert/strict';
import { test } from 'node:test';
import { PajClient, PajPoller, type PajCredentials } from '../src/trackers/paj.js';

/** PAJ-Schnittstelle als Attrappe: je Konto eigene Geräte. */
function fakePaj(accounts: Record<string, number[]>) {
  const logins: string[] = [];
  const fetchFn = (async (url: string | URL, init?: RequestInit) => {
    const u = new URL(String(url));
    if (u.pathname.endsWith('/login')) {
      const email = u.searchParams.get('email')!;
      logins.push(email);
      if (!accounts[email]) return new Response('{}', { status: 401 });
      return Response.json({ success: { token: email } });
    }
    const email = String((init?.headers as Record<string, string>).authorization).slice(7);
    if (u.pathname.endsWith('/device')) return Response.json({ success: accounts[email]!.map((id) => ({ id, name: `Gerät ${id}` })) });
    const ids = (JSON.parse(String(init?.body)) as { deviceIDs: number[] }).deviceIDs.filter((id) => accounts[email]!.includes(id));
    return Response.json({ success: ids.map((id) => ({ iddevice: id, lat: 53.5, lng: 10, dateunix: 1_700_000_000 })) });
  }) as typeof fetch;
  return { logins, make: (c: PajCredentials) => new PajClient(c, fetchFn) };
}

test('PAJ: jeder Tracker fragt über sein eigenes Konto ab, die Geräte-ID wird geprüft', async () => {
  const paj = fakePaj({ 'falke@x.de': [111], 'adler@x.de': [222, 333] });
  const fixes: string[] = [];
  const poller = new PajPoller(
    () => [
      { kennung: '111', konto: { email: 'falke@x.de', password: 'a' } },
      { kennung: '222', konto: { email: 'adler@x.de', password: 'b' } },
      { kennung: '333', konto: { email: 'adler@x.de', password: 'b' } },
    ],
    (kennung) => fixes.push(kennung),
    paj.make,
  );
  assert.equal(poller.active, true, 'Auch ohne zentrales Konto aktiv');
  await poller.poll();
  assert.deepEqual(fixes.sort(), ['111', '222', '333']);
  await poller.poll();
  assert.equal(paj.logins.length, 2, 'Anmeldung je Konto bleibt erhalten');

  assert.equal(await poller.verify({ email: 'falke@x.de', password: 'a' }, '111'), true);
  assert.equal(await poller.verify({ email: 'falke@x.de', password: 'a' }, '222'), false);
  await assert.rejects(poller.verify({ email: 'fremd@x.de', password: 'c' }, '111'));
  poller.stop();
});
