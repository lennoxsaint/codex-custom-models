#!/usr/bin/env node
// codex-custom-models — local alias proxy
// Bridges Codex (127.0.0.1 only) -> OpenRouter (or any OpenAI-compatible upstream, incl. Ollama).
// Rewrites OpenAI-style alias slugs to real provider model ids using your models.json,
// so the Codex Desktop model picker can show and switch custom models.
//
// Logs ONLY metadata (route, alias, target, status, latency). NEVER logs prompts, completions, or keys.
import http from "node:http";
import { Readable } from "node:stream";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const PORT = Number(process.env.CCM_PROXY_PORT ?? "8787");
const HOST = "127.0.0.1"; // loopback only — never bind 0.0.0.0
const UPSTREAM = (process.env.CCM_UPSTREAM ?? "https://openrouter.ai/api/v1").replace(/\/+$/, "");
const NEEDS_KEY = process.env.CCM_NEEDS_KEY ?? "1"; // "0" for local Ollama (no key)
const CATALOG_PATH = process.env.CCM_MODELS_JSON ?? `${process.env.HOME}/.codex-custom/custom-models/models.json`;
const KEYCHAIN_SERVICE = process.env.CCM_KEYCHAIN_SERVICE ?? "codex-custom-models-api-key";
const KEYCHAIN_ACCOUNT = process.env.CCM_KEYCHAIN_ACCOUNT ?? process.env.USER ?? "default";
const TITLE = process.env.CCM_TITLE ?? "codex-custom-models";
const REFERER = process.env.CCM_HTTP_REFERER ?? "https://github.com/lennox-saint/codex-custom-models";
const LOG_PATH = process.env.CCM_PROXY_LOG ?? "";

// --- alias map built from models.json (slug -> {target, name, contextLength}) ---
function loadAliases() {
  const raw = JSON.parse(readFileSync(CATALOG_PATH, "utf8"));
  const list = Array.isArray(raw) ? raw : raw.models ?? [];
  const map = {};
  for (const m of list) {
    if (!m || typeof m.slug !== "string") continue;
    map[m.slug] = {
      target: m.target ?? m.slug,
      name: m.display_name ?? m.slug,
      contextLength: m.context_window ?? 128000,
    };
  }
  return map;
}
let ALIASES = loadAliases();

// --- key: env first, then macOS Keychain (no key needed for local Ollama) ---
function getApiKey() {
  if (NEEDS_KEY === "0") return "";
  if (process.env.OPENROUTER_API_KEY) return process.env.OPENROUTER_API_KEY;
  try {
    return execFileSync(
      "/usr/bin/security",
      ["find-generic-password", "-a", KEYCHAIN_ACCOUNT, "-s", KEYCHAIN_SERVICE, "-w"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }
    ).trim();
  } catch {
    return "";
  }
}

