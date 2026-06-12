import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { afterEach, beforeEach, expect, test } from "bun:test";

import { linkSessionJsonl, unlinkMirroredDir } from "./link.ts";
import { projectDir, sessionJsonlPath } from "./project-hash.ts";

let home = "";

beforeEach(() => {
  home = fs.mkdtempSync(path.join(os.tmpdir(), "link-session-"));
});

afterEach(() => {
  fs.rmSync(home, { recursive: true, force: true });
});

const MAIN = "/Users/me/proj";
const WT = "/Users/me/.local/share/worktrees/proj@feat/x";

function seedSource(sessionId: string, content = "line1\n"): string {
  const file = sessionJsonlPath(MAIN, sessionId, home);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
  return file;
}

function inode(file: string): number {
  return fs.statSync(file).ino;
}

test("first link creates a shared-inode hardlink in the destination project dir", async () => {
  const id = "11111111-1111-1111-1111-111111111111";
  const src = seedSource(id);
  const outcome = await linkSessionJsonl({ sessionId: id, srcCwd: MAIN, dstCwd: WT, home });
  expect(outcome.status).toBe("linked");
  const dst = sessionJsonlPath(WT, id, home);
  expect(inode(dst)).toBe(inode(src));
});

test("append to source is visible through the destination (one inode)", async () => {
  const id = "22222222-2222-2222-2222-222222222222";
  const src = seedSource(id, "a\n");
  await linkSessionJsonl({ sessionId: id, srcCwd: MAIN, dstCwd: WT, home });
  fs.appendFileSync(src, "b\n");
  expect(fs.readFileSync(sessionJsonlPath(WT, id, home), "utf8")).toBe("a\nb\n");
});

test("relinking is idempotent (already-linked)", async () => {
  const id = "33333333-3333-3333-3333-333333333333";
  seedSource(id);
  await linkSessionJsonl({ sessionId: id, srcCwd: MAIN, dstCwd: WT, home });
  const again = await linkSessionJsonl({ sessionId: id, srcCwd: MAIN, dstCwd: WT, home });
  expect(again.status).toBe("already-linked");
});

test("a divergent destination inode is backed up, not clobbered, then relinked", async () => {
  const id = "44444444-4444-4444-4444-444444444444";
  const src = seedSource(id, "SOURCE\n");
  const dst = sessionJsonlPath(WT, id, home);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.writeFileSync(dst, "STALE\n");

  const outcome = await linkSessionJsonl({ sessionId: id, srcCwd: MAIN, dstCwd: WT, home });
  expect(outcome.status).toBe("relinked");
  expect(inode(dst)).toBe(inode(src));
  const backups = fs.readdirSync(path.dirname(dst)).filter((n) => n.includes(".broken-link."));
  expect(backups).toHaveLength(1);
  expect(fs.readFileSync(`${path.dirname(dst)}/${backups[0]}`, "utf8")).toBe("STALE\n");
});

test("missing source transcript yields source-missing instead of throwing", async () => {
  const outcome = await linkSessionJsonl({
    sessionId: "55555555-5555-5555-5555-555555555555",
    srcCwd: MAIN,
    dstCwd: WT,
    home,
  });
  expect(outcome.status).toBe("source-missing");
});

test("scan fallback finds the source even when src cwd hash is wrong", async () => {
  const id = "66666666-6666-6666-6666-666666666666";
  seedSource(id);
  const outcome = await linkSessionJsonl({ sessionId: id, srcCwd: "/wrong/cwd", dstCwd: WT, home });
  expect(outcome.status).toBe("linked");
});

test("unlink-dir purges a mirror but keeps the sole surviving copy (data-safe)", async () => {
  const mirrored = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
  const orphan = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
  seedSource(mirrored, "M\n");
  seedSource(orphan, "O\n");
  await linkSessionJsonl({ sessionId: mirrored, srcCwd: MAIN, dstCwd: WT, home });
  await linkSessionJsonl({ sessionId: orphan, srcCwd: MAIN, dstCwd: WT, home });

  fs.unlinkSync(sessionJsonlPath(MAIN, orphan, home));

  const outcome = unlinkMirroredDir(WT, home);
  expect(outcome.removed).toContain(`${mirrored}.jsonl`);
  expect(outcome.kept).toContain(`${orphan}.jsonl`);
  expect(fs.existsSync(sessionJsonlPath(WT, mirrored, home))).toBe(false);
  expect(fs.readFileSync(sessionJsonlPath(WT, orphan, home), "utf8")).toBe("O\n");
});

test("unlink-dir removes the project dir when nothing is left to keep", async () => {
  const id = "cccccccc-cccc-cccc-cccc-cccccccccccc";
  seedSource(id);
  await linkSessionJsonl({ sessionId: id, srcCwd: MAIN, dstCwd: WT, home });
  const outcome = unlinkMirroredDir(WT, home);
  expect(outcome.removedDir).toBe(true);
  expect(fs.existsSync(projectDir(WT, home))).toBe(false);
});
