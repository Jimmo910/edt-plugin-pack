#requires -Version 7
# sync-version.ps1 — версия набора (package.version) одна на все линии EDT.
#
# Зачем: check-updates.ps1 бампит версию в СВОЁМ манифесте. Пока составы линий были
# одинаковыми, обновлялись они всегда вместе и версии совпадали сами собой. С расхождением
# составов (напр. edt-editing 0.6.0 на 2026.1 / 0.7.0 на 2026.2) обновиться может ОДНА линия —
# и версии разъезжаются. А релиз/тег у набора один, и имя архива содержит версию, поэтому
# выравнивать надо ДО сборки: иначе в релизе v2.0.1 лежал бы EDT-Plugin-Pack-2026.1-2.0.0.zip,
# а внутри него README.txt ссылался бы на несуществующее имя файла.
#
#   без ключа: выравнивает манифесты по максимальной версии, печатает её (stdout — только версия)
#   -Check:    ничего не пишет; код 1, если версии расходятся (гейт перед релизом)
[CmdletBinding()]
param(
  [string[]] $ManifestPaths,
  [switch]   $Check
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $ManifestPaths) { $ManifestPaths = (Get-ChildItem (Join-Path $root 'manifests') -Filter '*.json').FullName }
if (-not $ManifestPaths) { throw "манифесты не найдены" }

$items = foreach ($mp in $ManifestPaths) {
  $m = Get-Content $mp -Raw | ConvertFrom-Json
  [pscustomobject]@{ Path = $mp; Manifest = $m; Version = [version]$m.package.version }
}
$target   = @($items.Version | Sort-Object -Descending)[0]
$diverged = @($items | Where-Object { $_.Version -ne $target })
$report   = ($items | ForEach-Object { "$(Split-Path $_.Path -Leaf)=$($_.Version)" }) -join ', '

if ($Check) {
  if ($diverged.Count) { [Console]::Error.WriteLine("package.version расходится по манифестам: $report"); exit 1 }
  Write-Output $target.ToString()
  exit 0
}

foreach ($it in $diverged) {
  $it.Manifest.package.version = $target.ToString()
  $it.Manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $it.Path -Encoding UTF8
  [Console]::Error.WriteLine("$(Split-Path $it.Path -Leaf): версия -> $target")
}
if (-not $diverged.Count) { [Console]::Error.WriteLine("версии уже совпадают: $report") }
Write-Output $target.ToString()
