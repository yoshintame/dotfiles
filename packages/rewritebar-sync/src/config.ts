import fs from "node:fs";
import path from "node:path";

import YAML from "yaml";
import { z } from "zod";

import { type Shortcut, toShortcut } from "./shortcut.ts";

const ConfigSchema = z.object({
  proxyBindings: z.string().min(1),
  commands: z.record(
    z.string().regex(/^[a-z0-9-]+$/),
    z.object({
      id: z.uuid(),
      name: z.string().min(1),
      binding: z.string().min(1).optional(),
    }),
  ),
});

const ProxyBindingsSchema = z.object({
  bindings: z.record(z.string(), z.string()),
});

export type Command = {
  id: string;
  name: string;
  slug: string;
  content: string;
  chord: string;
  shortcut: Shortcut;
};

export function readConfig(configPath: string): Command[] {
  const dir = path.dirname(configPath);
  const config = ConfigSchema.parse(YAML.parse(fs.readFileSync(configPath, "utf-8")));
  const { bindings } = ProxyBindingsSchema.parse(
    YAML.parse(fs.readFileSync(path.resolve(dir, config.proxyBindings), "utf-8")),
  );

  return Object.entries(config.commands).map(([slug, command]) => {
    const binding = command.binding ?? slug;
    const chord = bindings[binding];
    if (chord === undefined) {
      throw new Error(`${command.name}: proxy binding "${binding}" not found in ${config.proxyBindings}`);
    }
    return {
      id: command.id.toUpperCase(),
      name: command.name,
      slug,
      content: fs.readFileSync(path.join(dir, "prompts", `${slug}.md`), "utf-8").trimEnd(),
      chord,
      shortcut: toShortcut(chord),
    };
  });
}
