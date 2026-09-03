#!/usr/bin/env bun
import { appendFileSync, chmodSync, copyFileSync, existsSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { defineCommand, runMain } from "citty"
import {
  BODIES_DIR,
  blockHash,
  CLAUDE_DIR,
  commonPrefix,
  ensureDir,
  estimateTokens,
  findTranscript,
  parseJson,
  readJson,
  readJsonl,
  REAPER_KILLS,
  type BreakMeta,
  type RequestBody,
  type ResponseBody,
  SESSIONS_DIR,
  sessionIdOf,
  tailLines,
  TRACE_DIR,
  type Usage,
  usageOf,
  usageTotal,
  walkBlocks,
} from "./lib.ts"

const REQUEST_ORPHAN_MS = 15 * 60_000
const RESPONSE_GRACE_MS = 60_000
const TRANSCRIPT_TAIL_BYTES = 16 * 1024 * 1024
const SUBAGENT_LOOKBACK_MS = 24 * 3600_000

type Req = { file: string; mtime: number; size: number; sid?: string; body: RequestBody; paired?: boolean }
type Res = { file: string; mtime: number; reqId: string; body: ResponseBody }
type ReqIdInfo = { sid: string; sidechain: boolean; ts: number }
type State = { sid: string; model?: string; ts?: number; hashes?: string[]; labels?: string[]; requests: number; breaks: number }

const log = (msg: string) => console.log(`${new Date().toISOString()} ${msg}`)

function remove(file: string, dryRun: boolean) {
  if (!dryRun) rmSync(file, { force: true })
}

function indexTranscript(sid: string, reqIndex: Map<string, ReqIdInfo>, compactions: Map<string, number[]>, now: number) {
  const transcript = findTranscript(sid)
  if (!transcript) return
  const scan = (path: string, sidechain: boolean) => {
    for (const line of tailLines(path, TRANSCRIPT_TAIL_BYTES)) {
      const hasReq = line.includes('"requestId"')
      const hasCompact = line.includes("compact_boundary")
      if (!hasReq && !hasCompact) continue
      const d = parseJson<Record<string, any>>(line)
      if (!d) continue
      if (hasReq && typeof d.requestId === "string" && !reqIndex.has(d.requestId)) {
        reqIndex.set(d.requestId, { sid, sidechain: sidechain || d.isSidechain === true, ts: Date.parse(d.timestamp) })
      }
      if (hasCompact && d.subtype === "compact_boundary") {
        ;(compactions.get(sid) ?? compactions.set(sid, []).get(sid)!).push(Date.parse(d.timestamp))
      }
    }
  }
  scan(transcript, false)
  const subDir = join(transcript.slice(0, -".jsonl".length), "subagents")
  if (existsSync(subDir)) {
    for (const f of readdirSync(subDir)) {
      const path = join(subDir, f)
      if (f.endsWith(".jsonl") && now - statSync(path).mtimeMs < SUBAGENT_LOOKBACK_MS) scan(path, true)
    }
  }
}

function respawnBetween(sid: string, from: number, to: number): boolean {
  const dir = join(CLAUDE_DIR, "sessions")
  if (!existsSync(dir)) return false
  for (const f of readdirSync(dir)) {
    if (!f.endsWith(".json")) continue
    const e = readJson<{ sessionId?: string; startedAt?: number }>(join(dir, f))
    if (e?.sessionId === sid && typeof e.startedAt === "number" && e.startedAt > from && e.startedAt <= to) return true
  }
  return false
}

function killedBetween(sid: string, from: number, to: number): boolean {
  return readJsonl(REAPER_KILLS).some((k) => k.sid === sid && Date.parse(k.ts) > from && Date.parse(k.ts) <= to)
}

function classify(labels: string[], prevLabels: string[], breakAt: number, prevLen: number, flags: Record<string, boolean>): string {
  if (flags.model) return "model"
  const label = labels[breakAt] ?? prevLabels[breakAt] ?? ""
  if (flags.compaction) return "compaction"
  if (label === "tools") return "tools"
  if (label.startsWith("system")) return "system"
  const msgIndex = Number(label.match(/^msg\[(\d+)\]/)?.[1] ?? -1)
  if (msgIndex === 0) return "first-turn"
  if (breakAt >= prevLen - 1) return "tail"
  return "mid-history"
}

function loadState(sid: string): State {
  return readJson<State>(join(SESSIONS_DIR, sid, "last.json")) ?? { sid, requests: 0, breaks: 0 }
}

function processPair(req: Req, res: Res | undefined, state: State, compactions: number[], dryRun: boolean, verbose: boolean) {
  const sid = state.sid
  const dir = join(SESSIONS_DIR, sid)
  ensureDir(dir)
  const blocks = walkBlocks(req.body)
  const hashes = blocks.map(blockHash)
  const labels = blocks.map((b) => b.label)
  const prevHashes = state.hashes ?? []
  const prefix = commonPrefix(prevHashes, hashes)
  const isBreak = prevHashes.length > 0 && prefix < prevHashes.length
  const from = state.ts ?? 0
  const flags: Record<string, boolean> = {}
  if (state.model && state.model !== req.body.model) flags.model = true
  if (compactions.some((t) => t > from && t <= req.mtime)) flags.compaction = true
  if (respawnBetween(sid, from, req.mtime)) flags.respawn = true
  if (killedBetween(sid, from, req.mtime)) flags.killed = true
  const usage: Usage = res ? usageOf(res.body) : { input: 0, cacheRead: 0, cacheCreate: 0, output: 0 }
  const cls = isBreak ? classify(labels, state.labels ?? [], prefix, prevHashes.length, flags) : "ok"
  const ts = new Date(req.mtime).toISOString()
  const entry = {
    ts,
    model: req.body.model,
    blocks: hashes.length,
    prefix,
    prevBlocks: prevHashes.length,
    break: isBreak,
    breakAt: isBreak ? prefix : null,
    label: isBreak ? (labels[prefix] ?? state.labels?.[prefix] ?? null) : null,
    class: cls,
    usage,
    stop: res?.body.stop_reason ?? null,
    flags,
    bytes: req.size,
  }
  if (verbose || isBreak) log(`${sid.slice(0, 8)} ${cls} prefix=${prefix}/${prevHashes.length} blocks=${hashes.length} read=${usage.cacheRead} create=${usage.cacheCreate}${Object.keys(flags).length ? ` flags=${Object.keys(flags).join(",")}` : ""}`)
  if (dryRun) return

  appendFileSync(join(dir, "index.jsonl"), `${JSON.stringify(entry)}\n`)
  const last = join(dir, "last.request.json")
  if (isBreak) {
    const breaks = join(dir, "breaks")
    ensureDir(breaks)
    const stamp = ts.replace(/[:.]/g, "-")
    if (existsSync(last)) copyFileSync(last, join(breaks, `${stamp}.prev.request.json`))
    copyFileSync(req.file, join(breaks, `${stamp}.next.request.json`))
    const meta: BreakMeta = {
      ts,
      sid,
      model: req.body.model,
      prevModel: state.model ?? req.body.model,
      breakAt: prefix,
      prevLen: prevHashes.length,
      nextLen: hashes.length,
      label: String(entry.label),
      class: cls,
      usage,
      flags,
      prevLabels: state.labels ?? [],
      nextLabels: labels,
      prevHashes,
      nextHashes: hashes,
    }
    writeFileSync(join(breaks, `${stamp}.meta.json`), `${JSON.stringify(meta, null, 2)}\n`)
  }
  renameSync(req.file, last)
  if (res) rmSync(res.file, { force: true })
  const next: State = { sid, model: req.body.model, ts: req.mtime, hashes, labels, requests: state.requests + 1, breaks: state.breaks + (isBreak ? 1 : 0) }
  writeFileSync(join(dir, "last.json"), JSON.stringify(next))
  Object.assign(state, next)
}

async function compact(dryRun: boolean, verbose: boolean) {
  ensureDir(TRACE_DIR)
  ensureDir(BODIES_DIR)
  ensureDir(SESSIONS_DIR)
  for (const d of [TRACE_DIR, BODIES_DIR, SESSIONS_DIR]) chmodSync(d, 0o700)
  const now = Date.now()

  const reqs: Req[] = []
  const ress: Res[] = []
  let unparsable = 0
  for (const name of readdirSync(BODIES_DIR)) {
    const file = join(BODIES_DIR, name)
    const st = statSync(file)
    if (name.endsWith(".request.json")) {
      const body = readJson<RequestBody>(file)
      if (!body?.messages) {
        unparsable++
        if (now - st.mtimeMs > REQUEST_ORPHAN_MS) remove(file, dryRun)
        continue
      }
      reqs.push({ file, mtime: st.mtimeMs, size: st.size, sid: sessionIdOf(body), body })
    } else if (name.endsWith(".response.json")) {
      const body = readJson<ResponseBody>(file)
      if (!body?.usage) {
        unparsable++
        if (now - st.mtimeMs > REQUEST_ORPHAN_MS) remove(file, dryRun)
        continue
      }
      ress.push({ file, mtime: st.mtimeMs, reqId: name.slice(0, -".response.json".length), body })
    }
  }

  const sids = [...new Set(reqs.map((r) => r.sid).filter((s): s is string => !!s))]
  const reqIndex = new Map<string, ReqIdInfo>()
  const compactions = new Map<string, number[]>()
  for (const sid of sids) indexTranscript(sid, reqIndex, compactions, now)

  let paired = 0
  let breaks = 0
  let dropped = 0
  const consumedRes = new Set<string>()
  for (const sid of sids) {
    const state = loadState(sid)
    const candidates = reqs.filter((r) => r.sid === sid && r.mtime > (state.ts ?? 0)).sort((a, b) => a.mtime - b.mtime)
    const mainRes = ress
      .filter((r) => reqIndex.get(r.reqId)?.sid === sid && !reqIndex.get(r.reqId)?.sidechain)
      .sort((a, b) => a.mtime - b.mtime)
    let prevResMtime = 0
    for (const res of mainRes) {
      const total = usageTotal(usageOf(res.body))
      const window = candidates.filter((r) => !r.paired && r.mtime <= res.mtime && r.mtime > prevResMtime && r.body.model === res.body.model)
      if (!window.length) continue
      const scored = window.map((r) => {
        const hashes = walkBlocks(r.body).map(blockHash)
        const prefix = state.hashes ? commonPrefix(state.hashes, hashes) : 0
        return { r, prefix, delta: Math.abs(estimateTokens(r.size) - total) }
      })
      scored.sort((a, b) => b.prefix - a.prefix || a.delta - b.delta)
      const pick = scored[0].r
      pick.paired = true
      consumedRes.add(res.file)
      prevResMtime = res.mtime
      const before = state.breaks
      processPair(pick, res, state, compactions.get(sid) ?? [], dryRun, verbose)
      paired++
      if (state.breaks > before) breaks++
    }
  }

  for (const r of reqs) {
    if (r.paired) continue
    if (now - r.mtime > REQUEST_ORPHAN_MS) {
      remove(r.file, dryRun)
      dropped++
    }
  }
  for (const r of ress) {
    if (consumedRes.has(r.file)) continue
    const info = reqIndex.get(r.reqId)
    if (info?.sidechain || (!info && now - r.mtime > RESPONSE_GRACE_MS) || (info && now - r.mtime > REQUEST_ORPHAN_MS)) {
      remove(r.file, dryRun)
      dropped++
    }
  }

  const pending = reqs.filter((r) => !r.paired).length
  if (verbose || paired || breaks || dropped) {
    log(`paired=${paired} breaks=${breaks} dropped=${dropped} pending=${pending} unparsable=${unparsable} sessions=${sids.length}${dryRun ? " [dry-run]" : ""}`)
  }
}

const main = defineCommand({
  meta: {
    name: "cc-trace-compact",
    description: "Сворачивает дамп тел API-запросов Claude Code: пары запрос/ответ по сессиям, хэши префикса, разрывы кэша в архив.",
  },
  args: {
    "dry-run": { type: "boolean", default: false, description: "Ничего не писать и не удалять" },
    verbose: { type: "boolean", default: false, description: "Печатать каждую пару" },
  },
  run: ({ args }) => compact(args["dry-run"], args.verbose),
})

runMain(main)
