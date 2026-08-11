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
# Нормализация версии для СРАВНЕНИЯ (не для записи): обрезаем суффиксы (-rc1, +2) и добиваем
# до трёх компонент. Без добивки [version]'1.2' -lt [version]'1.2.0' истинно (Build = -1), и
# апстрим, выпустивший «0.7» вместо «0.7.0», ложно выглядел бы откатом.
function ConvertTo-CmpVersion([string]$s) {
  if (-not $s) { return $null }
  $t = ($s -split '[^0-9.]')[0].Trim('.')
  if (-not $t) { return $null }
  $p = @($t -split '\.' | Where-Object { $_ -ne '' })
  if (-not $p.Count) { return $null }
  while ($p.Count -lt 3) { $p += '0' }
  try { [version]($p[0..2] -join '.') } catch { $null }
}
# Пропажа релиза не должна молча откатывать набор назад. Раньше защита стояла только на
# gitlab-package, а 7 из 8 источников — gh-release/gh-jars: там перетегирование апстрима или
# хотфикс к старой ветке (у PluginEDT все релизы pre-release, берётся самый свежий ПО ДАТЕ,
# а не по версии) откатывал бы версию и ссылку без единого предупреждения.
function Assert-NotDowngrade([string]$id, [string]$old, [string]$new, [string]$where) {
  $o = ConvertTo-CmpVersion $old
  $n = ConvertTo-CmpVersion $new
  if ($o -and $n -and $n -lt $o) { throw "$id : в $where максимальная версия $new младше текущей $old — похоже на пропажу релиза, а не на обновление" }
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
          Assert-NotDowngrade $p.id $p.version $nv "релизах $($p.update.repo)"
          $url = Asset-Url $rel $p.update.asset
          $changes += "$($p.id): $($p.version) -> $nv"
          if (-not $DryRun) { $p.version = $nv; $p.source.url = $url }
        }
      }
      'gh-jars' {
        $rel = Get-GhLatest $p.update.repo; $nv = $rel.tag_name -replace '^v',''
        if (-not $nv) { throw "пустая версия в релизе $($p.update.repo)" }
        if ($nv -ne $p.version) {
          Assert-NotDowngrade $p.id $p.version $nv "релизах $($p.update.repo)"
          $feat = Asset-Url $rel $p.update.featureAsset
          $plug = Asset-Url $rel $p.update.pluginAsset
          $changes += "$($p.id): $($p.version) -> $nv"
          if (-not $DryRun) { $p.version = $nv; $p.source.features = @($feat); $p.source.plugins = @($plug) }
        }
      }
      'gitlab-package' {
        $proj = [uri]::EscapeDataString($p.update.project)
        $pkgs = Invoke-RestMethod "https://gitlab.com/api/v4/projects/$proj/packages?per_page=100"
        # Сортируем той же нормализацией, что и сравниваем: со старым `try { [version] }` версии
        # вида 2026.1.2+2 или 1.0.0-rc1 схлопывались в 0.0, сортировка вырождалась, и «самым
        # свежим» оказывался произвольный элемент в порядке ответа API.
        $cand = $pkgs | Where-Object { $_.name -eq $p.update.package } |
                Sort-Object { $v = ConvertTo-CmpVersion $_.version; if ($v) { $v } else { [version]'0.0.0' } } -Descending |
                Select-Object -First 1
        # Пустой результат — это ОТКАЗ, а не «обновлений нет»: проект переименован, пакет удалён,
        # ушли за 100 записей, поменялся формат ответа. Раньше такой случай не попадал ни в
        # $changes, ни в $failed, и прогон был зелёным и молчаливым.
        if (-not $cand) { throw "в проекте $($p.update.project) не найден пакет '$($p.update.package)'" }
        if ($cand.version -ne $p.version) {
          Assert-NotDowngrade $p.id $p.version $cand.version "пакетах $($p.update.project)"
          $changes += "$($p.id): $($p.version) -> $($cand.version)"
          if (-not $DryRun) { $p.version = $cand.version; $p.source.packageVersion = $cand.version }
        }
      }
      default { throw "неизвестный update.kind '$($p.update.kind)'" }
    }
  } catch { Write-Warning "$($p.id): пропуск обновления — $($_.Exception.Message)"; $failed += $p.id }
}

# Любой неотвеченный источник валит проверку — независимо от того, обновилось ли что-то ещё.
# Мягкий вариант (падать только когда изменений нет) оставлял немой сценарий: один апстрим
# недоступен, другой обновился — прогон зелёный, релиз выходит, и никто не знает, что часть
# плагинов не проверялась. Write-Warning в зелёном прогоне не даёт ни issue, ни письма.
# Цена — пропуск недели обновлений при разовом сбое апстрима; она ниже, чем тихая неполнота.
if ($failed.Count) {
  throw "проверка неполна: не ответили $($failed.Count) из $checked источников ($($failed -join ', ')) — результату доверять нельзя"
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
  # summary строится из tag_name сторонних репозиториев, поэтому пишем его многострочной формой
  # с делимитером: перевод строки в однострочном `key=value` позволил бы подменить соседние
  # outputs (например version=). Тот же класс, что уже закрыт для `run:` через env:.
  $d = 'EOF_' + [guid]::NewGuid().ToString('N')
  "changed=true"  | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
  # Пишем строго с LF: Out-File на Windows добавил бы CRLF, и закрывающая строка делимитера
  # приехала бы как "EOF_xxx\r" — раннер ответил бы «matching delimiter not found».
  [IO.File]::AppendAllText($env:GITHUB_OUTPUT, "summary<<$d`n$($changes -join '; ')`n$d`n", [Text.UTF8Encoding]::new($false))
  "version=$($m.package.version)"  | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
}
