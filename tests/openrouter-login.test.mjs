import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { createPkcePair } from "../scripts/openrouter-login.mjs";


test("PKCE uses a high-entropy verifier and matching S256 challenge", () => {
  const pair = createPkcePair();
  const expected = createHash("sha256").update(pair.verifier).digest("base64url");

  assert.match(pair.verifier, /^[A-Za-z0-9_-]{43,}$/);
  assert.equal(pair.challenge, expected);
  assert.equal(pair.method, "S256");
});
