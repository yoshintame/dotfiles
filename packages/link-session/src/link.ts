import fs from "node:fs";
import path from "node:path";

import { projectDir, projectsRoot, sessionJsonlPath } from "./project-hash.ts";

export type LinkOutcome =
  | { status: "linked"; src: string; dst: string }
  | { status: "already-linked"; src: string; dst: string }
  | { status: "relinked"; src: string; dst: string; backup: string }
  | { status: "same-target"; src: string; dst: string }
  | { status: "source-missing"; sessionId: string; srcCwd: string };

export type UnlinkOutcome = {
  status: "purged" | "nothing-to-do" | "no-dir";
  dir: string;
  removed: string[];
  kept: string[];
  removedDir: boolean;
};

type FileId = { dev: number; ino: number };

function fileId(p: string): FileId | undefined {
  try {
    const st = fs.statSync(p);
    return { dev: st.dev, ino: st.ino };
  } catch {
    return undefined;
  }
}

function sameFile(a: FileId | undefined, b: FileId | undefined): boolean {
  return a !== undefined && b !== undefined && a.dev === b.dev && a.ino === b.ino;
}

export function findSourceJsonl(sessionId: string, srcCwd: string, home?: string): string | undefined {
  const direct = sessionJsonlPath(srcCwd, sessionId, home);
  if (fs.existsSync(direct)) return direct;

  const root = projectsRoot(home);
  let dirs: string[];
  try {
    dirs = fs.readdirSync(root);
  } catch {
    return undefined;
  }
  for (const dir of dirs) {
    const candidate = `${root}/${dir}/${sessionId}.jsonl`;
    if (fs.existsSync(candidate)) return candidate;
  }
  return undefined;
}

async function resolveSource(
  sessionId: string,
  srcCwd: string,
  home: string | undefined,
  waitMs: number,
): Promise<string | undefined> {
  const start = Date.now();
  for (;;) {
    const found = findSourceJsonl(sessionId, srcCwd, home);
    if (found) return found;
    const elapsed = Date.now() - start;
    if (elapsed >= waitMs) return undefined;
    await Bun.sleep(Math.min(50, waitMs - elapsed));
  }
}

export async function linkSessionJsonl(opts: {
  sessionId: string;
  srcCwd: string;
  dstCwd: string;
  home?: string;
  waitMs?: number;
}): Promise<LinkOutcome> {
  const { sessionId, srcCwd, dstCwd, home } = opts;
  const waitMs = opts.waitMs ?? 0;

  const src = await resolveSource(sessionId, srcCwd, home, waitMs);
  if (!src) return { status: "source-missing", sessionId, srcCwd };

  const dst = sessionJsonlPath(dstCwd, sessionId, home);
  if (path.resolve(src) === path.resolve(dst)) return { status: "same-target", src, dst };

  fs.mkdirSync(path.dirname(dst), { recursive: true });

  const srcId = fileId(src);
  const dstId = fileId(dst);

  if (dstId) {
    if (sameFile(srcId, dstId)) return { status: "already-linked", src, dst };
    const backup = `${dst}.broken-link.${dstId.ino}`;
    fs.renameSync(dst, backup);
    fs.linkSync(src, dst);
    return { status: "relinked", src, dst, backup };
  }

  try {
    fs.linkSync(src, dst);
    return { status: "linked", src, dst };
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "EEXIST") {
      if (sameFile(fileId(src), fileId(dst))) return { status: "already-linked", src, dst };
      const raceId = fileId(dst);
      const backup = `${dst}.broken-link.${raceId?.ino ?? "x"}`;
      fs.renameSync(dst, backup);
      fs.linkSync(src, dst);
      return { status: "relinked", src, dst, backup };
    }
    throw err;
  }
}

function inodeExistsIn(dirs: string[], name: string, id: FileId): boolean {
  for (const dir of dirs) {
    const sibling = `${dir}/${name}`;
    if (sameFile(fileId(sibling), id)) return true;
  }
  return false;
}

export function unlinkMirroredDir(worktreeCwd: string, home?: string): UnlinkOutcome {
  const dir = projectDir(worktreeCwd, home);
  let entries: string[];
  try {
    entries = fs.readdirSync(dir);
  } catch {
    return { status: "no-dir", dir, removed: [], kept: [], removedDir: false };
  }

  const root = projectsRoot(home);
  const here = path.resolve(dir);
  let otherDirs: string[];
  try {
    otherDirs = fs
      .readdirSync(root)
      .map((d) => `${root}/${d}`)
      .filter((d) => path.resolve(d) !== here);
  } catch {
    otherDirs = [];
  }

  const removed: string[] = [];
  const kept: string[] = [];
  for (const name of entries) {
    if (!name.endsWith(".jsonl")) continue;
    const file = `${dir}/${name}`;
    const id = fileId(file);
    if (!id) continue;
    if (inodeExistsIn(otherDirs, name, id)) {
      fs.unlinkSync(file);
      removed.push(name);
    } else {
      kept.push(name);
    }
  }

  let removedDir = false;
  if (kept.length === 0) {
    try {
      if (fs.readdirSync(dir).length === 0) {
        fs.rmdirSync(dir);
        removedDir = true;
      }
    } catch {
      removedDir = false;
    }
  }

  const status = removed.length > 0 || removedDir ? "purged" : "nothing-to-do";
  return { status, dir, removed, kept, removedDir };
}
