import {
	lstat,
	mkdir,
	readFile,
	realpath,
	rename,
	rm,
	writeFile,
} from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'

const args = Bun.argv.slice(2)
const home = Bun.env.HOME
const dotfiles = Bun.env.DOTFILES ?? resolve(import.meta.dir, '../../..')

if (!home || !dotfiles || args.length === 0) {
	console.error(
		'Usage: run.ts <apm arguments...>; HOME and DOTFILES must be set',
	)
	process.exit(2)
}

const liveDirectory = join(home, '.apm')
const canonicalDirectory = join(dotfiles, 'modules/home/apm/config')
const names = ['apm.yml', 'apm.lock.yaml'] as const

async function pathExists(path: string) {
	try {
		await lstat(path)
		return true
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false
		throw error
	}
}

async function resolvesTo(path: string, expected: string) {
	try {
		return resolve(await realpath(path)) === resolve(await realpath(expected))
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === 'ENOENT') return false
		throw error
	}
}

async function writeAtomically(path: string, contents: Uint8Array) {
	await mkdir(dirname(path), { recursive: true })
	const temporary = `${path}.apm-${process.pid}-${crypto.randomUUID()}`
	try {
		await writeFile(temporary, contents)
		await rename(temporary, path)
	} finally {
		await rm(temporary, { force: true })
	}
}

async function persistReplacement(name: (typeof names)[number]) {
	const live = join(liveDirectory, name)
	const canonical = join(canonicalDirectory, name)
	if (await resolvesTo(live, canonical)) return false
	if (await pathExists(live)) {
		const contents = await readFile(live)
		Bun.YAML.parse(new TextDecoder().decode(contents))
		await writeAtomically(canonical, contents)
	}
	return true
}

async function repairLinks() {
	const needsRelink = (await Promise.all(names.map(persistReplacement))).some(
		Boolean,
	)
	if (needsRelink) {
		await Promise.all(
			names.map((name) => rm(join(liveDirectory, name), { force: true })),
		)
		const relink = Bun.spawn(['mise', 'run', 'dot:link'], {
			cwd: dotfiles,
			stderr: 'inherit',
			stdin: 'inherit',
			stdout: 'inherit',
		})
		const exitCode = await relink.exited
		if (exitCode !== 0) throw new Error(`dot:link exited ${exitCode}`)
	}
	for (const name of names) {
		const live = join(liveDirectory, name)
		const canonical = join(canonicalDirectory, name)
		if (!(await resolvesTo(live, canonical))) {
			throw new Error(`${live} does not resolve to ${canonical}`)
		}
	}
}

let child: ReturnType<typeof Bun.spawn> | undefined
let signal: 'SIGINT' | 'SIGTERM' | undefined

function forward(received: 'SIGINT' | 'SIGTERM') {
	signal ??= received
	child?.kill(received)
}

const onInterrupt = () => forward('SIGINT')
const onTerminate = () => forward('SIGTERM')
process.on('SIGINT', onInterrupt)
process.on('SIGTERM', onTerminate)

let apmExitCode = 1
let repairFailed = false

try {
	child = Bun.spawn(['apm', ...args], {
		cwd: liveDirectory,
		stderr: 'inherit',
		stdin: 'inherit',
		stdout: 'inherit',
	})
	apmExitCode = await child.exited
} catch (error) {
	console.error(error instanceof Error ? error.message : String(error))
} finally {
	try {
		await repairLinks()
	} catch (error) {
		repairFailed = true
		console.error(
			`Failed to restore global APM links: ${error instanceof Error ? error.message : String(error)}`,
		)
	}
	process.off('SIGINT', onInterrupt)
	process.off('SIGTERM', onTerminate)
}

if (repairFailed) process.exit(70)
if (signal === 'SIGINT') process.exit(130)
if (signal === 'SIGTERM') process.exit(143)
process.exit(apmExitCode)
