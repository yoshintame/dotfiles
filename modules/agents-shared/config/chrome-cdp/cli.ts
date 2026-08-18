#!/usr/bin/env bun
import { spawn } from "node:child_process"
import { existsSync, mkdirSync, openSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import { defineCommand, runMain } from "citty"

type Config = {
  profile: string
  chromePath: string
  port: number
  url: string
  headless: boolean
}

const DEFAULTS: Config = {
  profile: join(dataHome(), "chrome-cdp", "profile"),
  chromePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  port: 9222,
  url: "",
  headless: false,
}

function dataHome(): string {
  return process.env.XDG_DATA_HOME ?? join(homedir(), ".local", "share")
}
function configHome(): string {
  return process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config")
}
function stateDir(): string {
  const d = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"), "chrome-cdp")
  if (!existsSync(d)) mkdirSync(d, { recursive: true })
  return d
}
function expandHome(p: string): string {
  if (p === "~") return homedir()
  if (p.startsWith("~/")) return join(homedir(), p.slice(2))
  return p
}

function loadConfig(): Config {
  const path = join(configHome(), "chrome-cdp", "config.json")
  let user: Partial<Config> = {}
  if (existsSync(path)) {
    try {
      user = JSON.parse(readFileSync(path, "utf8")) as Partial<Config>
    } catch (e) {
      throw new Error(`chrome-cdp: bad config at ${path}: ${(e as Error).message}`)
    }
  }
  const c = { ...DEFAULTS, ...user }
  c.profile = expandHome(c.profile)
  return c
}

function statePath(): string {
  return join(stateDir(), "state.json")
}
function readPid(): number | null {
  if (!existsSync(statePath())) return null
  try {
    return (JSON.parse(readFileSync(statePath(), "utf8")) as { pid?: number }).pid ?? null
  } catch {
    return null
  }
}
function writePid(pid: number | null): void {
  writeFileSync(statePath(), JSON.stringify({ pid }, null, 2))
}
function alive(pid: number): boolean {
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}
function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}

async function cdpBrowser(port: number, timeoutMs = 0): Promise<string | null> {
  const deadline = Date.now() + timeoutMs
  do {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`)
      if (res.ok) return ((await res.json()) as { Browser?: string }).Browser ?? "Chrome"
    } catch {
      // not up yet
    }
    if (timeoutMs > 0) await sleep(250)
  } while (Date.now() < deadline)
  return null
}

const up = defineCommand({
  meta: { name: "up", description: "Launch (or reuse) a CDP Chrome on the debug port for chrome-devtools MCP to attach." },
  args: {
    profile: { type: "string", description: "override user-data-dir" },
    url: { type: "string", description: "URL to open (triggers dev autologin)" },
    port: { type: "string", description: "debug port (default 9222)" },
    headless: { type: "boolean", description: "run headless" },
  },
  run: async ({ args }) => {
    const cfg = loadConfig()
    const port = args.port ? Number(args.port) : cfg.port
    const profile = args.profile ? expandHome(String(args.profile)) : cfg.profile
    const url = args.url ? String(args.url) : cfg.url

    const existing = await cdpBrowser(port)
    if (existing) {
      console.log(`Already up: ${existing} on http://127.0.0.1:${port} — MCP can attach.`)
      return
    }

    mkdirSync(profile, { recursive: true })
    const chromeArgs = [
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${profile}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--hide-crash-restore-bubble",
    ]
    if (args.headless ?? cfg.headless) chromeArgs.push("--headless=new")
    chromeArgs.push(url || "about:blank")

    const log = openSync(join(stateDir(), "chrome.log"), "a")
    const child = spawn(cfg.chromePath, chromeArgs, { detached: true, stdio: ["ignore", log, log] })
    child.unref()
    if (typeof child.pid !== "number") throw new Error("chrome-cdp: failed to launch Chrome")

    const browser = await cdpBrowser(port, 15000)
    if (!browser) {
      throw new Error(
        `chrome-cdp: launched Chrome (pid ${child.pid}) but :${port} never answered. ` +
          `If run from an agent's sandboxed shell, retry unsandboxed (Chrome's crashpad needs it). Log: ${join(stateDir(), "chrome.log")}`,
      )
    }
    writePid(child.pid)
    console.log(`Up: ${browser} on http://127.0.0.1:${port} (pid ${child.pid}, profile ${profile})`)
    console.log("chrome-devtools MCP attaches via --browser-url=http://127.0.0.1:" + port + ". Run 'chrome-cdp down' to stop.")
  },
})

const down = defineCommand({
  meta: { name: "down", description: "Stop the Chrome that chrome-cdp launched (leaves any other Chrome alone)." },
  run: () => {
    const pid = readPid()
    if (pid && alive(pid)) {
      try {
        process.kill(pid, "SIGTERM")
      } catch {
        // already gone
      }
      writePid(null)
      console.log(`Stopped Chrome (pid ${pid}).`)
    } else {
      console.log("No chrome-cdp Chrome tracked as running.")
      writePid(null)
    }
  },
})

const status = defineCommand({
  meta: { name: "status", description: "Report whether a CDP Chrome is reachable on the debug port." },
  args: { port: { type: "string" } },
  run: async ({ args }) => {
    const cfg = loadConfig()
    const port = args.port ? Number(args.port) : cfg.port
    const browser = await cdpBrowser(port)
    const pid = readPid()
    console.log(`port :${port}: ${browser ? `UP (${browser})` : "down"}`)
    console.log(`tracked pid: ${pid && alive(pid) ? pid : "none"}`)
    console.log(`profile: ${cfg.profile}`)
  },
})

runMain(
  defineCommand({
    meta: {
      name: "chrome-cdp",
      description: "Reliable on-demand CDP Chrome for chrome-devtools MCP. Launch once; the MCP attaches to :9222.",
    },
    subCommands: { up, down, status },
  }),
)
