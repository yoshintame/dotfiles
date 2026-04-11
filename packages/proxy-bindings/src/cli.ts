#!/usr/bin/env bun

import { parseArgs } from "node:util";

import { generate } from "./generate.ts";
import { resolveConfig } from "./config.ts";

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    config: { type: "string", short: "c" },
    help: { type: "boolean", short: "h" },
  },
});

const command = positionals[0];

if (values.help || !command) {
  console.log(`
  proxy-bindings — generate typed keybinding files from a shared YAML config.

  Usage:
    proxy-bindings generate [-c <config>]

  Options:
    -c, --config <path>   Path to YAML config (default: auto-discover)
    -h, --help            Show this help

  Config discovery:
    Walks up from cwd looking for proxy-bindings.yaml
`.trimStart());
  process.exit(command ? 0 : 1);
}

if (command === "generate") {
  const configPath = resolveConfig(values.config);
  generate(configPath);
} else {
  console.error(`Unknown command: ${command}`);
  process.exit(1);
}
