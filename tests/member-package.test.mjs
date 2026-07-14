import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { validateMemberPackage } from "../scripts/validate-member-package.mjs";


const expectedTargets = [
  "anthropic/claude-fable-5",
  "z-ai/glm-5.2",
  "moonshotai/kimi-k2.7-code",
  "qwen/qwen3.7-max",
  "deepseek/deepseek-v4-pro",
];


test("member model pack contains the five verified Codex Club models", async () => {
  const models = JSON.parse(await readFile(new URL("../examples/models.openrouter.json", import.meta.url), "utf8"));
  const result = validateMemberPackage(models);

  assert.deepEqual(result.targets, expectedTargets);
  assert.equal(result.modelCount, 5);
});
