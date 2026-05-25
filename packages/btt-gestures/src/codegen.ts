import { buildAction } from "./actions.ts";
import { Trigger, TriggerClass } from "./triggers.ts";
import type { Gesture } from "./schema.ts";

export const MANAGED_TAG = "[managed:btt-gestures]";

export interface BttTrigger {
  BTTUUID?: string;
  BTTTriggerType: number;
  BTTTriggerClass: string;
  BTTTriggerTypeDescription: string;
  BTTEnabled: 1 | 0;
  BTTEnabled2: 1 | 0;
  BTTOrder?: number;
  BTTBelongsToApp?: string;
  BTTTriggerBelongsToPreset?: string;
  BTTActionsToExecute: ReturnType<typeof buildAction>[];
}

export interface BuildTriggerOptions {
  preset?: string;
}

export function buildTrigger(gesture: Gesture, opts: BuildTriggerOptions = {}): BttTrigger {
  return {
    BTTTriggerType: Trigger[gesture.trigger],
    BTTTriggerClass: TriggerClass.trackpad,
    BTTTriggerTypeDescription: `${MANAGED_TAG} ${gesture.id} (${gesture.trigger})`,
    BTTEnabled: 1,
    BTTEnabled2: 1,
    BTTOrder: 0,
    BTTBelongsToApp: "Global",
    ...(opts.preset ? { BTTTriggerBelongsToPreset: opts.preset } : {}),
    BTTActionsToExecute: [buildAction(gesture.action)],
  };
}
