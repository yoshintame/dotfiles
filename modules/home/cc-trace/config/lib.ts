import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

export const HOME = homedir()
export const CLAUDE_DIR = process.env.CLAUDE_CONFIG_DIR ?? join(HOME, ".claude")
export const TRACE_DIR = process.env.CC_TRACE_DIR ?? join(HOME, ".local", "state", "cc-trace")
export const BODIES_DIR = join(TRACE_DIR, "bodies")
export const SESSIONS_DIR = join(TRACE_DIR, "sessions")
export const REAPER_KILLS = join(HOME, ".local", "state", "cc-reaper", "kills.jsonl")

export type RequestBody = {
  model: string
  system?: string | Array<Record<string, any>>
  tools?: unknown[]
  messages: Array<{ role: string; content: string | Array<Record<string, any>> }>
  metadata?: { user_id?: string }
}

export type ResponseBody = { id: string; model: string; stop_reason: string; usage?: Record<string, any> }

export type Usage = { input: number; cacheRead: number; cacheCreate: number; output: number }

export type RawBlock = { label: string; value: unknown }

export type BreakMeta = {
  ts: string
  sid: string
  model: string
  prevModel: string
  breakAt: number
  prevLen: number
  nextLen: number
  label: string
  class: string
  usage: Usage
  flags: Record<string, boolean>
  prevLabels: string[]
  nextLabels: string[]
  prevHashes: string[]
  nextHashes: string[]
}

export const sha = (s: string) => createHash("sha1").update(s).digest("hex").slice(0, 16)

const stripCache = (block: Record<string, any>) => {
  const { cache_control: _omit, ...rest } = block
  return rest
}

export function walkBlocks(body: RequestBody): RawBlock[] {
  const blocks: RawBlock[] = [{ label: "tools", value: body.tools ?? [] }]
  const system = body.system
  if (typeof system === "string") blocks.push({ label: "system", value: system })
  else for (const [i, b] of (system ?? []).entries()) blocks.push({ label: `system[${i}]`, value: stripCache(b) })
  for (const [i, m] of body.messages.entries()) {
    if (typeof m.content === "string") blocks.push({ label: `msg[${i}].${m.role}`, value: m.content })
    else for (const [j, b] of m.content.entries()) blocks.push({ label: `msg[${i}].${m.role}[${j}].${b.type}`, value: stripCache(b) })
  }
  return blocks
}

export const blockHash = (b: RawBlock) => sha(typeof b.value === "string" ? b.value : JSON.stringify(b.value))

export function blockText(b: RawBlock): string {
  if (typeof b.value === "string") return b.value
  const v = b.value as Record<string, any>
  if (v?.type === "text" && typeof v.text === "string") return v.text
  return JSON.stringify(v, null, 2)
}

export function commonPrefix(a: string[], b: string[]): number {
  const n = Math.min(a.length, b.length)
  let i = 0
  while (i < n && a[i] === b[i]) i++
  return i
}

export function sessionIdOf(body: RequestBody): string | undefined {
  try {
    return JSON.parse(body.metadata?.user_id ?? "").session_id
  } catch {
    return undefined
  }
}

export function usageOf(r: ResponseBody): Usage {
  const u = r.usage ?? {}
  return {
    input: u.input_tokens ?? 0,
    cacheRead: u.cache_read_input_tokens ?? 0,
    cacheCreate: u.cache_creation_input_tokens ?? 0,
    output: u.output_tokens ?? 0,
  }
}

export const usageTotal = (u: Usage) => u.input + u.cacheRead + u.cacheCreate

export const estimateTokens = (bytes: number) => Math.round(bytes / 3.6)

export function findTranscript(sid: string): string | undefined {
  const root = join(CLAUDE_DIR, "projects")
  if (!existsSync(root)) return undefined
  for (const dir of readdirSync(root)) {
    const file = join(root, dir, `${sid}.jsonl`)
    if (existsSync(file)) return file
  }
  return undefined
}

export function ensureDir(path: string) {
  mkdirSync(path, { recursive: true, mode: 0o700 })
}

export function parseJson<T>(text: string): T | undefined {
  try {
    return JSON.parse(text)
  } catch {
    return undefined
  }
}

export function readJson<T>(path: string): T | undefined {
  try {
    return parseJson<T>(readFileSync(path, "utf8"))
  } catch {
    return undefined
  }
}

export function readJsonl(path: string): Array<Record<string, any>> {
  if (!existsSync(path)) return []
  return readFileSync(path, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((l) => parseJson<Record<string, any>>(l))
    .filter((l): l is Record<string, any> => l !== undefined)
}

export function tailLines(path: string, bytes: number): string[] {
  const size = statSync(path).size
  const start = Math.max(0, size - bytes)
  const lines = readFileSync(path).subarray(start).toString("utf8").split("\n")
  if (start > 0) lines.shift()
  return lines.filter(Boolean)
}

export function listBreaks(sid: string): BreakMeta[] {
  const dir = join(SESSIONS_DIR, sid, "breaks")
  if (!existsSync(dir)) return []
  return readdirSync(dir)
    .filter((f) => f.endsWith(".meta.json"))
    .sort()
    .map((f) => readJson<BreakMeta>(join(dir, f)))
    .filter((m): m is BreakMeta => m !== undefined)
}

export function listSessions(): string[] {
  if (!existsSync(SESSIONS_DIR)) return []
  return readdirSync(SESSIONS_DIR).filter((d) => statSync(join(SESSIONS_DIR, d)).isDirectory())
}
