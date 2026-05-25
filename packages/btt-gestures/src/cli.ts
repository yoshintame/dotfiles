#!/usr/bin/env bun

import fs from "node:fs";
import { parseArgs } from "node:util";

import { readConfig, resolveConfigPath } from "./config.ts";
import { buildTrigger } from "./codegen.ts";
import { applySync, planSync } from "./sync.ts";
import { gestureUuid } from "./gesture-uuid.ts";

const HELP = `
btt-gestures — sync trackpad gestures from YAML to BetterTouchTool via its REST API.

Usage:
  btt-gestures sync   [-c <config>]    apply YAML state to BTT (upsert + delete stale)
  btt-gestures diff   [-c <config>]    show what sync would do, change nothing
  btt-gestures dump   [-c <config>]    print generated BTT trigger JSON

Options:
  -c, --config <path>   path to btt-gestures.yaml (default: auto-discover)
  -h, --help            show this help

Environment:
  BTT_WEBSERVER_SHARED_SECRET   shared secret from BTT → Preferences → Advanced → Webserver
                                (read from \$XDG_RUNTIME_DIR or \$HOME/.config/sops-nix/secrets/
                                if unset)
`.trimStart();

function getSharedSecret(): string | undefined {
  const fromEnv = process.env["BTT_WEBSERVER_SHARED_SECRET"];
  if (fromEnv && fromEnv.trim()) return fromEnv.trim();

  const sopsPath = `${process.env["HOME"]}/.config/sops-nix/secrets/BTT_WEBSERVER_SHARED_SECRET`;
  if (fs.existsSync(sopsPath)) return fs.readFileSync(sopsPath, "utf-8").trim();

  return undefined;
}

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    config: { type: "string", short: "c" },
    help: { type: "boolean", short: "h" },
  },
});

const command = positionals[0];

if (values.help || !command) {
  console.log(HELP);
  process.exit(command ? 0 : 1);
}

const config = readConfig(resolveConfigPath(values.config));

if (command === "dump") {
  for (const gesture of config.gestures) {
    console.log(JSON.stringify({ uuid: gestureUuid(gesture.id), ...buildTrigger(gesture, { preset: config.preset }) }, null, 2));
  }
} else if (command === "diff") {
  const plan = await planSync(config, getSharedSecret());
  console.log(`Plan:`);
  console.log(`  upsert (${plan.upsert.length}):`);
  for (const u of plan.upsert) console.log(`    + ${u.id} (${u.trigger})`);
  console.log(`  delete (${plan.delete.length}):`);
  for (const d of plan.delete) console.log(`    - ${d.description}`);
} else if (command === "sync") {
  await applySync(config, getSharedSecret());
} else {
  console.error(`Unknown command: ${command}`);
  process.exit(1);
}
