#!/usr/bin/env bun
import http from "node:http"
import net from "node:net"
import { defineCommand, runMain } from "citty"

export function hostAllowed(host: string, allow: string[]): boolean {
  const h = host.split(":")[0].replace(/^\./, "").toLowerCase()
  return allow.some((a) => {
    const rule = a.replace(/^\./, "").toLowerCase()
    return h === rule || h.endsWith("." + rule)
  })
}

export function startProxy(port: number, allow: string[]): http.Server {
  const server = http.createServer((req, res) => {
    const host = (req.headers.host ?? "").split(":")[0]
    if (!hostAllowed(host, allow)) {
      process.stderr.write(`[blocked] HTTP ${req.method} ${host}\n`)
      res.writeHead(403, { "content-type": "text/plain" })
      res.end("chrome-agent proxy: host not on allowlist\n")
      return
    }
    const target = new URL(req.url ?? "", `http://${req.headers.host}`)
    const upstream = http.request(
      {
        host: target.hostname,
        port: target.port || 80,
        method: req.method,
        path: target.pathname + target.search,
        headers: req.headers,
      },
      (up) => {
        res.writeHead(up.statusCode ?? 502, up.headers)
        up.pipe(res)
      },
    )
    upstream.on("error", () => {
      res.writeHead(502)
      res.end("chrome-agent proxy: upstream error\n")
    })
    req.pipe(upstream)
  })

  server.on("connect", (req, clientSocket, head) => {
    const [host, portStr] = (req.url ?? "").split(":")
    const dstPort = Number(portStr) || 443
    if (!hostAllowed(host, allow)) {
      process.stderr.write(`[blocked] CONNECT ${req.url}\n`)
      clientSocket.write("HTTP/1.1 403 Forbidden\r\n\r\n")
      clientSocket.end()
      return
    }
    const upstream = net.connect(dstPort, host, () => {
      clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n")
      upstream.write(head)
      upstream.pipe(clientSocket)
      clientSocket.pipe(upstream)
    })
    upstream.on("error", () => clientSocket.end())
    clientSocket.on("error", () => upstream.end())
  })

  server.listen(port, "127.0.0.1")
  return server
}

const main = defineCommand({
  meta: { name: "chrome-agent-proxy", description: "Allowlist-only forward proxy for the agent runtime browser" },
  args: {
    port: { type: "string", required: true, description: "listen port on 127.0.0.1" },
    allow: { type: "string", required: true, description: "comma-separated allowlisted hosts" },
  },
  run({ args }) {
    const port = Number(args.port)
    const allow = String(args.allow).split(",").map((s) => s.trim()).filter(Boolean)
    startProxy(port, allow)
    process.stderr.write(`chrome-agent proxy listening on 127.0.0.1:${port}, allow=${allow.join(",")}\n`)
  },
})

if (import.meta.main) runMain(main)
