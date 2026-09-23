import { join, resolve } from 'node:path'
import { repairLinks } from './links'

const rawArgs = Bun.argv.slice(2)
const home = Bun.env.HOME
const dotfiles = Bun.env.DOTFILES ?? resolve(import.meta.dir, '../../..')

if (!home || !dotfiles || rawArgs.length === 0) {
	console.error(
		'Usage: run.ts <apm arguments...>; HOME and DOTFILES must be set',
	)
	process.exit(2)
}

const userScopedCommands = new Set(['install', 'update', 'uninstall', 'prune'])

function withUserScope(input: string[]) {
	const command = input.find((argument) => !argument.startsWith('-'))
	if (!command || !userScopedCommands.has(command)) return input
	if (input.some((argument) => argument === '-g' || argument === '--global')) {
		return input
	}
	const index = input.indexOf(command)
	return [...input.slice(0, index + 1), '--global', ...input.slice(index + 1)]
}

const args = withUserScope(rawArgs)

const liveDirectory = join(home, '.apm')

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
		await repairLinks(home, dotfiles)
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
