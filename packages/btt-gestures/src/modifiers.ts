export const Modifier = {
  cmd: 1048576,
  shift: 131072,
  alt: 524288,
  ctrl: 262144,
  fn: 8388608,
} as const;

export type ModifierName = keyof typeof Modifier;

export function toModifierMask(mods: readonly ModifierName[]): number {
  return mods.reduce((mask, name) => mask | Modifier[name], 0);
}
