import { KeyCode, type KeyName } from "./keycodes.ts";
import type { ModifierName } from "./modifiers.ts";

const PredefinedActionType = {
  SendKeyboardShortcut: 264,
  VolumeUp: 24,
  VolumeDown: 25,
  MiddleClick: 1,
} as const;

const ModifierKeyCode = {
  cmd: 55,
  shift: 56,
  alt: 58,
  ctrl: 59,
  fn: 63,
} as const satisfies Record<ModifierName, number>;

interface BttActionJson {
  BTTPredefinedActionType: number;
  BTTPredefinedActionName?: string;
  BTTShortcutToSend?: string;
}

export type Action =
  | { kind: "keystroke"; key: KeyName; mods?: readonly ModifierName[] }
  | { kind: "volume-up" }
  | { kind: "volume-down" }
  | { kind: "middle-click" };

function buildShortcutCsv(key: KeyName, mods: readonly ModifierName[]): string {
  const parts: number[] = mods.map((m) => ModifierKeyCode[m]);
  parts.push(KeyCode[key]);
  return parts.join(",");
}

export function buildAction(action: Action): BttActionJson {
  switch (action.kind) {
    case "keystroke":
      return {
        BTTPredefinedActionType: PredefinedActionType.SendKeyboardShortcut,
        BTTPredefinedActionName: "Send Keyboard Shortcut",
        BTTShortcutToSend: buildShortcutCsv(action.key, action.mods ?? []),
      };
    case "volume-up":
      return {
        BTTPredefinedActionType: PredefinedActionType.VolumeUp,
        BTTPredefinedActionName: "Volume Up",
      };
    case "volume-down":
      return {
        BTTPredefinedActionType: PredefinedActionType.VolumeDown,
        BTTPredefinedActionName: "Volume Down",
      };
    case "middle-click":
      return {
        BTTPredefinedActionType: PredefinedActionType.MiddleClick,
        BTTPredefinedActionName: "Middle Click (At Current Mouse Position)",
      };
  }
}
