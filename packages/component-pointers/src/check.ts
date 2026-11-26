#!/usr/bin/env bun

import { $ } from 'bun'

type Original = { type: string; owner?: string; repo?: string; url?: string }
type Node = { inputs?: Record<string, string | string[]>; locked?: { rev?: string }; original?: Original }
type Lock = { root: string; nodes: Record<string, Node> }
type Submodule = { path?: string; url?: string; update?: string }

const slugOfUrl = (url: string) => url.match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?\/?$/)?.[1].toLowerCase()
const slugOf = (original?: Original) =>
	original?.type === 'github'
		? `${original.owner}/${original.repo}`.toLowerCase()
		: original?.url && slugOfUrl(original.url)

function check(lock: Lock, submodules: Map<string, Submodule>, gitlinks: Map<string, string>) {
	const inputs = new Map<string, { name: string; rev: string }[]>()
	for (const [name, node] of Object.entries(lock.nodes[lock.root]?.inputs ?? {})) {
		const n = typeof node === 'string' ? lock.nodes[node] : undefined
		const slug = slugOf(n?.original)
		const rev = n?.locked?.rev
		if (slug && rev) inputs.set(slug, [...(inputs.get(slug) ?? []), { name, rev }])
	}
	return [...submodules].flatMap(([name, { path, url, update }]) => {
		if (update !== 'none') return []
		if (!path || !url) return [`${name}: no ${path ? 'url' : 'path'} in .gitmodules`]
		const slug = slugOfUrl(url)
		const candidates = (slug && inputs.get(slug)) || []
		const [input] = candidates
		if (!input) return [`${path}: no flake input for ${slug ?? url} in flake.lock`]
		if (candidates.some(({ rev }) => rev !== input.rev))
			return [`${path}: flake.lock inputs ${candidates.map((c) => `${c.name} ${c.rev}`).join(', ')} disagree on ${slug}`]
		const gitlink = gitlinks.get(path)
		if (gitlink === input.rev) return []
		return [
			`${path}: gitlink ${gitlink ?? 'missing'} != flake.lock ${input.name} ${input.rev}, run: git update-index --add --cacheinfo 160000,${input.rev},${path}`,
		]
	})
}

function exit(errors: string[]): never {
	for (const error of errors) console.error(error)
	process.exit(errors.length > 0 ? 1 : 0)
}

if ((await $`git cat-file -e :.gitmodules`.nothrow().quiet()).exitCode !== 0) exit([])
const lock = await $`git show :flake.lock`.nothrow().quiet()
if (lock.exitCode !== 0) exit(['component-pointers: flake.lock is not in the index'])
const config = await $`git config --blob :.gitmodules -z --list`.nothrow().quiet()
if (config.exitCode !== 0)
	exit([`component-pointers: ${config.stderr.toString().trim().split('\n')[0] || `git config exited with ${config.exitCode}`}`])

const submodules = new Map<string, Submodule>()
for (const [, name, key, value] of config.text().matchAll(/(?<=^|\0)submodule\.([^\n\0]+)\.(path|url|update)\n([^\0]*)\0/g))
	submodules.set(name, { ...submodules.get(name), [key]: key === 'path' ? value.replace(/\/+$/, '') : value })

const paths = [...submodules.values()].flatMap(({ path, update }) => (path && update === 'none' ? [path] : []))
const index = paths.length > 0 ? await $`git ls-files -s -z -- ${paths}`.quiet().text() : ''
const gitlinks = new Map([...index.matchAll(/160000 ([0-9a-f]+) \d\t([^\0]+)\0/g)].map(([, sha, path]) => [path, sha]))

exit(check(JSON.parse(lock.text()), submodules, gitlinks))
