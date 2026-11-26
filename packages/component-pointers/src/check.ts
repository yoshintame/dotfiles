#!/usr/bin/env bun

import { $ } from 'bun'

type Original = { type: string; owner?: string; repo?: string; url?: string }
type Node = { inputs?: Record<string, string | string[]>; locked?: { rev?: string }; original?: Original }
type Lock = { root: string; nodes: Record<string, Node> }
type Submodule = { name: string; path: string; url: string }
type Input = { name: string; rev: string }

const UPDATE_KEY = '^submodule\\..*\\.update$'
const NONE = '^none$'
const GITLINK = /^160000 ([0-9a-f]+) \d\t(.+)$/

const slugOfUrl = (url: string) => url.match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?\/?$/)?.[1].toLowerCase()

function slugOfOriginal(original?: Original) {
	if (original?.type === 'github') return `${original.owner}/${original.repo}`.toLowerCase()
	return original?.url ? slugOfUrl(original.url) : undefined
}

async function gitmodules(key: string) {
	const result = await $`git config --blob :.gitmodules --get ${key}`.nothrow().quiet()
	return result.exitCode === 0 ? result.text().trim() : undefined
}

if ((await $`git cat-file -e :.gitmodules`.nothrow().quiet()).exitCode !== 0) process.exit(0)

const lockFile = await $`git show :flake.lock`.nothrow().quiet()
if (lockFile.exitCode !== 0) {
	console.error('component-pointers: flake.lock is not in the index')
	process.exit(1)
}
const lock: Lock = JSON.parse(lockFile.text())

const inputs = new Map<string, Input[]>()
for (const [name, node] of Object.entries(lock.nodes[lock.root]?.inputs ?? {})) {
	if (typeof node !== 'string') continue
	const slug = slugOfOriginal(lock.nodes[node]?.original)
	const rev = lock.nodes[node]?.locked?.rev
	if (slug && rev) inputs.set(slug, [...(inputs.get(slug) ?? []), { name, rev }])
}

const updates = await $`git config --blob :.gitmodules --name-only --get-regexp ${UPDATE_KEY} ${NONE}`.nothrow().quiet()
const updatesError = updates.stderr.toString().trim()
if (updates.exitCode !== 0 && (updates.exitCode !== 1 || updatesError)) {
	console.error(`component-pointers: ${updatesError.split('\n')[0] || `git config exited with ${updates.exitCode}`}`)
	process.exit(1)
}
const names = updates
	.text()
	.split('\n')
	.filter(Boolean)
	.map((key) => key.slice('submodule.'.length, -'.update'.length))
if (names.length === 0) process.exit(0)

const errors: string[] = []
const submodules: Submodule[] = []
for (const name of names) {
	const path = await gitmodules(`submodule.${name}.path`)
	const url = await gitmodules(`submodule.${name}.url`)
	if (path && url) submodules.push({ name, path, url })
	else errors.push(`${name}: no ${path ? 'url' : 'path'} in .gitmodules`)
}

const gitlinks = new Map<string, string>()
for (const line of (await $`git ls-files -s -- ${submodules.map((submodule) => submodule.path)}`.quiet().text()).split('\n')) {
	const match = line.match(GITLINK)
	if (match) gitlinks.set(match[2], match[1])
}

for (const { path, url } of submodules) {
	const slug = slugOfUrl(url)
	const candidates = (slug && inputs.get(slug)) || []
	if (candidates.length === 0) {
		errors.push(`${path}: no flake input for ${slug ?? url} in flake.lock`)
		continue
	}
	if (new Set(candidates.map((candidate) => candidate.rev)).size > 1) {
		errors.push(
			`${path}: flake.lock inputs ${candidates.map((candidate) => `${candidate.name} ${candidate.rev}`).join(', ')} point to ${slug} with different revs`,
		)
		continue
	}
	const input = candidates[0]
	const gitlink = gitlinks.get(path)
	if (gitlink !== input.rev) {
		errors.push(
			`${path}: gitlink ${gitlink ?? 'missing'} != flake.lock ${input.name} ${input.rev}, run: git update-index --add --cacheinfo 160000,${input.rev},${path}`,
		)
	}
}

if (errors.length > 0) {
	for (const error of errors) console.error(error)
	process.exit(1)
}
