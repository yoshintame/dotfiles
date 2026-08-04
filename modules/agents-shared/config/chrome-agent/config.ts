import { existsSync, mkdirSync, readFileSync } from "node:fs"
import { homedir, tmpdir } from "node:os"
import { dirname, join } from "node:path"

export const ONEPASSWORD_EXTENSION_ID = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"

export type Config = {
  loginProfile: string
  chromePath: string
  debugPort: number
  proxyPort: number
  headless: boolean
  crmUrl: string
  allowHosts: string[]
  stripExtensionIds: string[]
  crmHosts: string[]
}

const DEFAULTS: Config = {
  loginProfile: join(homedir(), "chrome-agent-login"),
  chromePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  debugPort: 9222,
  proxyPort: 18119,
  headless: false,
  crmUrl: "",
  allowHosts: ["localhost", "127.0.0.1"],
  stripExtensionIds: [ONEPASSWORD_EXTENSION_ID],
  crmHosts: [],
}

export function expandHome(p: string): string {
  if (p === "~") return homedir()
  if (p.startsWith("~/")) return join(homedir(), p.slice(2))
  return p
}

export function configPath(): string {
  const base = process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config")
  return join(base, "chrome-agent", "config.json")
}

export function stateDir(): string {
  const base = process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state")
  const dir = join(base, "chrome-agent")
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
  return dir
}

export function runtimeProfileDir(): string {
  return join(tmpdir(), "chrome-agent-runtime")
}

export function loadConfig(): Config {
  const path = configPath()
  let user: Partial<Config> = {}
  if (existsSync(path)) {
    try {
      user = JSON.parse(readFileSync(path, "utf8")) as Partial<Config>
    } catch (e) {
      throw new Error(`chrome-agent: invalid config at ${path}: ${(e as Error).message}`)
    }
  }
  const merged: Config = { ...DEFAULTS, ...user }
  merged.loginProfile = expandHome(merged.loginProfile)
  merged.allowHosts = dedupe([...DEFAULTS.allowHosts, ...(user.allowHosts ?? [])])
  merged.stripExtensionIds = dedupe([...DEFAULTS.stripExtensionIds, ...(user.stripExtensionIds ?? [])])
  return merged
}

function dedupe(xs: string[]): string[] {
  return [...new Set(xs.map((x) => x.trim()).filter(Boolean))]
}

export function ensureParentDir(filePath: string): void {
  const dir = dirname(filePath)
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true })
}
