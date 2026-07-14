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
$beginMarker = "# BEGIN CODEX CUSTOM MODELS"
$endMarker = "# END CODEX CUSTOM MODELS"
$block = @"
$beginMarker
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
$endMarker
"@
$existing = if (Test-Path $cfg) { Get-Content -Raw -Path $cfg } else { "" }
$managedPattern = "(?ms)^# BEGIN CODEX CUSTOM MODELS\r?\n.*?^# END CODEX CUSTOM MODELS\r?\n?"
if ($existing -match $managedPattern) {
  $next = [regex]::Replace($existing, $managedPattern, "$block`r`n")
} elseif ($existing -match "(?m)^\[(model_providers|profiles)\.openrouter\]$") {
  Write-Error "An unmanaged OpenRouter provider/profile already exists in $cfg. Back up and review it before this installer changes anything."
  exit 1
} else {
  $separator = if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { "`r`n`r`n" } elseif ($existing.Length -gt 0) { "`r`n" } else { "" }
  $next = "$existing$separator$block`r`n"
}
Set-Content -Path $cfg -Value $next -NoNewline
Write-Host "Installed one managed OpenRouter provider + profile in $cfg"
Write-Host "Run:  codex --profile openrouter `"Say: OK`""
