import assert from "node:assert/strict";
import test from "node:test";

import { buildModels } from "../scripts/resolve-models.mjs";


const catalog = [
  { id: "z-ai/glm-5.2", name: "Z.ai: GLM 5.2", context_length: 1_048_576 },
  { id: "moonshotai/kimi-k2.7-code", name: "MoonshotAI: Kimi K2.7 Code", context_length: 262_144 },
];


test("model resolver validates targets and assigns picker-safe aliases", () => {
  const result = buildModels(
    ["z-ai/glm-5.2", "moonshotai/kimi-k2.7-code|Kimi Code"],
    catalog,
  );

  assert.deepEqual(result, {
    provider: "openrouter",
    models: [
      {
        slug: "gpt-5.5",
        display_name: "Z.ai: GLM 5.2 [OpenRouter]",
        target: "z-ai/glm-5.2",
        context_window: 1_048_576,
      },
      {
        slug: "gpt-5.4",
        display_name: "Kimi Code [OpenRouter]",
        target: "moonshotai/kimi-k2.7-code",
        context_window: 262_144,
      },
    ],
  });
});


test("model resolver rejects unknown targets instead of silently guessing", () => {
  assert.throws(
    () => buildModels(["missing/model"], catalog),
    /OpenRouter model not found: missing\/model/,
  );
});
