#!/usr/bin/env bun

import { join } from "node:path";
import { tmpdir } from "node:os";
import { defineCommand, runMain } from "citty";

type Kind = string;
type Entry = { kind: Kind; name: string; options: string; line: string };
type Key = { kind: Kind; name: string };
type Overrides = { skip: Key[]; args: (Key & { args: string[] })[] };
type Finding = { severity: "error" | "warning"; subject: string; reason: string };

const ENTRY = /^([a-z]+) "([^"]+)"(.*)$/;
const FAILED = /^(?:Installing|Upgrading|Tapping) (.+) has failed!$/;
const MARKETPLACE = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery";

const keyOf = (key: Key) => `${key.kind} ${key.name}`;

async function readDump(dir: string): Promise<Entry[]> {
  const entries: Entry[] = [];
  for (const line of (await Bun.file(join(dir, "Brewfile")).text()).split("\n")) {
    const match = line.match(ENTRY);
    if (match) entries.push({ kind: match[1], name: match[2], options: match[3], line });
  }
  return entries;
}

async function readOverrides(dir: string): Promise<Overrides> {
  const file = Bun.file(join(dir, "Brewfile.overrides.json"));
  if (!(await file.exists())) return { skip: [], args: [] };
  const overrides = (await file.json()) as Partial<Overrides>;
  return { skip: overrides.skip ?? [], args: overrides.args ?? [] };
}

function compose(entries: Entry[], overrides: Overrides, formulaeOnly: boolean): Entry[] {
  const skipped = new Set(overrides.skip.map(keyOf));
  const extraArgs = new Map(overrides.args.map((override) => [keyOf(override), override.args]));
  return entries
    .filter((entry) => !skipped.has(keyOf(entry)))
    .filter((entry) => !formulaeOnly || entry.kind === "tap" || entry.kind === "brew")
    .map((entry) => {
      const args = extraArgs.get(keyOf(entry));
      if (!args) return entry;
      const list = args.map((arg) => JSON.stringify(arg)).join(", ");
      return { ...entry, line: `${entry.kind} "${entry.name}"${entry.options}, args: [${list}]` };
    });
}

function staleOverrides(entries: Entry[], overrides: Overrides): Finding[] {
  const present = new Set(entries.map(keyOf));
  return [...overrides.skip, ...overrides.args]
    .filter((override) => !present.has(keyOf(override)))
    .map((override) => ({ severity: "error", subject: keyOf(override), reason: "override matches no Brewfile entry" }));
}

type Result = { code: number; stdout: string; stderr: string; output: string };

async function run(command: string[], tee: boolean): Promise<Result> {
  const proc = Bun.spawn(command, { stdout: "pipe", stderr: "pipe" });
  let output = "";
  const pump = async (stream: ReadableStream<Uint8Array>, sink: NodeJS.WriteStream) => {
    const decoder = new TextDecoder();
    let text = "";
    for await (const chunk of stream) {
      const piece = decoder.decode(chunk, { stream: true });
      text += piece;
      output += piece;
      if (tee) sink.write(piece);
    }
    return text;
  };
  const [stdout, stderr] = await Promise.all([pump(proc.stdout, process.stdout), pump(proc.stderr, process.stderr)]);
  return { code: await proc.exited, stdout, stderr, output };
}

const dirArg = {
  type: "string",
  description: "Directory with Brewfile and Brewfile.overrides.json",
  default: "hosts/lasthaze-mbp/packages",
} as const;

const install = defineCommand({
  meta: { name: "install", description: "Install the Brewfile with overrides applied; report entries that failed" },
  args: {
    dir: dirArg,
    "formulae-only": { type: "boolean", description: "Install only taps and formulae", default: false },
    cleanup: { type: "boolean", description: "Then uninstall everything not in the Brewfile", default: false },
    "dry-run": { type: "boolean", description: "Print the composed Brewfile and exit", default: false },
  },
  async run({ args }) {
    const entries = await readDump(args.dir);
    const composed = compose(entries, await readOverrides(args.dir), args["formulae-only"]);
    const brewfile = composed.map((entry) => entry.line).join("\n") + "\n";
    if (args["dry-run"]) {
      process.stdout.write(brewfile);
      return;
    }

    const path = join(tmpdir(), `Brewfile.${process.pid}`);
    await Bun.write(path, brewfile);
    const result = await run(["brew", "bundle", "install", `--file=${path}`, "--no-upgrade"], true);
    await Bun.file(path).delete();

    const failed = result.output.split("\n").flatMap((line) => line.match(FAILED)?.[1] ?? []);
    const errors = result.output.split("\n").filter((line) => line.startsWith("Error: "));
    if (result.code !== 0 || failed.length > 0) {
      console.log("\n\x1b[1;33m!!\x1b[0m Not installed from the Brewfile:");
      for (const name of failed) console.log(`   ${name}`);
      for (const line of errors) console.log(`   ${line}`);
    }

    if (args.cleanup) {
      const cleanup = await run(["brew", "bundle", "cleanup", `--file=${join(args.dir, "Brewfile")}`, "--force"], true);
      if (cleanup.code !== 0) process.exitCode = cleanup.code;
    }
    if (result.code !== 0) process.exitCode = result.code;
  },
});

