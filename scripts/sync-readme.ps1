#requires -Version 7
# sync-readme.ps1 — приводит колонку «Версия» в таблице README.md к версиям из манифестов.
#   Точечно правит только ячейку версии (описания/лицензии живут лишь в README и не трогаются).
#   Строки таблицы сопоставляются с плагином по ссылке [Имя](url) → slug owner/repo == repoUrl манифеста
#   (+ блок yaxunit по update.repo). Если версия на линиях (2025.2/2026.1) расходится — пишем обе:
#   «1.1.8 (2025.2) / 1.1.13 (2026.1)».
#   -Check: ничего не пишет, выходит с кодом 1, если README разошёлся с манифестами (гейт для CI).
[CmdletBinding()]
param(
  [string]   $ReadmePath,
  [string[]] $ManifestPaths,
  [switch]   $Check
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $ReadmePath)    { $ReadmePath    = Join-Path $root 'README.md' }
if (-not $ManifestPaths) { $ManifestPaths = (Get-ChildItem (Join-Path $root 'manifests') -Filter '*.json').FullName }

function Get-RepoSlug([string]$urlOrSlug) {
  if (-not $urlOrSlug) { return $null }
  ($urlOrSlug -replace '^https?://[^/]+/', '' -replace '\.git$', '' -replace '/+$', '').ToLowerInvariant()
}

# slug -> ([ordered] edtLine -> version)
$byRepo = @{}
function Add-Version([string]$slug, [string]$line, [string]$version) {
  if (-not $slug -or -not $version) { return }
  if (-not $byRepo.ContainsKey($slug)) { $byRepo[$slug] = [ordered]@{} }
  $byRepo[$slug][$line] = $version
}
foreach ($mp in $ManifestPaths) {
  $m = Get-Content $mp -Raw | ConvertFrom-Json
  $line = [string]$m.package.edtLine
  foreach ($p in $m.plugins) { Add-Version (Get-RepoSlug $p.repoUrl) $line $p.version }
  if ($m.yaxunit) { Add-Version (Get-RepoSlug $m.yaxunit.update.repo) $line $m.yaxunit.version }
}

function Format-Version($byLine) {
  $distinct = @($byLine.Values | Select-Object -Unique)
  if ($distinct.Count -le 1) { return [string]$distinct[0] }
  (($byLine.Keys | Sort-Object | ForEach-Object { "$($byLine[$_]) ($_)" }) -join ' / ')
}

$linkRe = [regex]'\]\((?<url>[^)]+)\)'
$raw     = [IO.File]::ReadAllText($ReadmePath)
$nl      = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$endsNl  = $raw.EndsWith("`n")
$lines   = Get-Content $ReadmePath -Encoding utf8
$changed = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
  $row = $lines[$i]
  if ($row -notmatch '^\s*\|') { continue }            # не строка таблицы
  $link = $linkRe.Match($row)
  if (-not $link.Success) { continue }                  # шапка/разделитель/без ссылки
  $slug = Get-RepoSlug $link.Groups['url'].Value
  if (-not $byRepo.ContainsKey($slug)) { Write-Warning "README: '$slug' нет в манифестах — строка пропущена"; continue }

  $cells = $row.Split('|')
  $ci = -1
  for ($c = 0; $c -lt $cells.Count; $c++) { if ($linkRe.IsMatch($cells[$c])) { $ci = $c; break } }
  if ($ci -lt 0 -or $ci + 1 -ge $cells.Count) { continue }

  $newCell = ' ' + (Format-Version $byRepo[$slug]) + ' '
  if ($cells[$ci + 1] -ne $newCell) {
    $cells[$ci + 1] = $newCell
    $lines[$i] = $cells -join '|'
    $changed = $true
  }
}

if ($Check) {
  if ($changed) { Write-Host "README разошёлся с манифестами — запустите scripts/sync-readme.ps1"; exit 1 }
  Write-Host "README в синхроне с манифестами"; exit 0
}

if ($changed) {
  $text = ($lines -join $nl) + $(if ($endsNl) { $nl } else { '' })
  [IO.File]::WriteAllText($ReadmePath, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "README обновлён."
} else {
  Write-Host "README уже актуален."
}
exit 0
