import $ from "dax-sh";
import plist from "plist";
import { z } from "zod";

import { type Shortcut, ShortcutSchema } from "./shortcut.ts";

const DOMAIN = "com.m91michel.rewritebar";
const PROCESS = "RewriteBar";
const PROMPTS_KEY = "customPrompts2";
const SHORTCUT_PREFIX = "KeyboardShortcuts_";
const QUIT_TIMEOUT_MS = 10_000;

const PromptSchema = z.looseObject({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  category: z.string(),
  content: z.string(),
});

export type Prompt = z.infer<typeof PromptSchema>;

export type Preferences = {
  prompts: Prompt[];
  shortcuts: Map<string, Shortcut>;
};

function parseShortcut(raw: unknown): Shortcut | undefined {
  if (typeof raw !== "string") return undefined;
  try {
    const parsed = ShortcutSchema.safeParse(JSON.parse(raw));
    return parsed.success ? parsed.data : undefined;
  } catch {
    return undefined;
  }
}

export async function readPreferences(): Promise<Preferences> {
  const values = plist.parse(await $`defaults export ${DOMAIN} -`.text()) as Record<string, unknown>;

  const blob = values[PROMPTS_KEY];
  if (!(blob instanceof Buffer)) throw new Error(`${DOMAIN}: ${PROMPTS_KEY} is missing or not data`);
  const prompts = z.array(PromptSchema).parse(JSON.parse(blob.toString("utf-8")));

  const shortcuts = new Map<string, Shortcut>();
  for (const [key, raw] of Object.entries(values)) {
    if (!key.startsWith(SHORTCUT_PREFIX)) continue;
    const shortcut = parseShortcut(raw);
    if (shortcut) shortcuts.set(key.slice(SHORTCUT_PREFIX.length), shortcut);
  }

  return { prompts, shortcuts };
}

export async function writePrompts(prompts: Prompt[]): Promise<void> {
  const hex = Buffer.from(JSON.stringify(prompts), "utf-8").toString("hex");
  await $`defaults write ${DOMAIN} ${PROMPTS_KEY} -data ${hex}`;
}

export async function writeShortcut(id: string, shortcut: Shortcut): Promise<void> {
  await $`defaults write ${DOMAIN} ${SHORTCUT_PREFIX + id} -string ${JSON.stringify(shortcut)}`;
}

export async function isRunning(): Promise<boolean> {
  return (await $`pgrep -x ${PROCESS}`.noThrow().quiet()).code === 0;
}

export async function quit(): Promise<void> {
  await $`osascript -e ${`quit app id "${DOMAIN}"`}`.quiet();
  const deadline = Date.now() + QUIT_TIMEOUT_MS;
  while (await isRunning()) {
    if (Date.now() > deadline) throw new Error(`${PROCESS} did not quit within ${QUIT_TIMEOUT_MS / 1000}s`);
    await $.sleep(200);
  }
}

export async function launch(): Promise<void> {
  await $`open -g -b ${DOMAIN}`;
}
