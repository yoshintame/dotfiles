import { tmpdir } from 'node:os'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
const dir = process.env.KSW_CORPUS_DIR ?? join(tmpdir(), 'keyswitcher-corpus')
await mkdir(dir, { recursive: true })
const pairs = JSON.parse(await readFile(join(dir, 'pairs.json'), 'utf8')) as Record<string, { count: number; sources: Record<string, number>; example: string }>
const total = new Map<string, number>()
for (const [key, e] of Object.entries(pairs)) {
	const w = key.split('\t')[0].toLowerCase()
	total.set(w, (total.get(w) ?? 0) + e.count)
}
type Row = { word: string; converted: string; hits: number; total: number; contexts: Set<string>; sources: Record<string, number>; example: string }
const rows = new Map<string, Row>()
for (const line of (await readFile(join(dir, 'hits.tsv'), 'utf8')).split('\n').filter(Boolean)) {
	const [word, ctx, converted] = line.split('\t')
	const e = pairs[`${word}\t${ctx}`]
	const key = word.toLowerCase()
	let r = rows.get(key)
	if (!r) {
		r = { word: key, converted: converted.toLowerCase(), hits: 0, total: total.get(key) ?? 0, contexts: new Set(), sources: {}, example: e.example }
		rows.set(key, r)
	}
	r.hits += e.count
	r.contexts.add(ctx || '-')
	for (const [s, n] of Object.entries(e.sources)) r.sources[s] = (r.sources[s] ?? 0) + n
}
const sorted = [...rows.values()].sort((a, b) => b.hits - a.hits)
await writeFile(join(dir, 'report.tsv'), sorted.map((r) => [r.word, r.converted, r.hits, r.total, [...r.contexts].join(','), Object.entries(r.sources).map(([s, n]) => `${s}:${n}`).join(' '), r.example.replace(/\s+/g, ' ')].join('\t')).join('\n') + '\n')
console.log('words', sorted.length, 'hits', sorted.reduce((s, r) => s + r.hits, 0))
