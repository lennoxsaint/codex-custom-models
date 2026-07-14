#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";


const PICKER_ALIASES = [
  "gpt-5.5",
  "gpt-5.4",
  "gpt-5.4-mini",
  "gpt-5.3-codex",
  "gpt-5.3-codex-spark",
  "gpt-5.2-codex",
];


export function validateMemberPackage(raw, liveCatalog = null) {
  if (raw?.provider !== "openrouter") throw new Error("member package provider must be openrouter");
  if (!Array.isArray(raw.models) || raw.models.length < 1 || raw.models.length > PICKER_ALIASES.length) {
    throw new Error(`member package must contain 1-${PICKER_ALIASES.length} models`);
  }

  const targets = [];
  const aliases = [];
  for (const [index, model] of raw.models.entries()) {
    if (!model || typeof model !== "object") throw new Error(`model ${index + 1} must be an object`);
    if (model.slug !== PICKER_ALIASES[index]) {
      throw new Error(`model ${index + 1} must use picker alias ${PICKER_ALIASES[index]}`);
    }
    if (typeof model.display_name !== "string" || !model.display_name.endsWith(" [OpenRouter]")) {
      throw new Error(`model ${index + 1} needs an explicit OpenRouter display name`);
    }
    if (typeof model.target !== "string" || !model.target.includes("/")) {
      throw new Error(`model ${index + 1} needs a provider/model target`);
    }
    if (!Number.isInteger(model.context_window) || model.context_window < 16_000) {
      throw new Error(`model ${index + 1} has an invalid context window`);
    }
    targets.push(model.target);
    aliases.push(model.slug);
  }

  if (new Set(targets).size !== targets.length) throw new Error("member package contains duplicate model targets");
  if (new Set(aliases).size !== aliases.length) throw new Error("member package contains duplicate picker aliases");

  if (liveCatalog) {
    const byId = new Map(liveCatalog.map((model) => [model.id, model]));
    for (const model of raw.models) {
      const live = byId.get(model.target);
      if (!live) throw new Error(`OpenRouter no longer lists ${model.target}`);
      if (Number(live.context_length) !== model.context_window) {
        throw new Error(`${model.target} context window drifted: package=${model.context_window} live=${live.context_length}`);
      }
    }
  }

  return { modelCount: raw.models.length, targets };
}


async function main() {
  const file = process.argv[2] ?? new URL("../examples/models.openrouter.json", import.meta.url);
  const raw = JSON.parse(await readFile(file, "utf8"));
  let catalog = null;
  if (process.argv.includes("--live")) {
    const response = await fetch("https://openrouter.ai/api/v1/models", { signal: AbortSignal.timeout(15_000) });
    if (!response.ok) throw new Error(`OpenRouter model catalog returned HTTP ${response.status}`);
    catalog = (await response.json()).data ?? [];
  }
  const result = validateMemberPackage(raw, catalog);
  console.log(JSON.stringify({ status: "ready", live: Boolean(catalog), ...result }));
}


if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  });
}
