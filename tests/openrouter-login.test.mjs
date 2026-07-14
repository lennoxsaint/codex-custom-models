import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import {
  createCallbackNonce,
  createPkcePair,
  parseOAuthCallback,
} from "../scripts/openrouter-login.mjs";


test("PKCE uses a high-entropy verifier and matching S256 challenge", () => {
  const pair = createPkcePair();
  const expected = createHash("sha256").update(pair.verifier).digest("base64url");

  assert.match(pair.verifier, /^[A-Za-z0-9_-]{43,}$/);
  assert.equal(pair.challenge, expected);
  assert.equal(pair.method, "S256");
});


test("OAuth callback path must match the initiating browser session", () => {
  const nonce = createCallbackNonce();
  assert.match(nonce, /^[A-Za-z0-9_-]{32,}$/);
  assert.equal(
    parseOAuthCallback(`/callback/${nonce}?code=one-time-code`, nonce),
    "one-time-code",
  );
  assert.throws(
    () => parseOAuthCallback("/callback/unrelated?code=one-time-code", nonce),
    /path did not match/,
  );
});
