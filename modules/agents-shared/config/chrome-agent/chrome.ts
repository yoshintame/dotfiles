import { spawn } from "node:child_process"
import { existsSync, openSync, rmSync } from "node:fs"
import { join } from "node:path"
import $ from "dax-sh"

$.setPrintCommand(false)

export function procAlive(pid: number): boolean {
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}

export async function killGraceful(pid: number, timeoutMs = 8000): Promise<void> {
  if (!procAlive(pid)) return
  try {
    process.kill(pid, "SIGTERM")
  } catch {
    return
  }
  const start = Date.now()
  while (Date.now() - start < timeoutMs) {
    if (!procAlive(pid)) return
    await sleep(150)
  }
  try {
    process.kill(pid, "SIGKILL")
  } catch {
    // already gone
  }
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}

export async function copyProfile(srcUserDataDir: string, dstUserDataDir: string): Promise<void> {
  rmSync(dstUserDataDir, { recursive: true, force: true })
  await $`mkdir -p ${dstUserDataDir}`
  const srcDefault = join(srcUserDataDir, "Default")
  if (!existsSync(srcDefault)) {
    throw new Error(`chrome-agent: login profile has no Default/ at ${srcUserDataDir} — run 'chrome-agent login' and sign in first`)
  }
  await $`cp -R ${srcDefault} ${join(dstUserDataDir, "Default")}`
  const localState = join(srcUserDataDir, "Local State")
  if (existsSync(localState)) await $`cp ${localState} ${join(dstUserDataDir, "Local State")}`
  rmSync(join(dstUserDataDir, "Default", "Local Storage", "leveldb", "LOCK"), { force: true })
  rmSync(join(dstUserDataDir, "SingletonLock"), { force: true })
}

export async function stripExtensions(userDataDir: string, ids: string[]): Promise<string[]> {
  const removed: string[] = []
  const def = join(userDataDir, "Default")
  for (const id of ids) {
    const targets = [
      join(def, "Extensions", id),
      join(def, "Local Extension Settings", id),
      join(def, "Sync Extension Settings", id),
    ]
    for (const t of targets) {
      if (existsSync(t)) {
        rmSync(t, { recursive: true, force: true })
        removed.push(t)
      }
    }
    for await (const p of new Bun.Glob(`Default/IndexedDB/chrome-extension_${id}_*`).scan({ cwd: userDataDir, absolute: true, onlyFiles: false })) {
      rmSync(p, { recursive: true, force: true })
      removed.push(p)
    }
  }
  return removed
}

export type LaunchOpts = {
  chromePath: string
  userDataDir: string
  debugPort?: number
  disableExtensions?: boolean
  proxyPort?: number
  headless?: boolean
  url?: string
  logFile: string
}

export function launchChrome(opts: LaunchOpts): number {
  const args = [
    `--user-data-dir=${opts.userDataDir}`,
    "--no-first-run",
    "--no-default-browser-check",
  ]
  if (opts.debugPort) args.push(`--remote-debugging-port=${opts.debugPort}`)
  if (opts.disableExtensions) args.push("--disable-extensions")
  if (opts.proxyPort) args.push(`--proxy-server=http://127.0.0.1:${opts.proxyPort}`)
  if (opts.headless) args.push("--headless=new")
  args.push(opts.url ?? "about:blank")

  const out = openSync(opts.logFile, "a")
  const child = spawn(opts.chromePath, args, { detached: true, stdio: ["ignore", out, out] })
  child.unref()
  if (typeof child.pid !== "number") throw new Error("chrome-agent: failed to launch Chrome")
  return child.pid
}

export function spawnDetached(cmd: string, args: string[], logFile: string): number {
  const out = openSync(logFile, "a")
  const child = spawn(cmd, args, { detached: true, stdio: ["ignore", out, out] })
  child.unref()
  if (typeof child.pid !== "number") throw new Error(`chrome-agent: failed to spawn ${cmd}`)
  return child.pid
}

export async function waitForCdp(port: number, timeoutMs = 15000): Promise<string> {
  const start = Date.now()
  let lastErr = "timeout"
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(`http://127.0.0.1:${port}/json/version`)
      if (res.ok) {
        const j = (await res.json()) as { Browser?: string }
        return j.Browser ?? "unknown"
      }
    } catch (e) {
      lastErr = (e as Error).message
    }
    await sleep(250)
  }
  throw new Error(`chrome-agent: CDP endpoint on :${port} did not come up (${lastErr})`)
}

export async function extensionTargetCount(port: number): Promise<number> {
  const res = await fetch(`http://127.0.0.1:${port}/json/list`)
  const list = (await res.json()) as Array<{ url?: string }>
  return list.filter((t) => String(t.url ?? "").startsWith("chrome-extension://")).length
}

export async function sessionSummary(port: number, crmHosts: string[]): Promise<{ cookies: number; domains: number; crmPresent: string[] }> {
  const ver = (await (await fetch(`http://127.0.0.1:${port}/json/version`)).json()) as { webSocketDebuggerUrl: string }
  const ws = new WebSocket(ver.webSocketDebuggerUrl)
  const pending = new Map<number, (v: any) => void>()
  let id = 0
  const send = (method: string, params: any = {}, sessionId?: string) =>
    new Promise<any>((resolve) => {
      const msgId = ++id
      pending.set(msgId, resolve)
      ws.send(JSON.stringify({ id: msgId, method, params, sessionId }))
    })
  await new Promise<void>((r, reject) => {
    ws.addEventListener("open", () => r())
    ws.addEventListener("error", () => reject(new Error("ws error")))
  })
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(String(ev.data))
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)!(msg)
      pending.delete(msg.id)
    }
  })
  const targets = await send("Target.getTargets")
  const page = targets.result.targetInfos.find((t: any) => t.type === "page")
  let cookies: any[] = []
  if (page) {
    const att = await send("Target.attachToTarget", { targetId: page.targetId, flatten: true })
    const sid = att.result.sessionId
    await send("Network.enable", {}, sid)
    const c = await send("Network.getAllCookies", {}, sid)
    cookies = c.result?.cookies ?? []
  }
  ws.close()
  const domains = new Set<string>(cookies.map((c) => String(c.domain).replace(/^\./, "")))
  const crmPresent = crmHosts.filter((h) => [...domains].some((d) => d === h || d.endsWith("." + h)))
  return { cookies: cookies.length, domains: domains.size, crmPresent }
}