function nowIso() { return new Date().toISOString(); }
function writeLog(event) {
  const line = JSON.stringify({ ts: nowIso(), ...event });
  if (!LOG_PATH) { console.error(line); return; }
  import("node:fs").then(({ appendFile }) => appendFile(LOG_PATH, `${line}\n`, () => {}));
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json", "content-length": Buffer.byteLength(payload) });
  res.end(payload);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function sanitize(body) {
  if (body == null || typeof body !== "object" || Array.isArray(body)) return { body, alias: null, target: null };
  const alias = typeof body.model === "string" ? body.model : null;
  const target = alias != null ? ALIASES[alias]?.target ?? null : null;
  if (target != null) body.model = target;
  // strip fields OpenRouter / chat-completions upstreams reject
  delete body.reasoning;
  delete body.reasoning_effort;
  delete body.model_reasoning_effort;
  delete body.reasoning_summary;
  delete body.model_reasoning_summary;
  delete body.store;
  return { body, alias, target };
}

async function forward(req, res) {
  const started = Date.now();
  const url = new URL(req.url ?? "/", `http://${HOST}:${PORT}`);
  const method = req.method ?? "GET";
  const path = `${url.pathname}${url.search}`;
  const key = getApiKey();
  if (NEEDS_KEY !== "0" && !key) {
    sendJson(res, 500, { error: { message: `No API key. Set OPENROUTER_API_KEY or add Keychain item '${KEYCHAIN_SERVICE}'.`, type: "ccm_proxy_error" } });
    writeLog({ route: path, status: 500, error: "missing_key" });
    return;
  }

  let bodyBuf = Buffer.alloc(0);
  let alias = null, target = null;
  if (!["GET", "HEAD"].includes(method)) {
    bodyBuf = await readBody(req);
    const ct = String(req.headers["content-type"] ?? "");
    if (bodyBuf.length > 0 && ct.includes("application/json")) {
      try {
        const parsed = JSON.parse(bodyBuf.toString("utf8"));
        const s = sanitize(parsed);
        alias = s.alias; target = s.target;
        bodyBuf = Buffer.from(JSON.stringify(s.body));
        if (alias != null && target == null) {
          sendJson(res, 400, { error: { message: `Unknown alias model: ${alias}`, type: "ccm_proxy_error" } });
          writeLog({ route: path, alias, status: 400, error: "unknown_alias" });
          return;
        }
      } catch {
        sendJson(res, 400, { error: { message: "Invalid JSON body.", type: "ccm_proxy_error" } });
        writeLog({ route: path, status: 400, error: "invalid_json" });
        return;
      }
    }
  }

  const headers = {
    "content-type": req.headers["content-type"] ?? "application/json",
    accept: req.headers.accept ?? "text/event-stream, application/json",
    "x-title": TITLE,
    "http-referer": REFERER,
  };
  if (key) headers.authorization = `Bearer ${key}`;
  if (bodyBuf.length > 0) headers["content-length"] = String(bodyBuf.length);

  let upstream;
  try {
    upstream = await fetch(`${UPSTREAM}${path.replace(/^\/v1/, "")}`, {
      method,
      headers,
      body: ["GET", "HEAD"].includes(method) ? undefined : bodyBuf,
      duplex: "half",
    });
  } catch {
    sendJson(res, 502, { error: { message: "Failed to reach upstream.", type: "ccm_proxy_error" } });
    writeLog({ route: path, alias, target, status: 502, duration_ms: Date.now() - started, error: "upstream_failed" });
    return;
  }

  const out = {};
  for (const [k, v] of upstream.headers.entries()) {
    if (k.toLowerCase() === "content-encoding") continue;
    out[k] = v;
  }
  res.writeHead(upstream.status, out);
  if (upstream.body == null) res.end();
  else Readable.fromWeb(upstream.body).pipe(res);
  res.on("finish", () => writeLog({ route: path, alias, target, status: upstream.status, duration_ms: Date.now() - started }));
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? "/", `http://${HOST}:${PORT}`);
    if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }
    if (req.method === "GET" && url.pathname === "/health") {
      ALIASES = loadAliases(); // hot-reload catalog edits
      sendJson(res, 200, { ok: true, service: "codex-custom-models-proxy", upstream: UPSTREAM, aliases: Object.keys(ALIASES) });
      return;
    }
    if (req.method === "GET" && url.pathname === "/v1/models") {
      ALIASES = loadAliases();
      const data = Object.entries(ALIASES).map(([id, v]) => ({
        id, object: "model", created: 0, owned_by: "custom", name: v.name, context_length: v.contextLength, target_model: v.target,
      }));
      sendJson(res, 200, { object: "list", data });
      writeLog({ route: "/v1/models", status: 200 });
      return;
    }
    await forward(req, res);
  } catch {
    sendJson(res, 500, { error: { message: "Unexpected proxy failure.", type: "ccm_proxy_error" } });
    writeLog({ route: req.url ?? "/", status: 500, error: "unexpected" });
  }
});

server.listen(PORT, HOST, () => writeLog({ event: "started", host: HOST, port: PORT, upstream: UPSTREAM, aliases: Object.keys(ALIASES) }));
