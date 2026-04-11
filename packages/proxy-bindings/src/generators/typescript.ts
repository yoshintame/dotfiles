const MOD_MAP: Record<string, string> = {
  cmd: "⌘",
  alt: "⌥",
  ctrl: "⌃",
  shift: "⇧",
};

function parseShortcut(shortcut: string) {
  const parts = shortcut.split(" ");
  const key = parts.pop()!;
  const mods = parts.map((m) => MOD_MAP[m] ?? m).join("");
  return { key, mods };
}

export function generateTypeScript(
  bindings: Record<string, string>,
  sourcePath: string,
): string {
  const lines = [
    `// GENERATED FILE — do not edit. Source: ${sourcePath}`,
    "import type { ModifierParam, ToKeyParam } from 'karabiner.ts'",
    "import { toKey } from 'karabiner.ts'",
    "",
    "export const proxy = {",
  ];

  for (const [key, value] of Object.entries(bindings)) {
    const { key: k, mods } = parseShortcut(value);
    if (mods) {
      lines.push(
        `  ${key}: toKey('${k}' as ToKeyParam, '${mods}' as ModifierParam),`,
      );
    } else {
      lines.push(`  ${key}: toKey('${k}' as ToKeyParam),`);
    }
  }

  lines.push("} as const", "");
  lines.push("export type ProxyBindingId = keyof typeof proxy", "");
  return lines.join("\n");
}