async function brewInfo(entry: Entry): Promise<Finding | undefined> {
  const flag = entry.kind === "cask" ? "--cask" : "--formula";
  const result = await run(["brew", "info", "--json=v2", flag, entry.name], false);
  const subject = keyOf(entry);
  if (result.code !== 0) {
    const reason = result.stderr.trim().split("\n").filter((line) => line.startsWith("Error: ")).pop() ?? "not found";
    return { severity: "error", subject, reason };
  }
  const json = JSON.parse(result.stdout);
  const info = (entry.kind === "cask" ? json.casks : json.formulae)[0];
  if (info?.disabled) {
    return { severity: "error", subject, reason: `disabled: ${info.disable_reason ?? "no reason"} (${info.disable_date ?? "?"})` };
  }
  if (info?.deprecated) {
    return { severity: "warning", subject, reason: `deprecated: ${info.deprecation_reason ?? "no reason"} (${info.deprecation_date ?? "?"})` };
  }
  return undefined;
}

async function missingExtensions(ids: string[]): Promise<Finding[]> {
  const found = new Set<string>();
  for (let i = 0; i < ids.length; i += 50) {
    const batch = ids.slice(i, i + 50);
    const response = await fetch(MARKETPLACE, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json;api-version=3.0-preview.1" },
      body: JSON.stringify({
        filters: [{ criteria: batch.map((value) => ({ filterType: 7, value })), pageSize: batch.length }],
        flags: 0,
      }),
    }).catch((error: Error) => error);
    if (response instanceof Error || !response.ok) {
      const reason = response instanceof Error ? response.message : `HTTP ${response.status}`;
      return [{ severity: "error", subject: "vscode marketplace", reason: `query failed: ${reason}` }];
    }
    const data = (await response.json()) as {
      results: { extensions: { publisher: { publisherName: string }; extensionName: string }[] }[];
    };
    for (const extension of data.results[0]?.extensions ?? []) {
      found.add(`${extension.publisher.publisherName}.${extension.extensionName}`.toLowerCase());
    }
  }
  return ids
    .filter((id) => !found.has(id.toLowerCase()))
    .map((id) => ({ severity: "error", subject: `vscode ${id}`, reason: "not in the VS Code Marketplace" }));
}

async function trustTaps(entries: Entry[]): Promise<Finding[]> {
  const findings: Finding[] = [];
  for (const tap of entries.filter((entry) => entry.kind === "tap")) {
    const url = tap.options.match(/^, "([^"]+)"/)?.[1];
    const tapped = await run(["brew", "tap", tap.name, ...(url ? [url] : [])], false);
    if (tapped.code !== 0) {
      findings.push({ severity: "error", subject: keyOf(tap), reason: tapped.output.trim().split("\n").pop() ?? "tap failed" });
      continue;
    }
    await run(["brew", "trust", "--tap", tap.name], false);
  }
  return findings;
}

const lint = defineCommand({
  meta: {
    name: "lint",
    description: "Report Brewfile entries a clean Mac could not install and overrides that match nothing",
  },
  args: {
    dir: dirArg,
    "trust-taps": { type: "boolean", description: "Tap and trust every tap first (for a fresh CI runner)", default: false },
  },
  async run({ args }) {
    const entries = await readDump(args.dir);
    const overrides = await readOverrides(args.dir);
    const composed = compose(entries, overrides, false);

    const findings: Finding[] = [...staleOverrides(entries, overrides)];
    if (args["trust-taps"]) findings.push(...(await trustTaps(composed)));
    for (const entry of composed.filter((entry) => entry.kind === "brew" || entry.kind === "cask")) {
      const finding = await brewInfo(entry);
      if (finding) findings.push(finding);
    }
    findings.push(...(await missingExtensions(composed.filter((entry) => entry.kind === "vscode").map((entry) => entry.name))));

    for (const finding of findings) {
      const line = `${finding.severity.toUpperCase()} ${finding.subject}: ${finding.reason}`;
      console.log(process.env.GITHUB_ACTIONS ? `::${finding.severity} title=Brewfile::${line}` : line);
    }
    const errors = findings.filter((finding) => finding.severity === "error").length;
    console.log(`checked ${composed.length} entries: ${errors} errors, ${findings.length - errors} warnings`);
    if (errors > 0) process.exitCode = 1;
  },
});

runMain(
  defineCommand({
    meta: { name: "brewfile", description: "Install and lint the Brewfile dump with Brewfile.overrides.json applied" },
    subCommands: { install, lint },
  }),
);
