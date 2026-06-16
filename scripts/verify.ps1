# scripts/verify.ps1 — поставить собранный набор на изолированную копию EDT через p2 director
. "$PSScriptRoot\common.ps1"
$sandbox = Join-Path $Build 'edt-sandbox'
if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
Write-Host "Копирую EDT в песочницу (несколько ГБ, подождите)..." -ForegroundColor Yellow
Copy-Item -Recurse -Force $EdtHome $sandbox

# профиль p2 целевой установки.
# Каталог профиля называется '<id>.profile'; идентификатор профиля для director — это <id>
# без суффикса '.profile'. У КАТАЛОГА .BaseName НЕ отрезает расширение, поэтому режем явно.
$profReg = Join-Path $sandbox 'p2\org.eclipse.equinox.p2.engine\profileRegistry'
$profDir = (Get-ChildItem $profReg -Filter '*.profile' -ErrorAction SilentlyContinue | Select-Object -First 1).Name
if (-not $profDir) { throw "Не найден профиль p2 в $profReg" }
$profileId = $profDir -replace '\.profile$', ''
Write-Host "Профиль: $profileId"

$repoUri = To-FileUri $RepoOut
$ius = (Get-Content (Join-Path $Build 'ius.txt') | Where-Object { $_ -match '\S' }) -join ','
Write-Host "Ставлю IU: $ius"

# director запускаем из песочницы (ставит в саму себя)
$java = Get-Java; $launcher = Get-Launcher $sandbox
& $java '-jar' $launcher '-nosplash' '-consoleLog' '-application' 'org.eclipse.equinox.p2.director' `
  '-repository' $repoUri '-installIU' $ius '-destination' $sandbox '-profile' $profileId
if ($LASTEXITCODE -ne 0) { throw "director: установка завершилась с кодом $LASTEXITCODE" }

# проверить, что IU реально установлены
& $java '-jar' $launcher '-nosplash' '-consoleLog' '-application' 'org.eclipse.equinox.p2.director' `
  '-destination' $sandbox '-profile' $profileId '-listInstalledRoots'
Write-Host "VERIFY DONE" -ForegroundColor Green
