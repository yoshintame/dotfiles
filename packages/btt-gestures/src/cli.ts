#!/usr/bin/env bun

import fs from "node:fs";
import { parseArgs } from "node:util";

import { readConfig, resolveConfigPath } from "./config.ts";
import { buildTrigger } from "./codegen.ts";
import { applySync, clean } from "./sync.ts";
import { gestureUuid } from "./gesture-uuid.ts";

const HELP = `
btt-gestures — sync trackpad gestures from YAML to BetterTouchTool via its REST API.

Usage:
  btt-gestures sync   [-c <config>] [--nuke-all]  delete managed triggers → add desired
                                                  --nuke-all  delete ALL trackpad triggers, including user's manual ones
  btt-gestures clean  [-c <config>] [--orphans]   delete all managed triggers
                                                  --orphans  also delete probe-action / multi-probe / TEST orphans
  btt-gestures dump   [-c <config>]               print generated BTT trigger JSON
  btt-gestures uuid <gesture-id>                  print deterministic UUID for a gesture id

Options:
  -c, --config <path>   path to btt-gestures.yaml (default: auto-discover)
  -h, --help            show this help

Environment:
  BTT_WEBSERVER_SHARED_SECRET   shared secret from BTT → Preferences → Advanced → Webserver
                                (read from \$HOME/.config/sops-nix/secrets/ if unset)
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
    orphans: { type: "boolean" },
    "nuke-all": { type: "boolean" },
  },
});

const command = positionals[0];

if (values.help || !command) {
  console.log(HELP);
  process.exit(command ? 0 : 1);
}

if (command === "uuid") {
  const id = positionals[1];
  if (!id) {
    console.error("usage: btt-gestures uuid <gesture-id>");
    process.exit(1);
  }
  console.log(gestureUuid(id));
} else {
  const config = readConfig(resolveConfigPath(values.config));

  if (command === "dump") {
    for (const gesture of config.gestures) {
      console.log(JSON.stringify({ uuid: gestureUuid(gesture.id), ...buildTrigger(gesture, { preset: config.preset, sound: config.feedback?.sound }) }, null, 2));
    }
  } else if (command === "sync") {
    await applySync(config, getSharedSecret(), { nukeAll: values["nuke-all"] === true });
  } else if (command === "clean") {
    const orphans = values.orphans === true;
    const filter = orphans
      ? (d: string | undefined) => {
          const desc = d ?? "";
          return desc.includes("managed:btt-gestures") || /probe|TEST|multi-probe/i.test(desc);
        }
      : undefined;
    const count = await clean(config, getSharedSecret(), { filter });
    console.log(`\n${count} trigger(s) removed.`);
  } else {
    console.error(`Unknown command: ${command}`);
    process.exit(1);
  }
}
