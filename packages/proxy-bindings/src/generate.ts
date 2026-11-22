import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { type Config, readConfig } from "./config.ts";
import { generateLua } from "./generators/lua.ts";
import { generateTypeScript } from "./generators/typescript.ts";

type Generator = (bindings: Record<string, string>, sourcePath: string) => string;

const generators: Record<string, Generator> = {
  lua: generateLua,
  typescript: generateTypeScript,
};

function expandHome(filePath: string) {
  return filePath.startsWith("~/") ? path.join(os.homedir(), filePath.slice(2)) : filePath;
}

function writeOutput(filePath: string, content: string) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir);
  fs.writeFileSync(filePath, content);
}

export function generate(configPath: string) {
  const config: Config = readConfig(configPath);
  const configDir = path.dirname(configPath);
  const relSource = path.relative(process.cwd(), configPath);

  for (const [format, outputPath] of Object.entries(config.outputs)) {
    const gen = generators[format];
    if (!gen) {
      console.error(`Unknown output format: ${format}`);
      process.exit(1);
    }

    const absPath = path.resolve(configDir, expandHome(outputPath));
    writeOutput(absPath, gen(config.bindings, relSource));
    console.log(`  ${format} → ${path.relative(process.cwd(), absPath)}`);
  }
}
