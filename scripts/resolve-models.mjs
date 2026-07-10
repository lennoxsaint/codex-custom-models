#!/usr/bin/env node
import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";


const PICKER_ALIASES = [
  "gpt-5.5",
  "gpt-5.4",
  "gpt-5.4-mini",
  "gpt-5.3-codex",
  "gpt-5.3-codex-spark",
  "gpt-5.2-codex",
];


export function buildModels(specs, catalog) {
  if (specs.length === 0) throw new Error("at least one --model is required");
  if (specs.length > PICKER_ALIASES.length) {
    throw new Error(`at most ${PICKER_ALIASES.length} models are supported by the desktop picker`);
  }
  const byId = new Map(catalog.map((model) => [model.id, model]));
  const models = specs.map((spec, index) => {
    const separator = spec.indexOf("|");
    const target = (separator === -1 ? spec : spec.slice(0, separator)).trim();
    const customName = separator === -1 ? "" : spec.slice(separator + 1).trim();
    const model = byId.get(target);
    if (!model) throw new Error(`OpenRouter model not found: ${target}`);
    const displayName = customName || model.name || target;
    return {
      slug: PICKER_ALIASES[index],
      display_name: `${displayName} [OpenRouter]`,
      target,
      context_window: Number(model.context_length) || 128_000,
    };
  });
  return { provider: "openrouter", models };
}


async function loadCatalog(catalogFile) {
  if (catalogFile) {
    const parsed = JSON.parse(await readFile(catalogFile, "utf8"));
    return parsed.data ?? parsed;
  }
  const response = await fetch("https://openrouter.ai/api/v1/models", { signal: AbortSignal.timeout(15_000) });
  if (!response.ok) throw new Error(`OpenRouter model catalog returned HTTP ${response.status}`);
  const parsed = await response.json();
  return parsed.data ?? [];
}


function parseArgs(argv) {
  const args = { models: [], out: "", catalogFile: "" };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === "--model") args.models.push(argv[++index]);
    else if (flag === "--out") args.out = argv[++index];
    else if (flag === "--catalog-file") args.catalogFile = argv[++index];
    else throw new Error(`unknown argument: ${flag}`);
  }
  if (!args.out) throw new Error("--out is required");
  return args;
}


async function main() {
  const args = parseArgs(process.argv.slice(2));
  const catalog = await loadCatalog(args.catalogFile);
  const resolved = buildModels(args.models, catalog);
  await writeFile(args.out, `${JSON.stringify(resolved, null, 2)}\n`, { mode: 0o600 });
  console.error(`resolved ${resolved.models.length} OpenRouter model(s) -> ${args.out}`);
}


if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  });
}
