import { KeyCode, type KeyName } from "./keycodes.ts";
import type { ModifierName } from "./modifiers.ts";

const PredefinedActionType = {
  SendKeyboardShortcut: 264,
  VolumeUp: 24,
  VolumeDown: 25,
  MiddleClick: 1,
  RunCoreJavaScript: 281,
  AppleScript: 195,
  ShellScript: 206,
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
  BTTAdditionalActionData?: Record<string, unknown>;
  BTTGenericActionConfig?: string;
  BTTInlineAppleScript?: string;
  BTTShellTaskActionScript?: string;
  BTTShellTaskActionConfig?: string;
}

export function buildSoundAction(sound: string): BttActionJson {
  return {
    BTTPredefinedActionType: PredefinedActionType.ShellScript,
    BTTPredefinedActionName: "Execute Shell Script  or  Task",
    BTTShellTaskActionScript: `(afplay /System/Library/Sounds/${sound}.aiff &) >/dev/null 2>&1`,
    BTTShellTaskActionConfig: "/bin/bash",
  };
}

export interface FloatingMenuItem {
  title: string;
  icon?: string;
  url?: string;
  app?: string;
  shortcut?: string;
}

export type Action =
  | { kind: "keystroke"; key: KeyName; mods?: readonly ModifierName[] }
  | { kind: "volume-up" }
  | { kind: "volume-down" }
  | { kind: "middle-click" }
  | { kind: "floating-menu"; items: readonly FloatingMenuItem[] };

function buildShortcutCsv(key: KeyName, mods: readonly ModifierName[]): string {
  const parts: number[] = mods.map((m) => ModifierKeyCode[m]);
  parts.push(KeyCode[key]);
  return parts.join(",");
}

function buildItemAction(item: FloatingMenuItem): Record<string, string> | string {
  if (item.url) return { js: `runShellScript({script: 'open "${item.url}"'});` };
  if (item.app) return { js: `runShellScript({script: 'open "${item.app}"'});` };
  if (item.shortcut) return `shortcut::${item.shortcut}`;
  throw new Error(`floating-menu item "${item.title}" missing url/app/shortcut`);
}

function defaultIcon(item: FloatingMenuItem): string {
  if (item.icon) return item.icon;
  if (item.url) return "sfsymbol::globe";
  if (item.app) return "sfsymbol::app.fill";
  return "sfsymbol::star";
}

function buildFloatingMenuScript(items: readonly FloatingMenuItem[]): string {
  const renderedItems = items.map((it) => ({
    title: it.title,
    icon: defaultIcon(it),
    action: buildItemAction(it),
  }));
  const itemsJson = JSON.stringify(renderedItems);
  return `async function generateMenu() {\n  return JSON.stringify({ type: "floatingmenu", items: ${itemsJson} });\n}`;
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
    case "floating-menu": {
      const script = buildFloatingMenuScript(action.items);
      return {
        BTTPredefinedActionType: PredefinedActionType.RunCoreJavaScript,
        BTTPredefinedActionName: "Run Real JavaScript",
        BTTGenericActionConfig: script,
        BTTAdditionalActionData: {
          BTTScriptFunctionToCall: "generateMenu",
          BTTJavaScriptUseIsolatedContext: false,
          BTTAppleScriptRunInBackground: false,
          BTTScriptType: 3,
          BTTActionJSRunInSeparateContext: false,
          BTTScriptString: script,
          BTTAppleScriptUsePath: false,
          BTTScriptLocation: 0,
        },
      };
    }
  }
}
