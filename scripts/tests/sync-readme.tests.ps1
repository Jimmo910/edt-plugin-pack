#requires -Version 7
# Тест для scripts/sync-readme.ps1 — синхронизация колонки «Версия» в README с манифестами.
$ErrorActionPreference = 'Stop'
$here   = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path (Split-Path -Parent $here) 'sync-readme.ps1'

$fails = 0
function Assert([bool]$cond, [string]$msg) {
  if ($cond) { Write-Host "  PASS: $msg" -ForegroundColor Green }
  else       { Write-Host "  FAIL: $msg" -ForegroundColor Red; $script:fails++ }
}
function Invoke-Sync([string]$readme, [string[]]$manifests, [switch]$Check) {
  # Дочерний pwsh через -Command: массив манифестов передаём литералом @('..','..'),
  # т.к. через -File native-exe разбивает массив на отдельные токены и [string[]] не биндится.
  $ml  = '@(' + (($manifests | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ',') + ')'
  $chk = if ($Check) { '-Check' } else { '' }
  & pwsh -NoProfile -Command "& '$script' -ReadmePath '$readme' -ManifestPaths $ml $chk; exit `$LASTEXITCODE" *> $null
  return $LASTEXITCODE
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("sync-readme-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $readme = Join-Path $tmp 'README.md'
  @'
# Test

| Плагин | Версия | Лицензия | Что делает |
|--------|--------|----------|------------|
| [Alpha](https://github.com/acme/alpha) | 1.0.0 | MIT | does alpha |
| [Beta](https://gitlab.com/acme/beta) | 2.0.0 | EPL-2.0 | does beta |
| [Yax](https://github.com/acme/yax) | 0.1 | Apache-2.0 | yax engine |
| [Unmatched](https://github.com/acme/ghost) | 9.9 | MIT | not in manifest |
'@ | Set-Content -Path $readme -Encoding utf8

  $m25 = Join-Path $tmp '2025.2.json'
  @'
{ "package": { "edtLine": "2025.2" },
  "yaxunit": { "version": "0.2", "update": { "repo": "acme/yax" } },
  "plugins": [
    { "id": "alpha", "version": "1.5.0", "repoUrl": "https://github.com/acme/alpha" },
    { "id": "beta",  "version": "2.0.0", "repoUrl": "https://gitlab.com/acme/beta" }
  ] }
'@ | Set-Content -Path $m25 -Encoding utf8

  $m26 = Join-Path $tmp '2026.1.json'
  @'
{ "package": { "edtLine": "2026.1" },
  "yaxunit": { "version": "0.2", "update": { "repo": "acme/yax" } },
  "plugins": [
    { "id": "alpha", "version": "1.5.0", "repoUrl": "https://github.com/acme/alpha" },
    { "id": "beta",  "version": "2.1.0", "repoUrl": "https://gitlab.com/acme/beta" }
  ] }
'@ | Set-Content -Path $m26 -Encoding utf8

  $rc = Invoke-Sync $readme @($m25,$m26) -Check
  Assert ($rc -eq 1) "-Check возвращает 1, когда README разошёлся с манифестами"

  $rc = Invoke-Sync $readme @($m25,$m26)
  Assert ($rc -eq 0) "режим правки завершается кодом 0"
  $out = Get-Content $readme -Raw

  Assert ($out -match '\[Alpha\]\([^)]+\)\s*\|\s*1\.5\.0\s*\|')                              "совпадающие версии -> одно значение (Alpha 1.5.0)"
  Assert ($out -match '\[Beta\]\([^)]+\)\s*\|\s*2\.0\.0 \(2025\.2\) / 2\.1\.0 \(2026\.1\)\s*\|') "расхождение -> обе версии (Beta)"
  Assert ($out -match '\[Yax\]\([^)]+\)\s*\|\s*0\.2\s*\|')                                    "версия из блока yaxunit (Yax 0.2)"
  Assert ($out -match '\[Unmatched\]\([^)]+\)\s*\|\s*9\.9\s*\|')                              "строка без совпадения не тронута (9.9)"
  Assert ($out -match 'MIT \| does alpha')                                                    "колонки лицензии/описания сохранены"

  $rc = Invoke-Sync $readme @($m25,$m26) -Check
  Assert ($rc -eq 0) "-Check возвращает 0, когда README в синхроне"
}
finally { Remove-Item -Recurse -Force $tmp }

if ($fails -gt 0) { Write-Host "`n$fails проверок упало" -ForegroundColor Red; exit 1 }
Write-Host "`nВсе проверки прошли" -ForegroundColor Green
exit 0
