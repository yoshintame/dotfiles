import { z } from "zod";

const CARBON_MODIFIERS: Record<string, number> = {
  cmd: 256,
  shift: 512,
  alt: 2048,
  ctrl: 4096,
};

const CARBON_KEY_CODES: Record<string, number> = {
  a: 0, s: 1, d: 2, f: 3, h: 4, g: 5, z: 6, x: 7, c: 8, v: 9,
  b: 11, q: 12, w: 13, e: 14, r: 15, y: 16, t: 17,
  "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
  o: 31, u: 32, i: 34, p: 35, l: 37, j: 38, k: 40, n: 45, m: 46,
};

export const ShortcutSchema = z.object({
  carbonKeyCode: z.number().int(),
  carbonModifiers: z.number().int(),
});

export type Shortcut = z.infer<typeof ShortcutSchema>;

export function toShortcut(chord: string): Shortcut {
  const parts = chord.trim().toLowerCase().split(/\s+/);
  const key = parts.pop();
  const carbonKeyCode = key === undefined ? undefined : CARBON_KEY_CODES[key];
  if (carbonKeyCode === undefined) throw new Error(`Unsupported key in chord "${chord}"`);

  const carbonModifiers = parts.reduce((mask, name) => {
    const bit = CARBON_MODIFIERS[name];
    if (bit === undefined) throw new Error(`Unsupported modifier "${name}" in chord "${chord}"`);
    return mask | bit;
  }, 0);

  return { carbonKeyCode, carbonModifiers };
}

export const shortcutId = (shortcut: Shortcut) => `${shortcut.carbonModifiers}:${shortcut.carbonKeyCode}`;
