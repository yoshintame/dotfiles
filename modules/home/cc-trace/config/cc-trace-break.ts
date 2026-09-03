#!/usr/bin/env bun
import { existsSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { defineCommand, runMain } from "citty"
import {
  blockText,
  type BreakMeta,
  listBreaks,
  listSessions,
  readJson,
  readJsonl,
  type RequestBody,
  SESSIONS_DIR,
  walkBlocks,
} from "./lib.ts"

const DIFF_LIMIT = 120

function overview() {
  const rows = listSessions().map((sid) => {
    const index = readJsonl(join(SESSIONS_DIR, sid, "index.jsonl"))
    const breaks = index.filter((e) => e.break)
    const last = index.at(-1)
    return { sid, requests: index.length, breaks: breaks.length, lastBreak: breaks.at(-1), lastTs: last?.ts ?? "" }
  })
  rows.sort((a, b) => (a.lastTs < b.lastTs ? 1 : -1))
  if (!rows.length) {
    console.log("Нет свёрнутых сессий: компактор ещё не отработал или дамп тел выключен.")
    return
  }
  for (const r of rows) {
    const lb = r.lastBreak ? ` последний: ${r.lastBreak.ts} ${r.lastBreak.class} @${r.lastBreak.label}` : ""
    console.log(`${r.sid}  requests=${r.requests} breaks=${r.breaks}${lb}`)
  }
}

function firstLine(text: string): string {
  return text.split("\n").find((l) => l.trim())?.trim().slice(0, 100) ?? ""
}

function diffText(a: string, b: string, full: boolean): string {
  const dir = tmpdir()
  const pa = join(dir, `cc-trace-prev-${process.pid}.txt`)
  const pb = join(dir, `cc-trace-next-${process.pid}.txt`)
  writeFileSync(pa, `${a}\n`)
  writeFileSync(pb, `${b}\n`)
  const out = Bun.spawnSync(["diff", "-u", "--label", "prev", "--label", "next", pa, pb]).stdout.toString()
  const lines = out.split("\n")
  if (full || lines.length <= DIFF_LIMIT) return out
  return `${lines.slice(0, DIFF_LIMIT).join("\n")}\n… (${lines.length - DIFF_LIMIT} строк скрыто, --full)`
}

function report(sid: string, full: boolean, last: number) {
  const dir = join(SESSIONS_DIR, sid)
  if (!existsSync(dir)) {
    console.log(`Сессия ${sid} не найдена в ${SESSIONS_DIR}`)
    return
  }
  const breaks = listBreaks(sid)
  if (!breaks.length) {
    console.log(`Разрывов нет: ${sid}`)
    return
  }
  for (const meta of breaks.slice(-last)) showBreak(sid, meta, full)
}

function showBreak(sid: string, meta: BreakMeta, full: boolean) {
  const stamp = meta.ts.replace(/[:.]/g, "-")
  const prevFile = join(SESSIONS_DIR, sid, "breaks", `${stamp}.prev.request.json`)
  const nextFile = join(SESSIONS_DIR, sid, "breaks", `${stamp}.next.request.json`)
  const flags = Object.keys(meta.flags).join(",") || "-"
  console.log(`\n=== ${meta.ts}  ${sid}`)
  console.log(`class=${meta.class}  breakAt=${meta.breakAt} (${meta.label})  prev=${meta.prevLen} next=${meta.nextLen} blocks  model=${meta.model}${meta.prevModel !== meta.model ? ` (было ${meta.prevModel})` : ""}`)
  console.log(`usage: read=${meta.usage.cacheRead} create=${meta.usage.cacheCreate} input=${meta.usage.input}  flags=${flags}`)

  const prev = readJson<RequestBody>(prevFile)
  const next = readJson<RequestBody>(nextFile)
  if (!prev || !next) {
    console.log(`тела не найдены: ${prevFile} / ${nextFile}`)
    return
  }
  const prevBlocks = walkBlocks(prev)
  const nextBlocks = walkBlocks(next)
  const i = meta.breakAt
  const pb = prevBlocks[i]
  const nb = nextBlocks[i]

  if (meta.class === "first-turn" || meta.class === "compaction") {
    console.log("\nблоки первого хода (prev → next):")
    const n = Math.max(prevBlocks.length, nextBlocks.length)
    for (let k = 0; k < n; k++) {
      const p = prevBlocks[k]
      const q = nextBlocks[k]
      if (!p?.label.startsWith("msg[0]") && !q?.label.startsWith("msg[0]")) continue
      const same = meta.prevHashes[k] === meta.nextHashes[k]
      console.log(`  ${same ? " " : "≠"} ${k} ${(q ?? p).label}  ${firstLine(blockText(q ?? p))}`)
    }
  }

  if (!pb || !nb) {
    console.log(`\nблок ${i}: ${pb ? "есть только в prev" : "есть только в next"} (${(pb ?? nb)?.label})`)
    if (pb) console.log(firstLine(blockText(pb)))
    if (nb) console.log(firstLine(blockText(nb)))
    return
  }
  console.log(`\nразошёлся блок ${i}: prev=${pb.label} next=${nb.label}`)
  console.log(diffText(blockText(pb), blockText(nb), full))
}

const main = defineCommand({
  meta: {
    name: "cc-trace-break",
    description: "Отчёт по разрывам prompt-кэша сессии: класс разрыва и unified diff разошедшегося блока.",
  },
  args: {
    sid: { type: "positional", required: false, description: "id сессии; без него — сводка по всем свёрнутым сессиям" },
    full: { type: "boolean", default: false, description: "Полный diff без обрезки" },
    last: { type: "string", default: "3", description: "Сколько последних разрывов показать" },
  },
  run({ args }) {
    if (!args.sid) return overview()
    report(String(args.sid), args.full, Math.max(1, Number(args.last) || 3))
  },
})

runMain(main)
