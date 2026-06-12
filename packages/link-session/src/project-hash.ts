const HOME = (): string => process.env["HOME"] ?? "";

export function normalizeCwd(absPath: string): string {
  if (absPath.length <= 1) return absPath;
  return absPath.replace(/\/+$/, "");
}

export function projectHash(absPath: string): string {
  return normalizeCwd(absPath).replace(/[^a-zA-Z0-9]/g, "-");
}

export function projectsRoot(home: string = HOME()): string {
  return `${home}/.claude/projects`;
}

export function projectDir(absPath: string, home: string = HOME()): string {
  return `${projectsRoot(home)}/${projectHash(absPath)}`;
}

export function sessionJsonlPath(absPath: string, sessionId: string, home: string = HOME()): string {
  return `${projectDir(absPath, home)}/${sessionId}.jsonl`;
}
