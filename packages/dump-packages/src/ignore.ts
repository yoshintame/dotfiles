export async function loadIgnore(path: string): Promise<Set<string>> {
  const file = Bun.file(path);
  if (!(await file.exists())) return new Set();
  const content = await file.text();
  const names = content
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
  return new Set(names);
}
