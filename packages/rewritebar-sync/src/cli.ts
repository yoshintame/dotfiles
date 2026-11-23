#!/usr/bin/env bun

import path from "node:path";

import { defineCommand, runMain } from "citty";

import { type Command, readConfig } from "./config.ts";
import { isEmpty, type Plan, plan } from "./plan.ts";
import { isRunning, launch, quit, readPreferences, writePrompts, writeShortcut } from "./rewritebar.ts";

function report(result: Plan): void {
  for (const change of result.promptChanges) {
    const detail = change.kind === "create" ? "create" : `update ${change.fields.join(", ")}`;
    console.log(`prompt   ${change.command.name}: ${detail}`);
  }
  for (const command of result.shortcutChanges) console.log(`shortcut ${command.name}: ${command.chord}`);
  for (const { command, others } of result.conflicts) {
    console.error(`conflict ${command.name}: ${command.chord} is also bound to ${others.join(", ")}`);
  }
}

async function apply(commands: Command[]): Promise<void> {
  const wasRunning = await isRunning();
  if (wasRunning) await quit();
  try {
    const fresh = plan(commands, await readPreferences());
    if (fresh.conflicts.length > 0) throw new Error("shortcut conflicts appeared after RewriteBar quit");
    if (fresh.promptChanges.length > 0) await writePrompts(fresh.prompts);
    for (const command of fresh.shortcutChanges) await writeShortcut(command.id, command.shortcut);
  } finally {
    if (wasRunning) await launch();
  }
}

const main = defineCommand({
  meta: {
    name: "rewritebar-sync",
    description: "Sync RewriteBar commands and their shortcuts from YAML into its defaults domain",
  },
  args: {
    config: { type: "string", alias: "c", description: "path to rewritebar.yaml", required: true },
    "dry-run": { type: "boolean", description: "print the plan without quitting RewriteBar or writing" },
  },
  async run({ args }) {
    const commands = readConfig(path.resolve(args.config));
    const result = plan(commands, await readPreferences());
    report(result);

    if (result.conflicts.length > 0) {
      process.exitCode = 1;
      return;
    }
    if (isEmpty(result)) {
      console.log("RewriteBar is up to date");
      return;
    }
    if (args["dry-run"]) return;

    await apply(commands);
    console.log("RewriteBar synced");
  },
});

await runMain(main);
