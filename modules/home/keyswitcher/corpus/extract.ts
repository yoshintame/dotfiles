import { tmpdir } from 'node:os'
import { createReadStream, existsSync, readdirSync, statSync } from 'node:fs'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { createInterface } from 'node:readline'
import { join } from 'node:path'
import { $ } from 'bun'

const home = process.env.HOME!
const out = process.env.KSW_CORPUS_DIR ?? join(tmpdir(), 'keyswitcher-corpus')
await mkdir(out, { recursive: true })
const seen = new Set<string>()
const counts: Record<string, number> = {}
const lines: string[] = []

const dropBlocks = [
	'system-reminder', 'ide_selection', 'ide_opened_file', 'local-command-stdout', 'local-command-stderr',
	'local-command-caveat', 'task-notification', 'bash-stdout', 'bash-stderr', 'command-message', 'command-name',
	'environment_context', 'user_instructions', 'recommended_plugins', 'user-prompt-submit-hook', 'turn_aborted',
]
const dropPrefixes = [
	'Base directory for this skill', 'Caveat:', 'This session is being continued', '[Request interrupted',
	'# AGENTS.md', '<environment_context>', '<user_instructions>', 'Stop hook feedback', 'API Error',
	'[SYSTEM NOTIFICATION', 'Your task is to create a detailed summary', 'The following is the Codex agent history',
	'# AGENTS.md', '<skill>', 'Human: ', 'Generate a title and a git branch name', '<chat-history-summary>',
]

function clean(raw: string): string {
	let t = raw
	t = t.replace(/<pasted_content[^>]*>[\s\S]*?<\/pasted_content[^>]*>/g, ' ')
	for (const tag of dropBlocks) t = t.replace(new RegExp(`<${tag}[^>]*>[\\s\\S]*?</${tag}>`, 'g'), ' ')
	t = t.replace(/<\/?(command-args|bash-input)>/g, ' ')
	t = t.replace(/```[\s\S]*?```/g, ' ')
	return t.trim()
}

function add(source: string, raw: string) {
	const ide = raw.indexOf('## My request for Codex:')
	if (ide >= 0) raw = raw.slice(ide + '## My request for Codex:'.length)
	if (!raw || dropPrefixes.some((p) => raw.trimStart().startsWith(p))) return
	const text = clean(raw)
	if (text.length < 2 || seen.has(text)) return
	seen.add(text)
	counts[source] = (counts[source] ?? 0) + 1
	lines.push(`${source}\t${text.replace(/\s+/g, ' ')}`)
}

function textOf(content: unknown): string {
	if (typeof content === 'string') return content
	if (!Array.isArray(content)) return ''
	return content
		.filter((b) => b && (b.type === 'text' || b.type === 'input_text'))
		.map((b) => b.text ?? '')
		.join('\n')
}

async function eachLine(path: string, fn: (entry: any) => void) {
	const rl = createInterface({ input: createReadStream(path), crlfDelay: Number.POSITIVE_INFINITY })
	for await (const line of rl) {
		if (!line.includes('"user"')) continue
		try {
			fn(JSON.parse(line))
		} catch {}
	}
}

function walk(dir: string, ext: string, acc: string[] = []): string[] {
	if (!existsSync(dir)) return acc
	for (const name of readdirSync(dir)) {
		const p = join(dir, name)
		const s = statSync(p)
		if (s.isDirectory()) {
			if (name === '.obsidian' || name === '.git' || name === 'node_modules' || name === '.trash') continue
			walk(p, ext, acc)
		} else if (name.endsWith(ext)) acc.push(p)
	}
	return acc
}

const liveSessions = new Set<string>()
for (const file of walk(join(home, '.claude/projects'), '.jsonl')) {
	if (file.includes('/subagents/')) continue
	liveSessions.add(file.replace(/^.*\//, '').replace(/\.jsonl$/, ''))
	await eachLine(file, (e) => {
		if (e.type !== 'user' || e.isSidechain || e.isMeta || e.isCompactSummary) return
		if (e.message?.role !== 'user') return
		add('claude', textOf(e.message.content))
	})
}

const snapshot = await $`duckdb ${join(home, '.claude/cc.duckdb')} -readonly -json -c ${"SELECT session_id, text FROM msg_cache WHERE kind = 'user'"}`
	.quiet()
	.nothrow()
if (snapshot.exitCode === 0) {
	for (const row of JSON.parse(snapshot.stdout.toString() || '[]') as { session_id: string; text: string }[]) {
		if (!liveSessions.has(row.session_id)) add('claude-deleted', row.text)
	}
}

for (const file of walk(join(home, '.codex/sessions'), '.jsonl')) {
	await eachLine(file, (e) => {
		const p = e.payload
		if (e.type === 'response_item' && p?.type === 'message' && p.role === 'user') add('codex', textOf(p.content))
	})
}

const atuin = await $`atuin history list --cmd-only`.quiet().nothrow()
for (const cmd of atuin.stdout.toString().split('\n')) add('atuin', cmd)

for (const file of walk(join(home, 'Documents/obsidian/yoshintame'), '.md')) {
	const body = (await readFile(file, 'utf8')).replace(/^---\n[\s\S]*?\n---\n/, '')
	const source = file.includes('/daily') ? 'vault-daily' : 'vault'
	for (const para of body.split(/\n\s*\n/)) add(source, para)
}

await writeFile(join(out, 'corpus.tsv'), `${lines.join('\n')}\n`)
console.log(counts, 'total', lines.length)
