#!/usr/bin/env bun

import { parseArgs } from "node:util";
import { join } from "node:path";
import { dump } from "./dump.ts";
import { loadIgnore } from "./ignore.ts";

const { values } = parseArgs({
  options: {
    "out-dir": { type: "string", short: "o" },
    brewfile: { type: "string", short: "b" },
    "apps-dir": { type: "string", short: "a" },
    "setapp-dir": { type: "string", short: "s" },
    "ignore-file": { type: "string", short: "i" },
    help: { type: "boolean", short: "h" },
  },
});

if (values.help) {
  console.log(`
  dump-packages — detect unmanaged macOS apps and Setapp apps.

  Compares /Applications against Homebrew casks and Mac App Store
  to find apps not tracked by any package manager.

  Usage:
    dump-packages [options]

  Options:
    -o, --out-dir <path>      Output directory (default: <dotfiles>/hosts/lasthaze-mbp/packages)
    -b, --brewfile <path>     Path to Brewfile for MAS app detection
    -a, --apps-dir <path>     Applications directory (default: /Applications)
    -s, --setapp-dir <path>   Setapp directory (default: /Applications/Setapp)
    -i, --ignore-file <path>  Ignore file with app names to skip (default: <out-dir>/.appsignore)
    -h, --help                Show this help

  Ignore file format:
    One app name per line. Lines starting with # are comments.
    Example:
      # System apps
      Safari
      Simulator

  Output:
    Appsfile.setapp     — Setapp app names
    Appsfile.unmanaged  — apps not managed by brew/MAS/Setapp
`.trimStart());
  process.exit(0);
}

const dotfilesRoot = join(import.meta.dir, "../../..");
const outDir = values["out-dir"] ?? join(dotfilesRoot, "hosts/lasthaze-mbp/packages");
const brewfile = values.brewfile ?? join(outDir, "Brewfile");
const appsDir = values["apps-dir"] ?? "/Applications";
const setappDir = values["setapp-dir"] ?? "/Applications/Setapp";
const ignoreFile = values["ignore-file"] ?? join(outDir, ".appsignore");

const ignore = await loadIgnore(ignoreFile);

await dump({ outDir, brewfile, appsDir, setappDir, ignore });
