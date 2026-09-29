#!/usr/bin/env bun
import { existsSync, readFileSync, realpathSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { defineCommand, runMain } from 'citty'

type Rule = { name?: string; scope?: string | string[]; settings?: Record<string, string | undefined> }
type Customizations = Record<string, unknown>
type ThemeContribution = { id?: string; label?: string; uiTheme?: string; path: string }
type LoadedTheme = { colors: Record<string, string>; tokenColors: Rule[] }

const home = homedir()
const vscodeUser = join(home, 'Library', 'Application Support', 'Code', 'User')
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

const defaultEditorColors = {
  dark: { fg: '#CCCCCC', bg: '#1E1E1E' },
  light: { fg: '#000000', bg: '#FFFFFF' },
}

function fail(message: string): never {
  process.stderr.write(`vscode-theme: ${message}\n`)
  process.exit(1)
}

function readJsonc<T>(path: string): T {
  return Bun.JSONC.parse(readFileSync(path, 'utf8')) as T
}

function normalizeColor(color: string | undefined): string | undefined {
  if (!color?.startsWith('#') || ![4, 5, 7, 9].includes(color.length)) return undefined
  const digits = color.slice(1).toUpperCase()
  if (!/^[0-9A-F]+$/.test(digits)) return undefined
  const full = digits.length <= 4 ? [...digits].map((c) => c + c).join('') : digits
  return `#${full.length === 8 && full.endsWith('FF') ? full.slice(0, 6) : full}`
}

function isThemeScopeMatch(pattern: string, settingsId: string): boolean {
  const starts = pattern.startsWith('*')
  const ends = pattern.endsWith('*')
  return (
    pattern === settingsId ||
    (starts && ends && settingsId.includes(pattern.slice(1, -1))) ||
    (ends && settingsId.startsWith(pattern.slice(0, -1))) ||
    (starts && settingsId.endsWith(pattern.slice(1)))
  )
}

function themeSpecific(customizations: Customizations, settingsId: string): Customizations | undefined {
  let merged: Customizations | undefined
  for (const [key, scoped] of Object.entries(customizations)) {
    if (!key.startsWith('[') || typeof scoped !== 'object' || scoped === null || Array.isArray(scoped)) continue
    for (const [, pattern] of key.matchAll(/\[(.+?)\]/g)) {
      if (!isThemeScopeMatch(pattern, settingsId)) continue
      merged ??= {}
      for (const [subkey, value] of Object.entries(scoped)) {
        const prior = merged[subkey]
        merged[subkey] = Array.isArray(prior) && Array.isArray(value) ? [...prior, ...value] : (value ?? prior)
      }
    }
  }
  return merged
}

function customTokenRules(customizations: Customizations): Rule[] {
  const rules: Rule[] = []
  for (const [group, scopes] of Object.entries(tokenGroupToScopes)) {
    const value = customizations[group]
    if (!value) continue
    const settings = typeof value === 'string' ? { foreground: value } : (value as Rule['settings'])
    for (const scope of scopes) rules.push({ scope, settings })
  }
  if (Array.isArray(customizations.textMateRules)) {
    for (const rule of customizations.textMateRules as Rule[]) if (rule.scope && rule.settings) rules.push(rule)
  }
  return rules
}

function findTheme(settingsId: string): { path: string; type: 'dark' | 'light' } {
  const roots: string[] = []
  const manifest = join(extensionsDir, 'extensions.json')
  if (existsSync(manifest)) {
    for (const entry of readJsonc<Array<{ relativeLocation: string }>>(manifest)) roots.push(join(extensionsDir, entry.relativeLocation))
  }
  if (existsSync(builtinExtensionsDir)) {
    for (const name of new Bun.Glob('*/package.json').scanSync(builtinExtensionsDir)) roots.push(join(builtinExtensionsDir, dirname(name)))
  }
  for (const root of roots) {
    const pkg = join(root, 'package.json')
    if (!existsSync(pkg)) continue
    const themes = readJsonc<{ contributes?: { themes?: ThemeContribution[] } }>(pkg).contributes?.themes ?? []
    const theme = themes.find((t) => (t.id ?? t.label) === settingsId)
    if (theme) return { path: resolve(root, theme.path), type: theme.uiTheme === 'vs' || theme.uiTheme === 'hc-light' ? 'light' : 'dark' }
  }
  fail(`no installed extension contributes the theme "${settingsId}"`)
}

function loadTheme(path: string, seen = new Set<string>()): LoadedTheme {
  if (seen.has(path)) fail(`include cycle at ${path}`)
  seen.add(path)
  const content = readJsonc<{ include?: string; colors?: Record<string, unknown>; tokenColors?: Rule[] | string; settings?: unknown }>(path)
  const result: LoadedTheme = content.include ? loadTheme(resolve(dirname(path), content.include), seen) : { colors: {}, tokenColors: [] }
  if (Array.isArray(content.settings)) fail(`${path}: .tmTheme-style "settings" themes are not supported`)
  for (const [id, color] of Object.entries(content.colors ?? {})) if (typeof color === 'string') result.colors[id] = color
  if (typeof content.tokenColors === 'string') fail(`${path}: tokenColors pointing at a .tmTheme file are not supported`)
  if (Array.isArray(content.tokenColors)) result.tokenColors.push(...content.tokenColors)
  return result
}

function toRule(rule: Rule): Rule {
  const { foreground, background, fontStyle } = rule.settings ?? {}
  return { scope: rule.scope, settings: { foreground: normalizeColor(foreground), background: normalizeColor(background), fontStyle } }
}

function buildTheme(settingsPath: string, name: string) {
  const settings = readJsonc<Record<string, unknown>>(settingsPath)
  const settingsId = (
    settings['window.autoDetectColorScheme'] ? (settings['workbench.preferredDarkColorTheme'] ?? 'Default Dark Modern') : settings['workbench.colorTheme']
  ) as string | undefined
  if (!settingsId) fail(`${settingsPath} sets no workbench.colorTheme`)
  const { path, type } = findTheme(settingsId)
  const theme = loadTheme(path)

  const colorCustomizations = (settings['workbench.colorCustomizations'] ?? {}) as Customizations
  const colors = { ...theme.colors }
  for (const layer of [colorCustomizations, themeSpecific(colorCustomizations, settingsId) ?? {}]) {
    for (const [id, color] of Object.entries(layer)) if (typeof color === 'string') colors[id] = color
  }

  const tokenCustomizations = (settings['editor.tokenColorCustomizations'] ?? {}) as Customizations
  const custom = [...customTokenRules(tokenCustomizations), ...customTokenRules(themeSpecific(tokenCustomizations, settingsId) ?? {})]
  const defaults = defaultEditorColors[type]
  const tokenColors: Rule[] = [
    { settings: { foreground: normalizeColor(colors['editor.foreground'] ?? defaults.fg), background: normalizeColor(colors['editor.background'] ?? defaults.bg) } },
    ...[...theme.tokenColors, ...custom].filter((rule) => rule.scope && rule.settings).map(toRule),
  ]
  return { name, displayName: settingsId, type, colors, tokenColors }
}

runMain(
  defineCommand({
    meta: { name: 'vscode-theme', description: 'Emit the active VSCode color theme, with settings overrides merged, as a Shiki theme' },
    args: {
      out: { type: 'positional', required: false, description: 'Output file (default: stdout)' },
      name: { type: 'string', description: 'Shiki theme name', default: 'vscode' },
      settings: { type: 'string', description: 'VSCode settings.json', default: join(vscodeUser, 'settings.json') },
    },
    async run({ args }) {
      const json = `${JSON.stringify(buildTheme(realpathSync(args.settings), args.name), null, 2)}\n`
      if (args.out) await Bun.write(args.out, json)
      else process.stdout.write(json)
    },
  }),
)
