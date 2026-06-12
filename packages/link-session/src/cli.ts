#!/usr/bin/env bun

import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";

import { linkSessionJsonl, unlinkMirroredDir, type LinkOutcome, type UnlinkOutcome } from "./link.ts";

const HELP = `
link-session-jsonl — hardlink a Claude Code session transcript across project folders
so the same session is visible/resumable from both a git worktree and its main checkout.

Usage:
  link-session-jsonl link <session-id> <src-cwd> <dst-cwd> [--wait-ms <n>]
  link-session-jsonl unlink-dir <worktree-cwd>
  link-session-jsonl <session-id> <src-cwd> <dst-cwd>      (alias for "link")

Modes:
  link         hardlink <src-hash>/<id>.jsonl into <dst-hash>/ (idempotent)
  unlink-dir   remove mirrored *.jsonl (nlink>=2 only) from a removed worktree's
               project folder, then rmdir it if empty (data-safe cleanup)

Options:
  --wait-ms <n>   poll up to n ms for the source transcript to appear (default 0).
                  Used by SessionStart, where the JSONL may not exist yet at hook time.
  --log <path>    append a JSON event line (default ~/.claude/logs/link-session.jsonl)
  --no-log        do not write the log file
  -h, --help      show this help

Exit codes:
  0  linked / already-linked / relinked / same-target / cleanup done
  3  source transcript not found (non-fatal: nothing to link yet)
  2  usage error
`.trimStart();

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    "wait-ms": { type: "string" },
    log: { type: "string" },
    "no-log": { type: "boolean" },
    help: { type: "boolean", short: "h" },
  },
});

if (values.help) {
  process.stdout.write(HELP);
  process.exit(0);
}

function logEvent(event: Record<string, unknown>): void {
  if (values["no-log"]) return;
  const home = process.env["HOME"] ?? "";
  const logPath = values.log ?? `${home}/.claude/logs/link-session.jsonl`;
  try {
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(logPath, `${JSON.stringify({ ts: new Date().toISOString(), ...event })}\n`);
  } catch {
    // logging must never break the hook
  }
}

function fail(message: string): never {
  process.stderr.write(`link-session-jsonl: ${message}\n`);
  process.exit(2);
}

const known = new Set(["link", "unlink-dir"]);
const mode = known.has(positionals[0] ?? "") ? positionals[0] : "link";
const args = known.has(positionals[0] ?? "") ? positionals.slice(1) : positionals;

async function runLink(): Promise<void> {
  const [sessionId, srcCwd, dstCwd] = args;
  if (!sessionId || !srcCwd || !dstCwd) fail("link requires <session-id> <src-cwd> <dst-cwd>");

  const waitMs = values["wait-ms"] ? Number.parseInt(values["wait-ms"], 10) : 0;
  if (Number.isNaN(waitMs) || waitMs < 0) fail("--wait-ms must be a non-negative integer");

  let outcome: LinkOutcome;
  try {
    outcome = await linkSessionJsonl({ sessionId, srcCwd, dstCwd, waitMs });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logEvent({ mode: "link", sessionId, srcCwd, dstCwd, error: message });
    process.stderr.write(`link-session-jsonl: ${message}\n`);
    process.exit(1);
  }

  logEvent({ mode: "link", sessionId, srcCwd, dstCwd, ...outcome });
  process.stderr.write(`link-session-jsonl: ${outcome.status} (${sessionId})\n`);
  process.exit(outcome.status === "source-missing" ? 3 : 0);
}

function runUnlinkDir(): void {
  const [worktreeCwd] = args;
  if (!worktreeCwd) fail("unlink-dir requires <worktree-cwd>");

  let outcome: UnlinkOutcome;
  try {
    outcome = unlinkMirroredDir(worktreeCwd);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    logEvent({ mode: "unlink-dir", worktreeCwd, error: message });
    process.stderr.write(`link-session-jsonl: ${message}\n`);
    process.exit(1);
  }

  logEvent({ mode: "unlink-dir", worktreeCwd, ...outcome });
  process.stderr.write(`link-session-jsonl: ${outcome.status} (${outcome.removed.length} removed)\n`);
  process.exit(0);
}

if (mode === "unlink-dir") {
  runUnlinkDir();
} else {
  await runLink();
}
