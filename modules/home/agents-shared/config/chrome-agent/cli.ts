#!/usr/bin/env bun
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { defineCommand, runMain } from "citty"
import {
  copyProfile,
  extensionTargetCount,
  killGraceful,
  launchChrome,
  procAlive,
  sessionSummary,
  sleep,
  spawnDetached,
  stripExtensions,
  waitForCdp,
} from "./chrome.ts"
import { type Config, loadConfig, runtimeProfileDir, stateDir } from "./config.ts"

type State = {
  login?: { pid: number; profile: string }
  runtime?: { chromePid: number; proxyPid: number; dir: string; port: number; proxyPort: number }
}

function statePath(): string {
  return join(stateDir(), "state.json")
}

function readState(): State {
  const p = statePath()
  if (!existsSync(p)) return {}
  try {
    return JSON.parse(readFileSync(p, "utf8")) as State
  } catch {
    return {}
  }
}

function writeState(s: State): void {
  writeFileSync(statePath(), JSON.stringify(s, null, 2))
}

function proxyScriptPath(): string {
  return join(import.meta.dir, "proxy.ts")
}

const login = defineCommand({
  meta: { name: "login", description: "Open the human login browser (1Password on, no debug port). Agent cannot attach." },
  run() {
    const cfg = loadConfig()
    const firstRun = !existsSync(cfg.loginProfile)
    if (firstRun) mkdirSync(cfg.loginProfile, { recursive: true })

    const state = readState()
    if (state.login && procAlive(state.login.pid)) {
      console.log(`Login browser already running (pid ${state.login.pid}) on ${cfg.loginProfile}.`)
      console.log("Log into the CRM, then run 'chrome-agent handoff'.")
      return
    }

    const pid = launchChrome({
      chromePath: cfg.chromePath,
      userDataDir: cfg.loginProfile,
      headless: false,
      url: cfg.crmUrl || "about:blank",
      logFile: join(stateDir(), "login.log"),
    })
    state.login = { pid, profile: cfg.loginProfile }
    writeState(state)

    console.log(`Login browser opened (pid ${pid}) on ${cfg.loginProfile}.`)
    console.log("  - 1Password is available here; there is NO debug port, so the agent cannot drive this browser.")
    if (firstRun) {
      console.log("  - First run: this is a fresh profile. Install & unlock 1Password in it once, then log into the CRM.")
    }
    if (!cfg.crmUrl) console.log("  - Tip: set \"crmUrl\" in the config so login opens straight to the CRM.")
    console.log("\nLog into the CRM, then tell me you're done — I'll run 'chrome-agent handoff'.")
  },
})

