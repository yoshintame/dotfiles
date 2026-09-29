#!/usr/bin/env bun
import { existsSync, readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { defineCommand, runMain } from 'citty'
import { z } from 'zod'

const home = homedir()
const extensionsDir = join(home, '.vscode', 'extensions')
const builtinExtensionsDir = '/Applications/Visual Studio Code.app/Contents/Resources/app/extensions'

const tokenGroupToScopes: Record<string, string[]> = {
  comments: ['comment', 'punctuation.definition.comment'],
  strings: ['string', 'meta.embedded.assembly'],
  keywords: ['keyword - keyword.operator', 'keyword.control', 'storage', 'storage.type'],
  numbers: ['constant.numeric'],
  types: ['entity.name.type', 'entity.name.class', 'support.type', 'support.class'],
  functions: ['entity.name.function', 'support.function'],
  variables: ['variable', 'entity.name.variable'],
}

const defaultForeground = { dark: '#BBBBBB', light: '#333333' }

const RuleSettings = z.object({ foreground: z.string().optional(), background: z.string().optional(), fontStyle: z.string().optional() })
const Scope = z.union([z.string(), z.array(z.string())])
const Rule = z.object({ scope: Scope.optional(), settings: RuleSettings.optional() })
const ScopedRule = z.object({ scope: Scope, settings: RuleSettings })
type Rule = z.infer<typeof Rule>
type ScopedRule = z.infer<typeof ScopedRule>

const Customizations = z.record(z.string(), z.unknown())
type Customizations = z.infer<typeof Customizations>

const UserSettings = z.object({
  'workbench.colorTheme': z.string().default('Default Dark Modern'),
  'workbench.colorCustomizations': Customizations.default({}),
  'editor.tokenColorCustomizations': Customizations.default({}),
})

const ThemeFile = z.object({
  include: z.string().optional(),
  colors: Customizations.default({}),
  tokenColors: z.array(Rule).default([]),
  settings: z.undefined({ error: '.tmTheme-style "settings" themes are not supported' }).optional(),
})

const ThemeContribution = z.object({ id: z.string().optional(), label: z.string().optional(), uiTheme: z.string().optional(), path: z.string() })
const ExtensionManifest = z.object({ contributes: z.object({ themes: z.array(ThemeContribution).default([]) }).default({ themes: [] }) })
const ExtensionsIndex = z.array(z.object({ relativeLocation: z.string() }))
const Color = z.string().optional().catch(undefined)

type ThemeType = keyof typeof defaultForeground

interface FoundTheme {
  path: string
  type: ThemeType
}

interface LoadedTheme {
  foreground: string | undefined
  tokenColors: Rule[]
}

function fail(message: string): never {
  process.stderr.write(`vscode-theme: ${message}\n`)
  process.exit(1)
}

function readJsonc<T>(path: string, schema: z.ZodType<T>): T {
  const parsed = schema.safeParse(Bun.JSONC.parse(readFileSync(path, 'utf8')))
  return parsed.success ? parsed.data : fail(`${path}: ${z.prettifyError(parsed.error)}`)
}

function normalizeColor(color: string | undefined): string | undefined {
  const digits = /^#([0-9A-F]{3,4}|[0-9A-F]{6}|[0-9A-F]{8})$/i.exec(color ?? '')?.[1]?.toUpperCase()
  if (digits === undefined) return undefined
  const full = digits.length <= 4 ? [...digits].map((c) => c + c).join('') : digits
  return `#${full.length === 8 ? full.replace(/FF$/, '') : full}`
}

function isThemeScopeMatch(pattern: string, settingsId: string): boolean {
  const core = pattern.replace(/^\*|\*$/g, '')
  const shape = `${pattern.startsWith('*') ? '*' : ''}x${pattern.endsWith('*') ? '*' : ''}`
  const matchers: Record<string, (id: string) => boolean> = {
    x: (id) => id === pattern,
    '*x*': (id) => id.includes(core),
    'x*': (id) => id.startsWith(core),
    '*x': (id) => id.endsWith(core),
  }
  return matchers[shape](settingsId)
}

function themeSpecific(customizations: Customizations, settingsId: string): Customizations {
  const merged: Customizations = {}
  for (const [key, scoped] of Object.entries(customizations)) {
    const patterns = /^\[.*\]$/.test(key) ? [...key.matchAll(/\[(.+?)\]/g)].map(([, pattern]) => pattern) : []
    const values = patterns.some((pattern) => isThemeScopeMatch(pattern, settingsId)) ? Customizations.safeParse(scoped) : undefined
    if (!values?.success) continue
    for (const [subkey, value] of Object.entries(values.data)) {
      const prior = merged[subkey]
      const concatenated = Array.isArray(prior) ? (Array.isArray(value) ? [...prior, ...value] : undefined) : undefined
      merged[subkey] = concatenated ?? (value || prior)
    }
  }
  return merged
}

function customTokenRules(customizations: Customizations): unknown[] {
  const groups = Object.entries(tokenGroupToScopes).flatMap(([group, scopes]) => {
    const value = customizations[group]
    if (!value) return []
    const settings = typeof value === 'string' ? { foreground: value } : value
    return scopes.map((scope) => ({ scope, settings }))
  })
  const textMateRules = Array.isArray(customizations.textMateRules) ? customizations.textMateRules : []
  return [...groups, ...textMateRules]
}

function extensionRoots(): string[] {
  const installed = existsSync(join(extensionsDir, 'extensions.json'))
    ? readJsonc(join(extensionsDir, 'extensions.json'), ExtensionsIndex).map(({ relativeLocation }) => join(extensionsDir, relativeLocation))
    : []
  const builtin = existsSync(builtinExtensionsDir)
    ? [...new Bun.Glob('*/package.json').scanSync(builtinExtensionsDir)].map((manifest) => join(builtinExtensionsDir, dirname(manifest)))
    : []
  return [...installed, ...builtin]
}

function findTheme(settingsId: string): FoundTheme {
  for (const root of extensionRoots().filter((root) => existsSync(join(root, 'package.json')))) {
    const theme = readJsonc(join(root, 'package.json'), ExtensionManifest).contributes.themes.find((t) => (t.id ?? t.label) === settingsId)
    if (theme === undefined) continue
    return { path: resolve(root, theme.path), type: ['vs', 'hc-light'].includes(theme.uiTheme ?? '') ? 'light' : 'dark' }
  }
  fail(`no installed extension contributes the theme "${settingsId}"`)
}

function loadTheme(path: string, seen: string[] = []): LoadedTheme {
  if (seen.includes(path)) fail(`include cycle at ${path}`)
  const content = readJsonc(path, ThemeFile)
  const included = content.include === undefined ? { foreground: undefined, tokenColors: [] } : loadTheme(resolve(dirname(path), content.include), [...seen, path])
  return {
    foreground: Color.parse(content.colors['editor.foreground']) ?? included.foreground,
    tokenColors: [...included.tokenColors, ...content.tokenColors],
  }
}

function toRule({ scope, settings: { foreground, background, fontStyle } }: ScopedRule): ScopedRule {
  return { scope, settings: { foreground: normalizeColor(foreground), background: normalizeColor(background), fontStyle } }
}

function buildTheme(settingsPath: string) {
  const settings = readJsonc(settingsPath, UserSettings)
  const settingsId = settings['workbench.colorTheme']
  const { path, type } = findTheme(settingsId)
  const theme = loadTheme(path)

  const colors = settings['workbench.colorCustomizations']
  const tokens = settings['editor.tokenColorCustomizations']
  const foreground =
    Color.parse(themeSpecific(colors, settingsId)['editor.foreground']) ?? Color.parse(colors['editor.foreground']) ?? theme.foreground ?? defaultForeground[type]
  const rules = [...theme.tokenColors, ...customTokenRules(tokens), ...customTokenRules(themeSpecific(tokens, settingsId))]
  const tokenColors = rules.flatMap((rule) => {
    const scoped = ScopedRule.safeParse(rule)
    return scoped.success ? [toRule(scoped.data)] : []
  })
  return { type, tokenColors: [{ settings: { foreground: normalizeColor(foreground) } }, ...tokenColors] }
}

runMain(
  defineCommand({
    meta: { name: 'vscode-theme', description: 'Emit the syntax token colors of the active VSCode theme, settings overrides merged, as a Shiki theme' },
    args: {
      out: { type: 'positional', required: false, description: 'Output file (default: stdout)' },
      settings: { type: 'string', description: 'VSCode settings.json', default: join(home, 'Library', 'Application Support', 'Code', 'User', 'settings.json') },
    },
    async run({ args }) {
      const json = `${JSON.stringify(buildTheme(args.settings), null, 2)}\n`
      if (args.out) await Bun.write(args.out, json)
      else process.stdout.write(json)
    },
  }),
)
