import type { Command } from "./config.ts";
import type { Preferences, Prompt } from "./rewritebar.ts";
import { shortcutId } from "./shortcut.ts";

const FIELDS = ["name", "slug", "content"] as const;

export type PromptChange = { command: Command; kind: "create" | "update"; fields: string[] };

export type Plan = {
  prompts: Prompt[];
  promptChanges: PromptChange[];
  shortcutChanges: Command[];
  conflicts: Array<{ command: Command; others: string[] }>;
};

export const isEmpty = (plan: Plan) => plan.promptChanges.length === 0 && plan.shortcutChanges.length === 0;

export function plan(commands: Command[], preferences: Preferences): Plan {
  const prompts = [...preferences.prompts];
  const promptChanges: PromptChange[] = [];
  const shortcutChanges: Command[] = [];
  const shortcuts = new Map(preferences.shortcuts);

  for (const command of commands) {
    const desired = { name: command.name, slug: command.slug, content: command.content };
    const index = prompts.findIndex((prompt) => prompt.id.toUpperCase() === command.id);
    const current = prompts[index];

    if (current === undefined) {
      prompts.push({ id: command.id, category: "customAction", hasCustomName: true, ...desired });
      promptChanges.push({ command, kind: "create", fields: [...FIELDS] });
    } else {
      const fields = FIELDS.filter((field) => current[field] !== desired[field]);
      if (fields.length > 0) {
        prompts[index] = { ...current, ...desired, hasCustomName: true };
        promptChanges.push({ command, kind: "update", fields });
      }
    }

    const existing = shortcuts.get(command.id);
    if (existing === undefined || shortcutId(existing) !== shortcutId(command.shortcut)) {
      shortcutChanges.push(command);
    }
    shortcuts.set(command.id, command.shortcut);
  }

  const conflicts = commands.flatMap((command) => {
    const others = [...shortcuts]
      .filter(([id, shortcut]) => id !== command.id && shortcutId(shortcut) === shortcutId(command.shortcut))
      .map(([id]) => commands.find((other) => other.id === id)?.name ?? id);
    return others.length > 0 ? [{ command, others }] : [];
  });

  return { prompts, promptChanges, shortcutChanges, conflicts };
}
