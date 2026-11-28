import { signal } from '@preact/signals';
import { WebLage } from '../kern/sentinel-kern.mjs';

/**
 * Gemeinsamer Kern im Web: dieselbe Lage, Karten-Szene und Kurzübersicht wie in den Apps. Die Server-Verbindung
 * reicht jede Nachricht hierher (`kernEmpfangen`); `kernStand` zählt Änderungen, damit die Karte neu zeichnet.
 */
export const lagekern = new WebLage();
export const kernStand = signal(0);

export function kernEmpfangen(text: string): void {
  try {
    lagekern.empfangen(text);
    kernStand.value++;
  } catch {
    // Unbekannte Nachrichten ignoriert der Kern; ein Fehler hier darf die Kommandozentrale nicht stören.
  }
}
