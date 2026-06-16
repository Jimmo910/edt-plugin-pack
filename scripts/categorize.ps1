# scripts/categorize.ps1 — категории из 5 целевых фич + CategoryPublisher
. "$PSScriptRoot\common.ps1"

function Remove-ForeignCategories([string]$repo, [string[]]$keepIds) {
  $jar = Join-Path $repo 'content.jar'
  if (-not (Test-Path $jar)) { throw "нет content.jar в $repo" }
  $tmp = Join-Path $env:TEMP ('cj_'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $tmp | Out-Null
  Expand-Archive $jar $tmp -Force
  $cx  = Join-Path $tmp 'content.xml'
  $xml = [xml](Get-Content $cx -Raw)
  $unitsNode = $xml.repository.units
  $removed = 0
  foreach ($u in @($unitsNode.unit)) {
    $isCat = $u.properties.property | Where-Object { $_.name -eq 'org.eclipse.equinox.p2.type.category' -and $_.value -eq 'true' }
    if ($isCat -and ($keepIds -notcontains $u.id)) { [void]$unitsNode.RemoveChild($u); $removed++ }
  }
  $unitsNode.SetAttribute('size', [string]([int]$unitsNode.size - $removed))
  $xml.Save($cx)
  Remove-Item $jar -Force
  Compress-Archive -Path $cx -DestinationPath $jar -Force
  Remove-Item -Recurse -Force $tmp
  Write-Host "Удалено чужих категорий: $removed"
}

$cats = $Manifest.categories

function Get-RepoContentXml([string]$repo) {
  if (Test-Path (Join-Path $repo 'content.jar')) {
    $tmp = Join-Path $env:TEMP ('cj_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $tmp | Out-Null
    Expand-Archive (Join-Path $repo 'content.jar') $tmp -Force
    $xml = [xml](Get-Content (Join-Path $tmp 'content.xml') -Raw)
    Remove-Item -Recurse -Force $tmp
    return $xml
  } elseif (Test-Path (Join-Path $repo 'content.xml')) {
    return [xml](Get-Content (Join-Path $repo 'content.xml') -Raw)
  } else { throw "не найден content.jar/content.xml в $repo" }
}
$content = Get-RepoContentXml $RepoOut

$entries = @(); $ius = @()
foreach ($p in $Manifest.plugins) {
  if (-not $p.featureId) { throw "$($p.id): в манифесте нет featureId" }
  $iu = "$($p.featureId).feature.group"
  $unit = $content.repository.units.unit | Where-Object { $_.id -eq $iu } | Select-Object -First 1
  if (-not $unit) { throw "В репозитории не найден IU $iu" }
  $entries += [pscustomobject]@{ id=$p.featureId; ver=$unit.version; cat=$p.category }
  $ius += $iu
}

$sb=[System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<site>')
foreach($e in $entries){ [void]$sb.AppendLine("  <feature id=`"$($e.id)`" version=`"$($e.ver)`"><category name=`"$($cats.$($e.cat).id)`"/></feature>") }
foreach($key in $cats.PSObject.Properties.Name){ $c=$cats.$key; [void]$sb.AppendLine("  <category-def name=`"$($c.id)`" label=`"$($c.label)`"><description>$($c.description)</description></category-def>") }
[void]$sb.AppendLine('</site>')
$catFile = Join-Path $Root 'p2\category.xml'
New-Item -ItemType Directory -Force (Split-Path $catFile) | Out-Null
Set-Content -Path $catFile -Value $sb.ToString() -Encoding UTF8
New-Item -ItemType Directory -Force $Build | Out-Null
Set-Content -Path (Join-Path $Build 'ius.txt') -Value ($ius | Sort-Object -Unique) -Encoding UTF8

# ВАЖНО: '-categoryQualifier' с ПУСТЫМ значением даёт чистые id категорий
# (edt.pack.main / edt.pack.mcp). Если убрать аргумент совсем, CategoryPublisher
# использует location category.xml как префикс id (file:////.../category.xml.edt.pack.main).
# См. SiteXMLAction.buildCategoryId: qualifier=="" -> вернуть имя как есть; qualifier==null -> префикс URI.
Invoke-P2App 'org.eclipse.equinox.p2.publisher.CategoryPublisher' @(
  '-metadataRepository', (To-FileUri $RepoOut),
  '-categoryDefinition', (To-FileUri $catFile),
  '-categoryQualifier', ''
)
Remove-ForeignCategories $RepoOut @('edt.pack.main','edt.pack.mcp')
Write-Host "CATEGORIZE DONE" -ForegroundColor Green
