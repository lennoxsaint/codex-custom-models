#!/usr/bin/env node
// Render the Codex Desktop picker catalog.json from the user's models.json.
// Usage: node render-catalog.mjs <models.json> <out-catalog.json>
import { readFileSync, writeFileSync } from "node:fs";

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error("usage: render-catalog.mjs <models.json> <catalog.json>");
  process.exit(2);
}

// Compaction/truncation thresholds MUST scale with each model's own context
// window. If they are fixed (the old bug hardcoded 24000 for every model),
// Codex auto-compacts at that tiny limit regardless of the real window — the
// classic "context automatically compacting after every prompt" on big-window
// models like GLM/Qwen (1M) or Kimi (256k). Deriving them per model from
// context_window keeps the picker correct even when you switch models
// mid-thread, because Codex reads these values from the selected model's
// catalog entry.
const EFFECTIVE_CONTEXT_PERCENT = 95;
const AUTO_COMPACT_RATIO = 0.85; // start compacting at 85% of the window
const TRUNCATION_RATIO = 0.92;   // hard-truncate history at 92% of the window
const DEFAULT_CONTEXT_WINDOW = 128000;

const raw = JSON.parse(readFileSync(inPath, "utf8"));
const list = Array.isArray(raw) ? raw : raw.models ?? [];
const models = list.map((m, i) => {
  const contextWindow = m.context_window ?? DEFAULT_CONTEXT_WINDOW;
  return {
    slug: m.slug,
    display_name: m.display_name ?? m.slug,
    description: m.description ?? `Custom model routed via the local alias proxy to ${m.target ?? m.slug}.`,
    supported_reasoning_levels: [],
    shell_type: "shell_command",
    visibility: "list",
    supported_in_api: true,
    priority: m.priority ?? i + 1,
    base_instructions: "You are Codex using a custom model via a local alias proxy. Help the user carefully, use tools when available, and keep privacy boundaries explicit.",
    supports_reasoning_summaries: false,
    default_reasoning_summary: "auto",
    support_verbosity: false,
    apply_patch_tool_type: "freeform",
    truncation_policy: { mode: "tokens", limit: Math.floor(contextWindow * TRUNCATION_RATIO) },
    supports_parallel_tool_calls: false,
    supports_image_detail_original: false,
    context_window: contextWindow,
    auto_compact_token_limit: Math.floor(contextWindow * AUTO_COMPACT_RATIO),
    effective_context_window_percent: EFFECTIVE_CONTEXT_PERCENT,
    experimental_supported_tools: [],
    input_modalities: ["text"],
  };
});
writeFileSync(outPath, JSON.stringify({ models }, null, 2));
console.error(`wrote ${models.length} models -> ${outPath}`);
