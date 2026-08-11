# scripts/check-updates.ps1 — проверка новых версий плагинов.
# -DryRun: только отчёт. Без флага: обновляет манифест (env MANIFEST) и бампит package.version (патч).
# Устойчивость: ошибка по одному плагину НЕ валит весь прогон (try/catch + предупреждение).
# Пины: update.hold=true — плагин не бампится (напр. известная несовместимость новой версии).
param([switch]$DryRun)
. "$PSScriptRoot\common.ps1"
$manifestPath = $ManifestPath
$m = Get-Content $manifestPath -Raw | ConvertFrom-Json
$changes = @()
# Считаем проверенное и упавшее: ошибка по одному плагину не должна валить прогон, но если
# НЕ ОТВЕТИЛ НИ ОДИН источник (сеть, лимит GitHub API, протухший токен), результат «обновлений
# нет» — ложь. Раньше такой прогон был зелёным и молчал, и набор тихо переставал обновляться.
$checked = 0
$failed  = @()

# gh api при HTTP-ошибке печатает тело ошибки В STDOUT и выходит с кодом 1, исключения при этом
# НЕТ даже при $ErrorActionPreference='Stop'. Раньше этот JSON разбирался как релиз: у объекта
# {message,status} нет ни tag_name, ни draft, поэтому фильтр `-not $_.draft` его пропускал,
# tag_name оказывался пустым, и пустая строка засчитывалась как НОВАЯ ВЕРСИЯ. Итог был бы
# катастрофический и тихий: version="" в манифесте, assets=[], зелёный релиз без YAXUnit.
# Поэтому: проверяем код возврата и требуем непустой tag_name.
function Invoke-GhJson([string]$path) {
  $out = gh api $path 2>$null
  if ($LASTEXITCODE -ne 0) { throw "gh api $path -> код $LASTEXITCODE" }
  if (-not $out) { throw "gh api $path вернул пустой ответ" }
  return ($out | ConvertFrom-Json)
}
function Get-GhLatest($repo) {
  $j = $null
  # releases/latest исключает pre-release/draft -> 404 для репозиториев, где все релизы prerelease
  # (напр. ZigRinat85/PluginEDT). Это ОЖИДАЕМЫЙ отказ, поэтому глушим его и идём в fallback.
  try { $j = Invoke-GhJson "repos/$repo/releases/latest" } catch { $j = $null }
  if (-not $j -or -not $j.tag_name) {
    # А вот ошибка полного списка — уже настоящий отказ: пусть валит проверку этого плагина.
    $all = Invoke-GhJson "repos/$repo/releases?per_page=100"
    $j = $all | Where-Object { $_.tag_name -and -not $_.draft } | Select-Object -First 1
  }
  if (-not $j -or -not $j.tag_name) { throw "не удалось получить релизы $repo (нужен gh/GH_TOKEN)" }
  return $j
}
function Asset-Url($rel, $pattern) {
  $a = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
  if (-not $a) { throw "ассет по шаблону '$pattern' не найден в релизе $($rel.tag_name)" }
  return $a.browser_download_url
}

if ($m.yaxunit.update) {
  $checked++
  try {
    $rel = Get-GhLatest $m.yaxunit.update.repo
    $nv = ($rel.tag_name -replace '^v','')
    if (-not $nv) { throw "пустая версия в релизе $($m.yaxunit.update.repo)" }
    if ($nv -ne $m.yaxunit.version) {
      # Ассеты резолвим ДО записи в манифест и в DryRun тоже: так шаблон проверяется всегда,
      # а неудача не оставляет манифест с новой версией и старыми/пустыми ссылками.
      $urls = @($rel.assets | Where-Object { $_.name -match $m.yaxunit.update.asset } | ForEach-Object { $_.browser_download_url })
      if (-not $urls.Count) { throw "в релизе $nv нет ассетов по шаблону '$($m.yaxunit.update.asset)'" }
      $changes += "YAXUnit: $($m.yaxunit.version) -> $nv"
      if (-not $DryRun) { $m.yaxunit.version = $nv; $m.yaxunit.assets = $urls }
    }
  } catch { Write-Warning "YAXUnit: пропуск проверки — $($_.Exception.Message)"; $failed += 'YAXUnit' }
}

foreach ($p in $m.plugins) {
  if (-not $p.update) { continue }
  if ($p.update.hold) { Write-Host "  $($p.id): hold (пин зафиксирован) — пропуск"; continue }
  $checked++
  try {
    switch ($p.update.kind) {
      # ПОРЯДОК ВАЖЕН: сначала резолвим ассеты (может бросить), и только потом трогаем манифест.
      # Раньше версия присваивалась первой, и падение Asset-Url оставляло в манифесте новую
      # версию со старой ссылкой — а при наличии любого другого обновления это уезжало в main.
      'gh-release' {
        $rel = Get-GhLatest $p.update.repo; $nv = $rel.tag_name -replace '^v',''
        if (-not $nv) { throw "пустая версия в релизе $($p.update.repo)" }
        if ($nv -ne $p.version) {
          $url = Asset-Url $rel $p.update.asset
          $changes += "$($p.id): $($p.version) -> $nv"
          if (-not $DryRun) { $p.version = $nv; $p.source.url = $url }
        }
      }
      'gh-jars' {
        $rel = Get-GhLatest $p.update.repo; $nv = $rel.tag_name -replace '^v',''
        if (-not $nv) { throw "пустая версия в релизе $($p.update.repo)" }
        if ($nv -ne $p.version) {
          $feat = Asset-Url $rel $p.update.featureAsset
          $plug = Asset-Url $rel $p.update.pluginAsset
          $changes += "$($p.id): $($p.version) -> $nv"
          if (-not $DryRun) { $p.version = $nv; $p.source.features = @($feat); $p.source.plugins = @($plug) }
        }
      }
      'gitlab-package' {
        $proj = [uri]::EscapeDataString($p.update.project)
        $pkgs = Invoke-RestMethod "https://gitlab.com/api/v4/projects/$proj/packages?per_page=100"
        $cand = $pkgs | Where-Object { $_.name -eq $p.update.package } | Sort-Object { try { [version]$_.version } catch { [version]'0.0' } } -Descending | Select-Object -First 1
        if ($cand -and $cand.version -ne $p.version) { $changes += "$($p.id): $($p.version) -> $($cand.version)"; if (-not $DryRun) { $p.version = $cand.version; $p.source.packageVersion = $cand.version } }
      }
      default { throw "неизвестный update.kind '$($p.update.kind)'" }
    }
  } catch { Write-Warning "$($p.id): пропуск обновления — $($_.Exception.Message)"; $failed += $p.id }
}

if ($failed.Count) { Write-Warning ("Не удалось проверить $($failed.Count) из $checked источников: " + ($failed -join ', ')) }
# «Обновлений нет» достоверно только если проверено ВСЁ. Прежнее условие (упали все источники)
# ловило лишь тотальный отказ: при недоступности одного провайдера — скажем, GitHub API при живом
# GitLab — прогон снова был бы зелёным и молчаливым. Если же что-то обновилось, идём дальше:
# частичный отказ порядок присваиваний выше уже сделал безопасным.
if ($failed.Count -and $changes.Count -eq 0) {
  throw "проверка неполна: не ответили $($failed.Count) из $checked источников ($($failed -join ', ')) — «обновлений нет» недостоверно"
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
