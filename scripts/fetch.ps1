# scripts/fetch.ps1 — скачивание релизов плагинов и YAXUnit
. "$PSScriptRoot\common.ps1"
New-Item -ItemType Directory -Force $Downloads, $Sources, (Join-Path $Staging 'yaxunit') | Out-Null

function Resolve-RepoRoot([string]$dir) {
  # вернуть путь к папке, содержащей content.jar/content.xml/compositeContent.xml (учёт вложенной подпапки)
  $hasRepo = { param($d) (Test-Path (Join-Path $d 'content.jar')) -or (Test-Path (Join-Path $d 'content.xml')) -or (Test-Path (Join-Path $d 'compositeContent.xml')) }
  if (& $hasRepo $dir) { return $dir }
  $inner = Get-ChildItem $dir -Directory | Where-Object { & $hasRepo $_.FullName } | Select-Object -First 1
  if ($inner) { return $inner.FullName }
  # некоторые релизы упаковывают сам p2-репозиторий во вложенный zip (например, repository.zip) — распаковать его
  $nestedZip = Get-ChildItem $dir -File -Filter *.zip -Recurse | Select-Object -First 1
  if ($nestedZip) {
    $unpack = Join-Path $dir ('_p2_' + $nestedZip.BaseName)
    Expand-Archive -Path $nestedZip.FullName -DestinationPath $unpack -Force
    if (& $hasRepo $unpack) { return $unpack }
    $innerZip = Get-ChildItem $unpack -Directory | Where-Object { & $hasRepo $_.FullName } | Select-Object -First 1
    if ($innerZip) { return $innerZip.FullName }
  }
  return $null
}

foreach ($p in $Manifest.plugins) {
  if ($p.source.type -eq 'p2-publish') {
    $dest = Join-Path $Sources $p.id
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force (Join-Path $dest 'features'), (Join-Path $dest 'plugins') | Out-Null
    foreach ($u in $p.source.features) { Invoke-WebRequest -Uri $u -OutFile (Join-Path $dest "features\$(Split-Path $u -Leaf)") -UseBasicParsing }
    foreach ($u in $p.source.plugins)  { Invoke-WebRequest -Uri $u -OutFile (Join-Path $dest "plugins\$(Split-Path $u -Leaf)")  -UseBasicParsing }
    $uri = To-FileUri $dest
    Invoke-P2App 'org.eclipse.equinox.p2.publisher.FeaturesAndBundlesPublisher' @('-source',$dest,'-metadataRepository',$uri,'-artifactRepository',$uri,'-publishArtifacts','-compress')
    if (-not (Test-Path (Join-Path $dest 'content.jar')) -and -not (Test-Path (Join-Path $dest 'content.xml'))) { throw "$($p.id): FeaturesAndBundlesPublisher не создал метаданные" }
    Write-Host "OK $($p.id) (published)"
    continue
  }
  $zip = Join-Path $Downloads "$($p.id).zip"
  switch ($p.source.type) {
    'zip' {
      Write-Host "Download $($p.id) <- $($p.source.url)"
      Invoke-WebRequest -Uri $p.source.url -OutFile $zip -UseBasicParsing
    }
    'gitlab-package' {
      $proj = [uri]::EscapeDataString($p.source.project)
      $url  = "https://gitlab.com/api/v4/projects/$proj/packages/generic/$($p.source.package)/$($p.source.packageVersion)/$($p.source.file)"
      Write-Host "Download $($p.id) <- $url"
      Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    }
    default { throw "неизвестный тип источника: $($p.source.type)" }
  }
  $dest = Join-Path $Sources $p.id
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  New-Item -ItemType Directory -Force $dest | Out-Null
  Expand-Archive -Path $zip -DestinationPath $dest -Force
  $repoRoot = Resolve-RepoRoot $dest
  if (-not $repoRoot) { throw "$($p.id): после распаковки не найден p2-репозиторий (content.jar/.xml)" }
  if ($repoRoot -ne $dest) {
    # перенести содержимое p2-репозитория в корень $dest и подчистить обёртки распаковки
    $temp = Join-Path $Sources "_tmp_$($p.id)"
    if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
    Move-Item $repoRoot $temp -Force
    Get-ChildItem $dest -Force | Remove-Item -Recurse -Force
    Get-ChildItem $temp -Force | Move-Item -Destination $dest -Force
    Remove-Item -Recurse -Force $temp
  }
  Write-Host "OK $($p.id)"
}

# YAXUnit (.cfe) — не плагин EDT, кладётся в дистрибутив отдельно
foreach ($a in $Manifest.yaxunit.assets) {
  $name = Split-Path $a -Leaf
  Write-Host "Download YAXUnit asset $name"
  Invoke-WebRequest -Uri $a -OutFile (Join-Path $Staging "yaxunit\$name") -UseBasicParsing
}
Write-Host "FETCH DONE" -ForegroundColor Green
