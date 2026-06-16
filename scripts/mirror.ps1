# scripts/mirror.ps1 — свести все sources/* в один p2-репозиторий build/repository
. "$PSScriptRoot\common.ps1"
if (Test-Path $RepoOut) { Remove-Item -Recurse -Force $RepoOut }
New-Item -ItemType Directory -Force $RepoOut | Out-Null
$destUri = To-FileUri $RepoOut
foreach ($p in $Manifest.plugins) {
  $srcUri = To-FileUri (Join-Path $Sources $p.id)
  Invoke-P2App 'org.eclipse.equinox.p2.metadata.repository.mirrorApplication' @('-source',$srcUri,'-destination',$destUri,'-writeMode','append')
  Invoke-P2App 'org.eclipse.equinox.p2.artifact.repository.mirrorApplication' @('-source',$srcUri,'-destination',$destUri,'-writeMode','append')
}
Write-Host "MIRROR DONE" -ForegroundColor Green
