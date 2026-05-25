import fs from "node:fs";
import path from "node:path";

import YAML from "yaml";

import { ConfigSchema, type Config } from "./schema.ts";

const CONFIG_NAME = "btt-gestures.yaml";

function discover(from: string): string | null {
  let dir = path.resolve(from);
  while (true) {
    const candidate = path.join(dir, CONFIG_NAME);
    if (fs.existsSync(candidate)) return candidate;
    const parent = path.dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

export function resolveConfigPath(explicit?: string): string {
  if (explicit) {
    const resolved = path.resolve(explicit);
    if (!fs.existsSync(resolved)) {
      console.error(`Config not found: ${resolved}`);
      process.exit(1);
    }
    return resolved;
  }
  const found = discover(process.cwd());
  if (!found) {
    console.error(`No ${CONFIG_NAME} found (searched upward from ${process.cwd()})`);
    process.exit(1);
  }
  return found;
}

export function readConfig(configPath: string): Config {
  const raw = fs.readFileSync(configPath, "utf-8");
  const parsed = YAML.parse(raw);
  return ConfigSchema.parse(parsed);
}
