# codex-custom-models — Windows/Linux FALLBACK installer (PowerShell).
# No renamed desktop app in v1. Adds an OpenRouter provider + profile to ~/.codex/config.toml,
# or prints the Ollama (--oss) path. Key lives in the OPENROUTER_API_KEY env var (never in config).
param(
  [ValidateSet("openrouter","ollama")] [string]$Provider = "openrouter",
  [string]$Model = "z-ai/glm-5.2"
)
$ErrorActionPreference = "Stop"
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { Write-Error "Codex CLI not found. Install Codex first: https://developers.openai.com/codex"; exit 1 }
$cfgDir = Join-Path $HOME ".codex"; New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
$cfg = Join-Path $cfgDir "config.toml"

if ($Provider -eq "ollama") {
  Write-Host "Ollama path: 1) ollama serve  2) ollama pull $Model  3) codex --oss -m $Model"
  exit 0
}

if (-not $env:OPENROUTER_API_KEY) {
  Write-Error "OPENROUTER_API_KEY is missing. Set it in a trusted PowerShell session with: `$env:OPENROUTER_API_KEY = Read-Host -MaskInput 'OpenRouter key'. Never paste it into an agent chat."
  exit 1
}
$block = @"

[model_providers.openrouter]
name = "OpenRouter"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_API_KEY"
wire_api = "responses"

[profiles.openrouter]
model_provider = "openrouter"
model = "$Model"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
"@
Add-Content -Path $cfg -Value $block
Write-Host "Appended OpenRouter provider + profile to $cfg"
Write-Host "Run:  codex --profile openrouter `"Say: OK`""
