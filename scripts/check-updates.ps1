# scripts/check-updates.ps1 — проверка новых версий плагинов.
# -DryRun: только отчёт. Без флага: обновляет манифест (env MANIFEST) и бампит package.version (патч).
# Устойчивость: ошибка по одному плагину НЕ валит весь прогон (try/catch + предупреждение).
# Пины: update.hold=true — плагин не бампится (напр. известная несовместимость новой версии).
param([switch]$DryRun)
. "$PSScriptRoot\common.ps1"
$manifestPath = $ManifestPath
$m = Get-Content $manifestPath -Raw | ConvertFrom-Json
$changes = @()

function Get-GhLatest($repo) {
  $j = gh api "repos/$repo/releases/latest" 2>$null | ConvertFrom-Json
  # releases/latest исключает pre-release/draft -> 404 для репозиториев, где все релизы prerelease
  # (напр. ZigRinat85/PluginEDT). Тогда берём самый свежий не-draft из полного списка.
  if (-not $j -or -not $j.tag_name) {
    $all = gh api "repos/$repo/releases?per_page=100" 2>$null | ConvertFrom-Json
    $j = $all | Where-Object { -not $_.draft } | Select-Object -First 1
  }
  if (-not $j) { throw "не удалось получить релизы $repo (нужен gh/GH_TOKEN)" }
  return $j
}
function Asset-Url($rel, $pattern) {
  $a = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
  if (-not $a) { throw "ассет по шаблону '$pattern' не найден в релизе $($rel.tag_name)" }
  return $a.browser_download_url
}

if ($m.yaxunit.update) {
  try {
    $rel = Get-GhLatest $m.yaxunit.update.repo
    $nv = $rel.tag_name -replace '^v',''
    if ($nv -ne $m.yaxunit.version) {
      $changes += "YAXUnit: $($m.yaxunit.version) -> $nv"
      if (-not $DryRun) {
        $m.yaxunit.version = $nv
        $m.yaxunit.assets = @($rel.assets | Where-Object { $_.name -match $m.yaxunit.update.asset } | ForEach-Object { $_.browser_download_url })
      }
    }
  } catch { Write-Warning "YAXUnit: пропуск проверки — $($_.Exception.Message)" }
}

foreach ($p in $m.plugins) {
  if (-not $p.update) { continue }
  if ($p.update.hold) { Write-Host "  $($p.id): hold (пин зафиксирован) — пропуск"; continue }
  try {
    switch ($p.update.kind) {
      'gh-release' {
        $rel = Get-GhLatest $p.update.repo; $nv = $rel.tag_name -replace '^v',''
        if ($nv -ne $p.version) { $changes += "$($p.id): $($p.version) -> $nv"; if (-not $DryRun) { $p.version = $nv; $p.source.url = (Asset-Url $rel $p.update.asset) } }
      }
      'gh-jars' {
        $rel = Get-GhLatest $p.update.repo; $nv = $rel.tag_name -replace '^v',''
        if ($nv -ne $p.version) { $changes += "$($p.id): $($p.version) -> $nv"; if (-not $DryRun) { $p.version = $nv; $p.source.features = @(Asset-Url $rel $p.update.featureAsset); $p.source.plugins = @(Asset-Url $rel $p.update.pluginAsset) } }
      }
      'gitlab-package' {
        $proj = [uri]::EscapeDataString($p.update.project)
        $pkgs = Invoke-RestMethod "https://gitlab.com/api/v4/projects/$proj/packages?per_page=100"
        $cand = $pkgs | Where-Object { $_.name -eq $p.update.package } | Sort-Object { try { [version]$_.version } catch { [version]'0.0' } } -Descending | Select-Object -First 1
        if ($cand -and $cand.version -ne $p.version) { $changes += "$($p.id): $($p.version) -> $($cand.version)"; if (-not $DryRun) { $p.version = $cand.version; $p.source.packageVersion = $cand.version } }
      }
      default { throw "неизвестный update.kind '$($p.update.kind)'" }
    }
  } catch { Write-Warning "$($p.id): пропуск обновления — $($_.Exception.Message)" }
}

if ($changes.Count -eq 0) {
  Write-Host "Обновлений нет — все версии актуальны (или удержаны/пропущены)."
  if ($env:GITHUB_OUTPUT) { "changed=false" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8 }
  return
}
Write-Host ("Найдены обновления:`n  " + ($changes -join "`n  "))
if ($DryRun) { if ($env:GITHUB_OUTPUT) { "changed=true" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8 }; return }

$v = [version]$m.package.version
$m.package.version = "$($v.Major).$($v.Minor).$($v.Build + 1)"
$m | ConvertTo-Json -Depth 12 | Set-Content -Path $manifestPath -Encoding UTF8
Write-Host "$manifestPath обновлён; версия пакета -> $($m.package.version)"
if ($env:GITHUB_OUTPUT) {
  "changed=true"  | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
  "summary=$($changes -join '; ')" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
  "version=$($m.package.version)"  | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
}
