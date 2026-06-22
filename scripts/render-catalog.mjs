#!/usr/bin/env node
// Render the Codex Desktop picker catalog.json from the user's models.json.
// Usage: node render-catalog.mjs <models.json> <out-catalog.json>
import { readFileSync, writeFileSync } from "node:fs";

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error("usage: render-catalog.mjs <models.json> <catalog.json>");
  process.exit(2);
}
const raw = JSON.parse(readFileSync(inPath, "utf8"));
const list = Array.isArray(raw) ? raw : raw.models ?? [];
const models = list.map((m, i) => ({
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
  truncation_policy: { mode: "tokens", limit: 24000 },
  supports_parallel_tool_calls: false,
  supports_image_detail_original: false,
  context_window: m.context_window ?? 128000,
  auto_compact_token_limit: 24000,
  effective_context_window_percent: 95,
  experimental_supported_tools: [],
  input_modalities: ["text"],
}));
writeFileSync(outPath, JSON.stringify({ models }, null, 2));
console.error(`wrote ${models.length} models -> ${outPath}`);
