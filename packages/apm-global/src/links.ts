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

async function persistReplacement(
	liveDirectory: string,
	canonicalDirectory: string,
	name: (typeof names)[number],
) {
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

export async function repairLinks(home: string, dotfiles: string) {
	const liveDirectory = join(home, '.apm')
	const canonicalDirectory = join(dotfiles, 'modules/home/apm/config')
	const needsRelink = (
		await Promise.all(
			names.map((name) =>
				persistReplacement(liveDirectory, canonicalDirectory, name),
			),
		)
	).some(Boolean)
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
