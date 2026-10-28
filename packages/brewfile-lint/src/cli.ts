#!/usr/bin/env bun

import { join } from "node:path";
import { defineCommand, runMain } from "citty";
import { $ } from "dax-sh";

type Kind = "tap" | "brew" | "cask" | "vscode";
type Entry = { kind: Kind; name: string };
type Finding = { severity: "error" | "warning"; entry: Entry; reason: string };

const ENTRY = /^(tap|brew|cask|vscode) "([^"]+)"/;
const MARKETPLACE = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery";

async function readLines(path: string): Promise<string[]> {
  const file = Bun.file(path);
  if (!(await file.exists())) return [];
  return (await file.text()).split("\n");
}

async function composeEntries(dir: string): Promise<Entry[]> {
  const skip = new Set(await readLines(join(dir, "Brewfile.skip")));
  const dump = (await readLines(join(dir, "Brewfile"))).filter((line) => !skip.has(line));
  const lines = [...dump, ...(await readLines(join(dir, "Brewfile.extra")))];
  const entries: Entry[] = [];
  for (const line of lines) {
    const match = line.match(ENTRY);
    if (match) entries.push({ kind: match[1] as Kind, name: match[2] });
  }
  return entries;
}

async function brewInfo(entry: Entry): Promise<Finding | undefined> {
  const flag = entry.kind === "cask" ? "--cask" : "--formula";
  const result = await $`brew info --json=v2 ${flag} ${entry.name}`.quiet().noThrow();
  if (result.code !== 0) {
    const reason = result.stderr.trim().split("\n").pop() ?? "not found";
    return { severity: "error", entry, reason };
  }
  const json = JSON.parse(result.stdout);
  const info = (entry.kind === "cask" ? json.casks : json.formulae)[0];
  if (info?.disabled) {
    return { severity: "error", entry, reason: `disabled: ${info.disable_reason ?? "no reason"} (${info.disable_date ?? "?"})` };
  }
  if (info?.deprecated) {
    return { severity: "warning", entry, reason: `deprecated: ${info.deprecation_reason ?? "no reason"} (${info.deprecation_date ?? "?"})` };
  }
  return undefined;
}

async function missingExtensions(ids: string[]): Promise<string[]> {
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
    });
    if (!response.ok) throw new Error(`marketplace query failed: ${response.status}`);
    const data = (await response.json()) as {
      results: { extensions: { publisher: { publisherName: string }; extensionName: string }[] }[];
    };
    for (const extension of data.results[0]?.extensions ?? []) {
      found.add(`${extension.publisher.publisherName}.${extension.extensionName}`.toLowerCase());
    }
  }
  return ids.filter((id) => !found.has(id.toLowerCase()));
}

const main = defineCommand({
  meta: {
    name: "brewfile-lint",
    description: "Report Brewfile entries a clean Mac could not install: missing, disabled or deprecated formulae and casks, VS Code extensions gone from the Marketplace",
  },
  args: {
    dir: { type: "string", description: "Directory with Brewfile, Brewfile.skip and Brewfile.extra", default: "hosts/lasthaze-mbp/packages" },
    "trust-taps": { type: "boolean", description: "Tap and trust every tap first (for a fresh CI runner)", default: false },
  },
  async run({ args }) {
    const entries = await composeEntries(args.dir);
    if (args["trust-taps"]) {
      for (const tap of entries.filter((entry) => entry.kind === "tap")) {
        await $`brew tap ${tap.name}`.quiet();
        await $`brew trust --tap ${tap.name}`.quiet();
      }
    }

    const findings: Finding[] = [];
    for (const entry of entries.filter((entry) => entry.kind === "brew" || entry.kind === "cask")) {
      const finding = await brewInfo(entry);
      if (finding) findings.push(finding);
    }
    const extensions = entries.filter((entry) => entry.kind === "vscode");
    for (const id of await missingExtensions(extensions.map((entry) => entry.name))) {
      findings.push({ severity: "error", entry: { kind: "vscode", name: id }, reason: "not in the VS Code Marketplace" });
    }

    for (const finding of findings) {
      const line = `${finding.severity.toUpperCase()} ${finding.entry.kind} "${finding.entry.name}": ${finding.reason}`;
      if (process.env.GITHUB_ACTIONS) {
        console.log(`::${finding.severity} title=Brewfile::${line}`);
      } else {
        console.log(line);
      }
    }
    const errors = findings.filter((finding) => finding.severity === "error").length;
    console.log(`checked ${entries.length} entries: ${errors} errors, ${findings.length - errors} warnings`);
    if (errors > 0) process.exit(1);
  },
});

runMain(main);
