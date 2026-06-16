# scripts/common.ps1 — общие переменные и хелперы. Точка входа: . "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
$script:Root      = Split-Path -Parent $PSScriptRoot
# Манифест выбирается через env MANIFEST (путь относительно корня), иначе — 2025.2 по умолчанию.
$script:ManifestPath = if ($env:MANIFEST) { Join-Path $Root $env:MANIFEST } else { Join-Path $Root 'manifests/2025.2.json' }
if (-not (Test-Path $ManifestPath)) { throw "Манифест не найден: $ManifestPath (env MANIFEST=$($env:MANIFEST))" }
$script:Manifest  = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$script:Build     = Join-Path $Root 'build'
$script:Downloads = Join-Path $Build 'downloads'
$script:Sources   = Join-Path $Build 'sources'
$script:RepoOut   = Join-Path $Build 'repository'
$script:Staging   = Join-Path $Build 'staging'
$script:Dist      = Join-Path $Build 'dist'
# Путь к Eclipse/EDT: ECLIPSE_HOME или EDT_HOME из окружения имеют приоритет
# (для CI на ванильном Eclipse); иначе — edtHome из манифеста (локальная EDT).
$script:EdtHome   = if ($env:ECLIPSE_HOME) { $env:ECLIPSE_HOME } elseif ($env:EDT_HOME) { $env:EDT_HOME } else { $Manifest.edtHome }

function Get-Java {
  # JAVA_HOME из окружения имеет приоритет (CI: actions/setup-java). Иначе — JDK-компонент EDT.
  if ($env:JAVA_HOME) {
    foreach ($b in @('bin/java.exe','bin/java')) { $j = Join-Path $env:JAVA_HOME $b; if (Test-Path $j) { return $j } }
  }
  $jdk = Get-ChildItem (Split-Path $Manifest.jdkGlob) -Directory -Filter (Split-Path $Manifest.jdkGlob -Leaf) -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $jdk) { throw "JDK не найден: задайте JAVA_HOME или установите по пути $($Manifest.jdkGlob)" }
  foreach ($b in @('bin/java.exe','bin/java')) { $j = Join-Path $jdk.FullName $b; if (Test-Path $j) { return $j } }
  throw "java не найден в $($jdk.FullName)/bin"
}
function Get-Launcher([string]$edtHome = $script:EdtHome) {
  $l = Get-ChildItem (Join-Path $edtHome 'plugins') -Filter 'org.eclipse.equinox.launcher_*.jar' | Select-Object -First 1
  if (-not $l) { throw "equinox launcher не найден в $edtHome\plugins" }
  $l.FullName
}
# Возвращаем file:-URI в РАСКОДИРОВАННОМ виде (без percent-encoding).
# Причина: при кириллическом пути проекта (НаборПлагинов…) p2-приложения повторно
# кодируют %-последовательности (%D0 -> %25D0) и не находят репозиторий. Литеральная
# форма с кириллицей принимается корректно. В наших путях пробелов нет, поэтому
# раскодирование %20 безопасно.
function To-FileUri([string]$path) { [uri]::UnescapeDataString((([uri]((Resolve-Path $path).Path)).AbsoluteUri)) }
function Invoke-P2App([string]$app, [string[]]$appArgs, [string]$edtHome = $script:EdtHome) {
  $java = Get-Java; $launcher = Get-Launcher $edtHome
  Write-Host ">> p2: $app" -ForegroundColor Cyan
  & $java '-jar' $launcher '-nosplash' '-consoleLog' '-application' $app @appArgs
  if ($LASTEXITCODE -ne 0) { throw "p2-приложение $app завершилось с кодом $LASTEXITCODE" }
}
