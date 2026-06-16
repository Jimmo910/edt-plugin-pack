# scripts/ci-validate.ps1 — облачная smoke-проверка БЕЗ установки на EDT.
# Проверяет, что метаданные собранного репозитория валидны (p2 director их читает)
# и что все целевые фичи (build/ius.txt) реально присутствуют в репозитории.
# Полную проверку установки на 1C:EDT см. scripts/verify.ps1 (локально / self-hosted).
. "$PSScriptRoot\common.ps1"
$ius = Get-Content (Join-Path $Build 'ius.txt') | Where-Object { $_ -match '\S' }
$java = Get-Java; $launcher = Get-Launcher
$repoUri = To-FileUri $RepoOut
$out = & $java '-jar' $launcher '-nosplash' '-consoleLog' '-application' 'org.eclipse.equinox.p2.director' '-repository' $repoUri '-list' 2>&1
if ($LASTEXITCODE -ne 0) { $out | Out-String | Write-Host; throw "director -list завершился с кодом $LASTEXITCODE (метаданные невалидны)" }
$text = ($out | Out-String)
$missing = @()
foreach ($iu in $ius) { if ($text -notmatch [regex]::Escape($iu)) { $missing += $iu } }
if ($missing.Count) { Write-Host $text; throw "В репозитории не найдены IU: $($missing -join ', ')" }
Write-Host "CI VALIDATE OK: все $($ius.Count) фич присутствуют, метаданные репозитория валидны" -ForegroundColor Green
