import { z } from "zod";

import { KeyCode } from "./keycodes.ts";
import { Modifier } from "./modifiers.ts";
import { Trigger } from "./triggers.ts";

const KeyNameSchema = z.enum(Object.keys(KeyCode) as [keyof typeof KeyCode, ...(keyof typeof KeyCode)[]]);
const ModifierNameSchema = z.enum(Object.keys(Modifier) as [keyof typeof Modifier, ...(keyof typeof Modifier)[]]);
const TriggerNameSchema = z.enum(Object.keys(Trigger) as [keyof typeof Trigger, ...(keyof typeof Trigger)[]]);

const FloatingMenuItemSchema = z
  .object({
    title: z.string().min(1),
    icon: z.string().optional(),
    url: z.string().url().optional(),
    app: z.string().optional(),
    shortcut: z.string().optional(),
  })
  .refine((v) => Boolean(v.url || v.app || v.shortcut), {
    message: "item must have one of: url, app, shortcut",
  });

const ActionSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("keystroke"), key: KeyNameSchema, mods: z.array(ModifierNameSchema).optional() }),
  z.object({ kind: z.literal("volume-up") }),
  z.object({ kind: z.literal("volume-down") }),
  z.object({ kind: z.literal("middle-click") }),
  z.object({ kind: z.literal("floating-menu"), items: z.array(FloatingMenuItemSchema).min(1) }),
]);

const GestureSchema = z.object({
  id: z.string().min(1),
  trigger: TriggerNameSchema,
  action: ActionSchema,
  sound: z.string().optional(),
  app: z.string().optional(),
});

export const ConfigSchema = z.object({
  webserver: z.object({
    url: z.string().url(),
  }),
  preset: z.string().optional(),
  feedback: z.object({ sound: z.string() }).optional(),
  gestures: z.array(GestureSchema),
});

export type Config = z.infer<typeof ConfigSchema>;
export type Gesture = z.infer<typeof GestureSchema>;