const handoff = defineCommand({
  meta: { name: "handoff", description: "Quit login browser, copy profile, strip 1Password, launch runtime browser behind the allowlist proxy." },
  run: async () => {
    const cfg = loadConfig()
    const state = readState()

    if (state.login && procAlive(state.login.pid)) {
      console.log(`Quitting login browser (pid ${state.login.pid}) to flush the session to disk...`)
      await killGraceful(state.login.pid)
    }
    delete state.login

    if (state.runtime) {
      if (procAlive(state.runtime.chromePid)) await killGraceful(state.runtime.chromePid)
      if (procAlive(state.runtime.proxyPid)) await killGraceful(state.runtime.proxyPid)
    }

    const dir = runtimeProfileDir()
    console.log(`Copying login profile -> ${dir} ...`)
    await copyProfile(cfg.loginProfile, dir)
    const removed = await stripExtensions(dir, cfg.stripExtensionIds)
    console.log(`Stripped ${removed.length} extension path(s) (${cfg.stripExtensionIds.join(", ")}).`)

    const proxyPid = spawnDetached(
      process.execPath,
      [proxyScriptPath(), "--port", String(cfg.proxyPort), "--allow", cfg.allowHosts.join(",")],
      join(stateDir(), "proxy.log"),
    )
    await sleep(400)

    const chromePid = launchChrome({
      chromePath: cfg.chromePath,
      userDataDir: dir,
      debugPort: cfg.debugPort,
      disableExtensions: true,
      proxyPort: cfg.proxyPort,
      headless: cfg.headless,
      url: cfg.crmUrl || "about:blank",
      logFile: join(stateDir(), "runtime.log"),
    })

    const browser = await waitForCdp(cfg.debugPort)
    const extCount = await extensionTargetCount(cfg.debugPort)

    state.runtime = { chromePid, proxyPid, dir, port: cfg.debugPort, proxyPort: cfg.proxyPort }
    writeState(state)

    console.log(`\nRuntime browser ready: ${browser}`)
    console.log(`  - CDP:        http://127.0.0.1:${cfg.debugPort}  (chrome-devtools MCP attaches here)`)
    console.log(`  - Extensions: ${extCount} target(s) — ${extCount === 0 ? "1Password absent ✓" : "WARNING: extensions still present!"}`)
    console.log(`  - Proxy:      127.0.0.1:${cfg.proxyPort}, allow=[${cfg.allowHosts.join(", ")}] (pid ${proxyPid})`)
    try {
      const s = await sessionSummary(cfg.debugPort, cfg.crmHosts)
      const crm = cfg.crmHosts.length ? `, CRM hosts present: [${s.crmPresent.join(", ") || "none"}]` : ""
      console.log(`  - Session:    ${s.cookies} cookies across ${s.domains} domains${crm}`)
    } catch {
      // session summary is best-effort
    }
    console.log("\nThe agent's browser carries the session, not the vault. Run 'chrome-agent down' when finished.")
  },
})

const down = defineCommand({
  meta: { name: "down", description: "Tear down the runtime browser and proxy, remove the temp profile copy." },
  run: async () => {
    const state = readState()
    if (!state.runtime) {
      console.log("No runtime browser tracked.")
      return
    }
    const { chromePid, proxyPid, dir } = state.runtime
    if (procAlive(chromePid)) await killGraceful(chromePid)
    if (procAlive(proxyPid)) await killGraceful(proxyPid)
    rmSync(dir, { recursive: true, force: true })
    delete state.runtime
    writeState(state)
    console.log("Runtime browser + proxy stopped, temp profile removed.")
  },
})

const status = defineCommand({
  meta: { name: "status", description: "Show login / runtime / proxy state." },
  run: async () => {
    const cfg = loadConfig()
    const state = readState()
    const loginUp = state.login ? procAlive(state.login.pid) : false
    const chromeUp = state.runtime ? procAlive(state.runtime.chromePid) : false
    const proxyUp = state.runtime ? procAlive(state.runtime.proxyPid) : false
    console.log(`login browser:   ${loginUp ? `up (pid ${state.login!.pid})` : "down"}`)
    console.log(`runtime browser: ${chromeUp ? `up (pid ${state.runtime!.chromePid}, :${state.runtime!.port})` : "down"}`)
    console.log(`allowlist proxy: ${proxyUp ? `up (pid ${state.runtime!.proxyPid}, :${state.runtime!.proxyPort})` : "down"}`)
    console.log(`allowHosts:      [${cfg.allowHosts.join(", ")}]`)
    console.log(`loginProfile:    ${cfg.loginProfile}`)
    if (chromeUp) {
      try {
        const browser = await waitForCdp(cfg.debugPort, 2000)
        const extCount = await extensionTargetCount(cfg.debugPort)
        console.log(`CDP:             ${browser}, extension targets: ${extCount}`)
      } catch {
        console.log("CDP:             not answering")
      }
    }
  },
})

const main = defineCommand({
  meta: {
    name: "chrome-agent",
    description: "Gated Chrome for the agent: human logs in with 1Password, then the agent gets a copy with the session but no password manager.",
  },
  subCommands: { login, handoff, down, status },
})

runMain(main)
