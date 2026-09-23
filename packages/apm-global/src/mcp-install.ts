import { readFile } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { repairLinks } from './links'

type Values = Record<string, string>

export type Dependency = {
	name: string
	transport?: string
	env?: Values
	headers?: Values
}

export type Entry = { env?: Values; headers?: Values }

export type Stale = { claude: string[]; codex: string[] }

const reference = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g

export function references(dependency: Dependency) {
	const values = [
		...Object.values(dependency.env ?? {}),
		...Object.values(dependency.headers ?? {}),
	]
	return [
		...new Set(
			values.flatMap((value) =>
				[...String(value).matchAll(reference)].map((match) => match[1]),
			),
		),
	]
}

function expand(values: Values | undefined, secrets: Values) {
	return Object.fromEntries(
		Object.entries(values ?? {}).map(([key, value]) => [
			key,
			String(value).replace(reference, (_, name: string) => secrets[name] ?? ''),
		]),
	)
}

function differs(expected: Values, actual: Values | undefined) {
	return Object.entries(expected).some(([key, value]) => actual?.[key] !== value)
}

export function staleServers(
	dependencies: Dependency[],
	secrets: Values,
	claude: Record<string, Entry>,
	codex: Record<string, Entry>,
): Stale {
	const stale: Stale = { claude: [], codex: [] }
	for (const dependency of dependencies) {
		if (references(dependency).length === 0) continue
		const claudeEntry = claude[dependency.name]
		const codexEntry = codex[dependency.name]
		if (dependency.transport === 'http') {
			const headers = expand(dependency.headers, secrets)
			if (claudeEntry && differs(headers, claudeEntry.headers)) {
				stale.claude.push(dependency.name)
			}
			continue
		}
		const env = expand(dependency.env, secrets)
		if (claudeEntry && differs(env, claudeEntry.env)) {
			stale.claude.push(dependency.name)
		}
		if (codexEntry && differs(env, codexEntry.env)) {
			stale.codex.push(dependency.name)
		}
	}
	return stale
}

async function readServers(path: string, parse: (text: string) => unknown, key: string) {
	try {
		const document = parse(await readFile(path, 'utf8')) as Record<string, unknown>
		return (document[key] ?? {}) as Record<string, Entry>
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === 'ENOENT') return {}
		throw error
	}
}

async function run(command: string[], env?: Record<string, string | undefined>) {
	const child = Bun.spawn(command, {
		env,
		stderr: 'inherit',
		stdin: 'ignore',
		stdout: 'inherit',
	})
	return child.exited
}

async function decrypt(path: string) {
	const child = Bun.spawn(['sops', '-d', '--output-type', 'json', path], {
		stderr: 'inherit',
		stdin: 'ignore',
		stdout: 'pipe',
	})
	const [output, exitCode] = await Promise.all([
		new Response(child.stdout).text(),
		child.exited,
	])
	if (exitCode !== 0) throw new Error(`sops -d ${path} exited ${exitCode}`)
	return JSON.parse(output) as Values
}

async function main() {
	const home = Bun.env.HOME
	const dotfiles = Bun.env.DOTFILES ?? resolve(import.meta.dir, '../../..')
	if (!home) {
		console.error('HOME must be set')
		return 2
	}
	if (!Bun.which('apm')) {
		console.warn('WARN: apm not found, skipping MCP install')
		return 0
	}

	const config = join(dotfiles, 'modules/home/apm/config/apm.yml')
	const manifest = Bun.YAML.parse(await readFile(config, 'utf8')) as {
		dependencies?: { mcp?: Dependency[] }
	}
	const dependencies = manifest.dependencies?.mcp ?? []
	const secrets = await decrypt(join(dotfiles, 'modules/home/apm/secrets.yaml'))
	const missing = [...new Set(dependencies.flatMap(references))].filter(
		(name) => !secrets[name],
	)
	if (missing.length > 0) {
		console.error(
			`MCP secrets missing from SOPS: ${missing.join(', ')}; skipping apm install`,
		)
		return 1
	}

	const claudeConfig = join(home, '.claude.json')
	const codexConfig = join(Bun.env.CODEX_HOME ?? join(home, '.codex'), 'config.toml')
	const detect = async () =>
		staleServers(
			dependencies,
			secrets,
			await readServers(claudeConfig, JSON.parse, 'mcpServers'),
			await readServers(codexConfig, Bun.TOML.parse, 'mcp_servers'),
		)

	const stale = await detect()
	for (const name of stale.claude) {
		console.log(`Reconfiguring ${name} for Claude: resolved secrets changed`)
		await run(['claude', 'mcp', 'remove', name, '-s', 'user'])
	}
	for (const name of stale.codex) {
		console.log(`Reconfiguring ${name} for Codex: resolved secrets changed`)
		await run(['codex', 'mcp', 'remove', name])
	}

	const exitCode = await run(['apm', 'install', '--global', '--only', 'mcp'], {
		...Bun.env,
		...secrets,
	})
	await repairLinks(home, dotfiles)
	if (exitCode !== 0) return exitCode

	const remaining = await detect()
	const unresolved = [
		...remaining.claude.map((name) => `claude:${name}`),
		...remaining.codex.map((name) => `codex:${name}`),
	]
	if (unresolved.length > 0) {
		console.error(`MCP entries still carry stale secrets: ${unresolved.join(', ')}`)
		return 1
	}
	return 0
}

if (import.meta.main) process.exit(await main())
