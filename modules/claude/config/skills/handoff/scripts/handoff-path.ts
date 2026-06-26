#!/usr/bin/env bun
import { mkdirSync } from "node:fs";

const slug = (process.argv[2] ?? "").trim();
if (!slug) {
  console.error("usage: handoff-path.ts <kebab-slug>");
  process.exit(1);
}

const dir = `${process.env.HOME}/.claude/handoffs/${process.cwd().replaceAll("/", "-")}`;
mkdirSync(dir, { recursive: true });
console.log(`${dir}/${slug}.md`);
