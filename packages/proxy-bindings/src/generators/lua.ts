const camelToSnake = (s: string) =>
  s.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);

export function generateLua(
  bindings: Record<string, string>,
  sourcePath: string,
): string {
  const lines = [
    `-- GENERATED FILE — do not edit. Source: ${sourcePath}`,
    "local M = {}",
    "",
  ];

  for (const [key, value] of Object.entries(bindings)) {
    lines.push(`M.${camelToSnake(key)} = "${value}"`);
  }

  lines.push("", "return M", "");
  return lines.join("\n");
}
