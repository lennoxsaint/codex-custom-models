#!/usr/bin/env node
import { createHash, randomBytes } from "node:crypto";
import { spawn } from "node:child_process";
import http from "node:http";
import os from "node:os";
import { pathToFileURL } from "node:url";


export function createPkcePair() {
  const verifier = randomBytes(48).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge, method: "S256" };
}


export function createCallbackNonce() {
  return randomBytes(32).toString("base64url");
}


export function parseOAuthCallback(requestUrl, expectedNonce) {
  const url = new URL(requestUrl ?? "/", "http://127.0.0.1");
  if (url.pathname !== `/callback/${expectedNonce}`) {
    throw new Error("OpenRouter callback path did not match the initiating browser session");
  }
  const providerError = url.searchParams.get("error");
  if (providerError) {
    throw new Error(`OpenRouter authorization failed: ${providerError}`);
  }
  const code = url.searchParams.get("code");
  if (!code) throw new Error("OpenRouter callback did not include a code");
  return code;
}


function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    let stderr = "";
    child.stderr?.on("data", (chunk) => { stderr += chunk.toString(); });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || `${command} exited ${code}`));
    });
  });
}


async function keyExists(account, service) {
  try {
    await run("/usr/bin/security", ["find-generic-password", "-a", account, "-s", service], {
      stdio: ["ignore", "ignore", "pipe"],
    });
    return true;
  } catch {
    return false;
  }
}


async function storeKey(account, service, key) {
  const child = spawn(
    "/usr/bin/security",
    ["add-generic-password", "-a", account, "-s", service, "-U", "-w"],
    { stdio: ["pipe", "ignore", "pipe"] },
  );
  let stderr = "";
  child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
  // With -w and no argv value, macOS security prompts twice. Supplying both
  // entries over stdin keeps the credential out of argv, logs, and shell history.
  child.stdin.end(`${key}\n${key}\n`);
  await new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || `security exited ${code}`));
    });
  });
}


function browserPage(ok, message) {
  const color = ok ? "#117a37" : "#b42318";
  return `<!doctype html><meta charset="utf-8"><title>OpenRouter setup</title><style>body{font:18px system-ui;max-width:640px;margin:15vh auto;padding:24px;color:#202124}h1{color:${color}}</style><h1>${ok ? "Connected" : "Setup failed"}</h1><p>${message}</p><p>You can close this tab.</p>`;
}


async function login({ account, service, force, timeoutSeconds }) {
  if (process.platform !== "darwin") throw new Error("browser login currently supports macOS Keychain only");
  if (!force && await keyExists(account, service)) {
    console.log(`OpenRouter credential already present in Keychain service ${service}.`);
    return;
  }

  const pkce = createPkcePair();
  const callbackNonce = createCallbackNonce();
  let settled = false;
  let resolveLogin;
  let rejectLogin;
  const completion = new Promise((resolve, reject) => {
    resolveLogin = resolve;
    rejectLogin = reject;
  });

  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    if (url.pathname !== `/callback/${callbackNonce}`) {
      response.writeHead(404).end();
      return;
    }
    let code;
    try {
      code = parseOAuthCallback(request.url, callbackNonce);
    } catch (error) {
      response.writeHead(400, { "content-type": "text/html" });
      response.end(browserPage(false, "OpenRouter returned an invalid or unrelated authorization callback."));
      if (!settled) rejectLogin(error);
      settled = true;
      return;
    }
    try {
      const exchange = await fetch("https://openrouter.ai/api/v1/auth/keys", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          code,
          code_verifier: pkce.verifier,
          code_challenge_method: pkce.method,
        }),
      });
      if (!exchange.ok) throw new Error(`OpenRouter key exchange returned HTTP ${exchange.status}`);
      const payload = await exchange.json();
      if (typeof payload.key !== "string" || !payload.key) throw new Error("OpenRouter key exchange returned no key");
      await storeKey(account, service, payload.key);
      response.writeHead(200, { "content-type": "text/html" });
      response.end(browserPage(true, "OpenRouter is connected and the credential is stored in your Mac Keychain."));
      payload.key = undefined;
      if (!settled) resolveLogin();
      settled = true;
    } catch (error) {
      response.writeHead(500, { "content-type": "text/html" });
      response.end(browserPage(false, "The authorization could not be completed."));
      if (!settled) rejectLogin(error);
      settled = true;
    }
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  const port = typeof address === "object" && address ? address.port : 0;
  const callback = `http://localhost:${port}/callback/${callbackNonce}`;
  const auth = new URL("https://openrouter.ai/auth");
  auth.searchParams.set("callback_url", callback);
  auth.searchParams.set("code_challenge", pkce.challenge);
  auth.searchParams.set("code_challenge_method", pkce.method);
  console.log("Opening OpenRouter in your browser. Approve the connection to continue setup.");
  await run("/usr/bin/open", [auth.toString()], { stdio: ["ignore", "ignore", "pipe"] });

  const timeout = setTimeout(() => {
    if (!settled) rejectLogin(new Error(`OpenRouter login timed out after ${timeoutSeconds} seconds`));
    settled = true;
  }, timeoutSeconds * 1000);
  try {
    await completion;
    console.log(`OpenRouter connected. Credential stored in Keychain service ${service}.`);
  } finally {
    clearTimeout(timeout);
    server.close();
  }
}


function parseArgs(argv) {
  const args = {
    account: process.env.USER || os.userInfo().username,
    service: "codex-custom-models-api-key",
    force: false,
    timeoutSeconds: 300,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === "--account") args.account = argv[++index];
    else if (flag === "--service") args.service = argv[++index];
    else if (flag === "--force") args.force = true;
    else if (flag === "--timeout-seconds") args.timeoutSeconds = Number(argv[++index]);
    else throw new Error(`unknown argument: ${flag}`);
  }
  if (!args.account || !args.service) throw new Error("Keychain account and service must not be empty");
  if (!Number.isFinite(args.timeoutSeconds) || args.timeoutSeconds < 30 || args.timeoutSeconds > 900) {
    throw new Error("--timeout-seconds must be between 30 and 900");
  }
  return args;
}


async function main() {
  await login(parseArgs(process.argv.slice(2)));
}


if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  });
}
