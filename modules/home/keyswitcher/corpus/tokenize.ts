import { tmpdir } from 'node:os'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

const dir = process.env.KSW_CORPUS_DIR ?? join(tmpdir(), 'keyswitcher-corpus')
await mkdir(dir, { recursive: true })
const cyr = /^[А-Яа-яЁё]+$/
const lat = /^[A-Za-z]+$/
type Entry = { count: number; sources: Record<string, number>; example: string }
const pairs = new Map<string, Entry>()

for (const line of (await readFile(join(dir, 'corpus.tsv'), 'utf8')).split('\n')) {
	const tab = line.indexOf('\t')
	if (tab < 0) continue
	const source = line.slice(0, tab)
	const text = line.slice(tab + 1)
	let prev = ''
	for (const m of text.matchAll(/[\p{L}\p{N}_]+/gu)) {
		const word = m[0]
		const script = cyr.test(word) ? 'ru' : lat.test(word) ? 'en' : ''
		if (script) {
			const key = `${word}\t${prev}`
			let e = pairs.get(key)
			if (!e) {
				const at = m.index ?? 0
				e = { count: 0, sources: {}, example: text.slice(Math.max(0, at - 50), at + word.length + 50) }
				pairs.set(key, e)
			}
			e.count++
			e.sources[source] = (e.sources[source] ?? 0) + 1
		}
		prev = script
	}
}

await writeFile(join(dir, 'pairs.tsv'), `${[...pairs.keys()].join('\n')}\n`)
await writeFile(join(dir, 'pairs.json'), JSON.stringify(Object.fromEntries(pairs)))
console.log('pairs', pairs.size)
