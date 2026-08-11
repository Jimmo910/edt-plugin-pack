# scripts/verify.ps1 — поставить собранный набор на изолированную копию EDT через p2 director
# (Windows-аналог verify.sh). Гейт тот же: ФАКТ установки каждого запрошенного IU, а не код возврата —
# director умеет возвращать 0, не разрешив зависимости.
. "$PSScriptRoot\common.ps1"

function Get-JavaFor([string]$edtHome) {
  # requiredJavaVersion из 1cedt.ini — это МИНИМУМ, а не точное совпадение: EDT 2026.1 (требует 17)
  # штатно стартует на JDK 25 (проверено). Берём подходящую JVM, предпочитая точное совпадение:
  # раньше бралась первая попавшаяся axiom-jdk, и verify линии 2026.1 мог уйти на JDK от 2026.2.
  $ini = Join-Path $edtHome '1cedt.ini'
  $req = 0
  if (Test-Path $ini) {
    $m = Select-String -Path $ini -Pattern '-Dosgi\.requiredJavaVersion=(\d+)' | Select-Object -First 1
    if ($m) { $req = [int]$m.Matches[0].Groups[1].Value }
  }
  $cands = @()
  if ($env:JAVA_HOME) { $cands += (Join-Path $env:JAVA_HOME 'bin\java.exe') }
  $cands += Get-ChildItem (Split-Path $Manifest.jdkGlob) -Directory -Filter (Split-Path $Manifest.jdkGlob -Leaf) -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'bin\java.exe' }
  $best = $null
  foreach ($c in $cands) {
    if (-not (Test-Path $c)) { continue }
    $out = & $c '-version' 2>&1 | Out-String
    if ($out -notmatch 'version "(\d+)') { continue }
    $v = [int]$Matches[1]
    if ($v -lt $req) { continue }
    if (-not $best) { $best = [pscustomobject]@{ Path = $c; Ver = $v } }
    if ($v -eq $req) { $best = [pscustomobject]@{ Path = $c; Ver = $v }; break }
  }
  if (-not $best) { throw "не найдена Java >= $req для $edtHome (искали JAVA_HOME и $($Manifest.jdkGlob))" }
  Write-Host "Java: $($best.Path) (версия $($best.Ver), EDT требует >= $req)"
  return $best.Path
}

$sandbox = Join-Path $Build 'edt-sandbox'
if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
Write-Host "Копирую EDT в песочницу (несколько ГБ, подождите)..." -ForegroundColor Yellow
Copy-Item -Recurse -Force $EdtHome $sandbox
try {

# профиль p2 целевой установки.
# Каталог профиля называется '<id>.profile'; идентификатор профиля для director — это <id>
# без суффикса '.profile'. У КАТАЛОГА .BaseName НЕ отрезает расширение, поэтому режем явно.
$profReg = Join-Path $sandbox 'p2\org.eclipse.equinox.p2.engine\profileRegistry'
$profDir = (Get-ChildItem $profReg -Filter '*.profile' -ErrorAction SilentlyContinue | Select-Object -First 1).Name
if (-not $profDir) { throw "Не найден профиль p2 в $profReg" }
$profileId = $profDir -replace '\.profile$', ''
Write-Host "Профиль: $profileId"

# Проверяем ИМЕННО релизный архив, если он собран: в CI verify ставит из zip
# (`jar:file:…!/`), а не из staging-каталога, и локальная проверка должна повторять тот же путь.
$pkg  = $Manifest.package
$zip  = Join-Path $Dist "$($pkg.name)-$($pkg.edtLine)-$($pkg.version).zip"
if (Test-Path $zip) {
  $repoUri = 'jar:' + (To-FileUri $zip) + '!/'
  Write-Host "Источник: релизный архив $zip"
} else {
  $repoUri = To-FileUri $RepoOut
  Write-Host "Источник: staging-каталог $RepoOut (архив не собран — запустите package.ps1)" -ForegroundColor Yellow
}
$iuList  = @(Get-Content (Join-Path $Build 'ius.txt') | Where-Object { $_ -match '\S' })
$ius     = $iuList -join ','
Write-Host "Ставлю IU: $ius"

# director запускаем из песочницы (ставит в саму себя)
$java = Get-JavaFor $EdtHome; $launcher = Get-Launcher $sandbox
& $java '-jar' $launcher '-nosplash' '-consoleLog' '-application' 'org.eclipse.equinox.p2.director' `
  '-repository' $repoUri '-installIU' $ius '-destination' $sandbox '-profile' $profileId
$dirRc = $LASTEXITCODE
Write-Host "director rc=$dirRc"

# Гейт по ФАКТУ: код возврата director'у не доверяем — проверяем, что каждый IU стал installed root.
$rootsOut = & $java '-jar' $launcher '-nosplash' '-consoleLog' '-application' 'org.eclipse.equinox.p2.director' `
  '-destination' $sandbox '-profile' $profileId '-listInstalledRoots' 2>&1 | Out-String
$missing = @($iuList | Where-Object { $rootsOut -notmatch [regex]::Escape($_) })
if ($missing.Count) {
  Write-Host $rootsOut
  throw "VERIFY FAILED ($EdtHome): не установились — $($missing -join ', ')"
}
Write-Host "VERIFY OK ($EdtHome): установлены все $($iuList.Count) фич" -ForegroundColor Green
}
finally {
  # Песочница — копия EDT на несколько ГБ. Без finally она оставалась на диске при любом
  # провале гейта (в Linux-варианте это закрыто trap'ом, здесь раньше не было).
  if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
}
