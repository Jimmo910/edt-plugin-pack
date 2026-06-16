# scripts/package.ps1 — собрать дистрибутив и заархивировать
. "$PSScriptRoot\common.ps1"
$pkg = $Manifest.package
$distName = "$($pkg.name)-$($pkg.edtLine)-$($pkg.version)"
$out = Join-Path $Staging $distName
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out, (Join-Path $out 'licenses') | Out-Null

# p2-репозиторий кладём в КОРЕНЬ комплекта (чтобы архив ставился напрямую через Add -> Archive).
# yaxunit/ и licenses/ — рядом; Eclipse при установке их игнорирует.
Copy-Item -Recurse (Join-Path $RepoOut '*') $out
# yaxunit (скачан в fetch -> build/staging/yaxunit)
Copy-Item -Recurse (Join-Path $Staging 'yaxunit') (Join-Path $out 'yaxunit')
# licenses
Copy-Item (Join-Path $Root 'licenses\*.txt') (Join-Path $out 'licenses')

# NOTICES.md
$n = [System.Text.StringBuilder]::new()
[void]$n.AppendLine("# Состав и лицензии`n")
[void]$n.AppendLine("Все плагины включены в неизменённом виде. Тексты лицензий — в папке licenses/.`n")
foreach ($p in $Manifest.plugins) {
  [void]$n.AppendLine("## $($p.name) ($($p.version))")
  [void]$n.AppendLine("- Лицензия: $($p.license)")
  [void]$n.AppendLine("- Источник: $($p.repoUrl)")
  if ($p.license -like 'AGPL*') { [void]$n.AppendLine("- Исходный код (Corresponding Source, AGPL §6): $($p.repoUrl) (тег v$($p.version))") }
  [void]$n.AppendLine("")
}
[void]$n.AppendLine("## YAXUnit ($($Manifest.yaxunit.version))")
[void]$n.AppendLine("- Лицензия: $($Manifest.yaxunit.license)")
[void]$n.AppendLine("- Источник: https://github.com/bia-technologies/yaxunit")
Set-Content (Join-Path $out 'licenses\NOTICES.md') $n.ToString() -Encoding UTF8

# yaxunit/README.txt
$yax = @"
YAXUnit — расширение конфигурации 1С (не плагин EDT)
====================================================
Файл YAxUnit-$($Manifest.yaxunit.version).cfe — расширение конфигурации 1С,
которое нужно для работы плагина edt-test-runner. Установка:
  Конфигуратор -> Расширения конфигурации -> добавить YAxUnit-$($Manifest.yaxunit.version).cfe
  (либо импортировать как расширение в EDT-проект).
Smoke-$($Manifest.yaxunit.version).cfe — демонстрационные smoke-тесты (опционально).
Инструкция: https://bia-technologies.github.io/yaxunit/docs/getting-started/install/
Лицензия: $($Manifest.yaxunit.license)
"@
Set-Content (Join-Path $out 'yaxunit\README.txt') $yax -Encoding UTF8

# README.txt (корень)
$readme = @"
Набор плагинов 1C:EDT ($($pkg.edtLine), v$($pkg.version))
=========================================================

1. УСТАНОВКА ПЛАГИНОВ EDT
   В 1C:EDT: Справка -> Установить новое ПО (Install New Software) -> Add... -> Archive...
   Выбрать ЭТОТ архив ($distName.zip).
   Внизу СНЯТЬ галку "Обращаться ко всем сайтам обновления..." (чтобы p2 не лез
   на посторонние, возможно мёртвые, сайты — ставим только из этого архива).
   Отметить категорию "Набор плагинов 1C:EDT" (ставит все плагины разом).
   Категория "EDT MCP (AGPL-3.0)" — опционально (см. licenses/NOTICES.md).
   Принять лицензии, "Install anyway" на предупреждении о подписи, перезапустить EDT.

   (Этот архив — он же p2 update site: папки yaxunit/ и licenses/ Eclipse игнорирует.)

2. УСТАНОВКА YAXUNIT (нужен для плагина edt-test-runner)
   YAXUnit — это расширение конфигурации 1С (.cfe), НЕ плагин EDT.
   См. yaxunit/README.txt.

ЛИЦЕНЗИИ: см. licenses/ и licenses/NOTICES.md
"@
Set-Content (Join-Path $out 'README.txt') $readme -Encoding UTF8

# zip: единый комплект — p2-репозиторий в корне (ставится через Add -> Archive)
# + yaxunit/ + licenses/ + README. Один файл = и установщик, и комплект.
New-Item -ItemType Directory -Force $Dist | Out-Null
$zipPath = Join-Path $Dist "$distName.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zipPath
Write-Host "PACKAGE DONE -> $zipPath (Install New Software -> Add -> Archive)" -ForegroundColor Green
