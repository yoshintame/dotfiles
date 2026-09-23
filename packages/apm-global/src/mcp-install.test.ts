import { describe, expect, test } from 'bun:test'
import { type Dependency, references, staleServers } from './mcp-install'

const stdio: Dependency = {
	name: 'ynab',
	transport: 'stdio',
	env: { YNAB_ACCESS_TOKEN: '${YNAB_ACCESS_TOKEN}', YNAB_MCP_ENABLE_DELTA: 'true' },
}

const http: Dependency = {
	name: 'grafana-monitor',
	transport: 'http',
	headers: {
		Authorization: 'Bearer ${GATEWAY_TOKEN}',
		'X-Token': '${SERVICE_TOKEN}',
	},
}

const plain: Dependency = { name: 'chrome-devtools', transport: 'stdio' }

describe('references', () => {
	test('collects unique variable names from env and headers', () => {
		expect(references(stdio)).toEqual(['YNAB_ACCESS_TOKEN'])
		expect(references(http)).toEqual(['GATEWAY_TOKEN', 'SERVICE_TOKEN'])
		expect(references(plain)).toEqual([])
	})
})

describe('staleServers', () => {
	const secrets = { GATEWAY_TOKEN: 'g2', SERVICE_TOKEN: 's1', YNAB_ACCESS_TOKEN: 'y2' }

	test('keeps entries whose resolved values match', () => {
		expect(
			staleServers(
				[stdio, http],
				secrets,
				{
					ynab: { env: { YNAB_ACCESS_TOKEN: 'y2', YNAB_MCP_ENABLE_DELTA: 'true' } },
					'grafana-monitor': { headers: { Authorization: 'Bearer g2', 'X-Token': 's1' } },
				},
				{ ynab: { env: { YNAB_ACCESS_TOKEN: 'y2', YNAB_MCP_ENABLE_DELTA: 'true' } } },
			),
		).toEqual({ claude: [], codex: [] })
	})

	test('flags rotated and unresolved values per provider', () => {
		expect(
			staleServers(
				[stdio, http],
				secrets,
				{
					ynab: { env: { YNAB_ACCESS_TOKEN: '${YNAB_ACCESS_TOKEN}' } },
					'grafana-monitor': { headers: { Authorization: 'Bearer g1', 'X-Token': 's1' } },
				},
				{ ynab: { env: { YNAB_ACCESS_TOKEN: 'y1' } } },
			),
		).toEqual({ claude: ['ynab', 'grafana-monitor'], codex: ['ynab'] })
	})

	test('ignores codex http headers, missing entries and secretless servers', () => {
		expect(
			staleServers(
				[stdio, http, plain],
				secrets,
				{ 'chrome-devtools': { env: {} } },
				{ 'grafana-monitor': { headers: { Authorization: 'Bearer ${GATEWAY_TOKEN}' } } },
			),
		).toEqual({ claude: [], codex: [] })
	})
})
