# scripts/build.ps1 — полный конвейер сборки (без verify).
# -Target 2025.2|2026.1 выбирает манифест (manifests/<Target>.json). Можно задать env MANIFEST.
param([string]$Target)
$ErrorActionPreference = 'Stop'
if ($Target) { $env:MANIFEST = "manifests/$Target.json" }
if (-not $env:MANIFEST) { $env:MANIFEST = 'manifests/2025.2.json' }
Write-Host "BUILD manifest: $env:MANIFEST" -ForegroundColor Cyan
& "$PSScriptRoot\fetch.ps1"
& "$PSScriptRoot\mirror.ps1"
& "$PSScriptRoot\categorize.ps1"
& "$PSScriptRoot\package.ps1"
Write-Host "BUILD PIPELINE DONE" -ForegroundColor Green
