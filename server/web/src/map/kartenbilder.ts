import { SYMBOLPFADE } from './symbolpfade';
import { lagekern } from './kern';

/**
 * Bilder, die der gemeinsame Stil anfordert (`grund-#RRGGBB`, `schild-#RRGGBB`, `sym-…`, `zeichen-a`, `ich-…`), im
 * Browser gezeichnet. Gleiche Formen und Maße wie auf Android (Material-Symbole aus denselben Vorlagen).
 */
export interface Kartenbild {
  width: number;
  height: number;
  data: Uint8ClampedArray;
  pixelRatio: number;
  stretchX?: [number, number][];
  stretchY?: [number, number][];
  content?: [number, number, number, number];
}

const R = Math.max(1, Math.round(window.devicePixelRatio || 1));
const px = (dp: number) => dp * R;

function leinwand(w: number, h: number): CanvasRenderingContext2D {
  const c = document.createElement('canvas');
  c.width = Math.ceil(w);
  c.height = Math.ceil(h);
  return c.getContext('2d')!;
}

function bild(ctx: CanvasRenderingContext2D, extra: Partial<Kartenbild> = {}): Kartenbild {
  const { width, height } = ctx.canvas;
  return { width, height, data: ctx.getImageData(0, 0, width, height).data, pixelRatio: R, ...extra };
}

function rundRechteck(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

/** Abgerundetes Quadrat in der Farbe mit weißem Rand und leichtem Schatten. */
function grund(farbe: string): Kartenbild {
  const g = px(44);
  const ctx = leinwand(g, g);
  ctx.shadowColor = 'rgba(0,0,0,0.35)';
  ctx.shadowBlur = px(2.5);
  ctx.shadowOffsetY = px(1);
  rundRechteck(ctx, px(3), px(2), g - px(6), g - px(6), px(11));
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  ctx.shadowColor = 'transparent';
  rundRechteck(ctx, px(5), px(4), g - px(10), g - px(10), px(9));
  ctx.fillStyle = farbe;
  ctx.fill();
  return bild(ctx);
}

/** Linienschild: abgerundetes Rechteck in Linienfarbe mit weißem Rand, dehnbar für die Liniennummer. */
function schild(farbe: string): Kartenbild {
  const w = px(30);
  const h = px(22);
  const ctx = leinwand(w, h);
  rundRechteck(ctx, px(1), px(1), w - px(2), h - px(2), px(5));
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  rundRechteck(ctx, px(2.5), px(2.5), w - px(5), h - px(5), px(4));
  ctx.fillStyle = farbe;
  ctx.fill();
  const rand = px(7);
  return bild(ctx, { stretchX: [[rand, w - rand]], stretchY: [[rand, h - rand]], content: [rand, rand, w - rand, h - rand] });
}

/** Material-Symbol in Weiß (24er-Raster skaliert). */
function zeichen(material: string, dp = 22, farbe = '#FFFFFF'): Kartenbild | null {
  const pfad = SYMBOLPFADE[material];
  if (!pfad) return null;
  const g = px(dp);
  const ctx = leinwand(g, g);
  ctx.scale(g / 24, g / 24);
  ctx.fillStyle = farbe;
  ctx.fill(new Path2D(pfad));
  return bild(ctx);
}

function buchstabeA(): Kartenbild {
  const g = px(18);
  const ctx = leinwand(g, g);
  ctx.beginPath();
  ctx.arc(g / 2, g / 2, g / 2 - px(1), 0, Math.PI * 2);
  ctx.fillStyle = '#FF3B30';
  ctx.fill();
  ctx.lineWidth = px(1.5);
  ctx.strokeStyle = '#FFFFFF';
  ctx.stroke();
  ctx.fillStyle = '#FFFFFF';
  ctx.font = `bold ${px(11)}px system-ui, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('A', g / 2, g / 2 + px(0.5));
  return bild(ctx);
}

function ichPunkt(): Kartenbild {
  const g = px(26);
  const ctx = leinwand(g, g);
  ctx.shadowColor = 'rgba(0,0,0,0.3)';
  ctx.shadowBlur = px(2);
  ctx.beginPath();
  ctx.arc(g / 2, g / 2, px(11), 0, Math.PI * 2);
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  ctx.shadowColor = 'transparent';
  ctx.beginPath();
  ctx.arc(g / 2, g / 2, px(8), 0, Math.PI * 2);
  ctx.fillStyle = '#0A84FF';
  ctx.fill();
  return bild(ctx);
}

function ichPfeil(): Kartenbild {
  const g = px(48);
  const ctx = leinwand(g, g);
  ctx.beginPath();
  ctx.moveTo(g / 2, px(4));
  ctx.lineTo(g - px(8), g - px(6));
  ctx.lineTo(g / 2, g - px(16));
  ctx.lineTo(px(8), g - px(6));
  ctx.closePath();
  ctx.fillStyle = '#0A84FF';
  ctx.fill();
  ctx.lineWidth = px(2.5);
  ctx.lineJoin = 'round';
  ctx.strokeStyle = '#FFFFFF';
  ctx.stroke();
  return bild(ctx);
}

export function kartenbild(name: string): Kartenbild | null {
  if (name.startsWith('grund-')) return grund(name.slice(6));
  if (name.startsWith('schild-')) return schild(name.slice(7));
  if (name.startsWith('sym-')) {
    const material = lagekern.symbolFuerBild(name);
    return material ? zeichen(material) : null;
  }
  if (name === 'zeichen-a') return buchstabeA();
  if (name === 'ich-punkt' || name === 'ich-fahrzeug') return ichPunkt();
  if (name === 'ich-pfeil') return ichPfeil();
  return null;
}
