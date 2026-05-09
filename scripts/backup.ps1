<#
.SYNOPSIS
  Crea un snapshot tar.gz del volumen pz-server-config (incluye Saves, ini,
  Lua y Logs). Imprescindible antes de cada `docker pull` en la rama
  unstable, porque los saves pueden romperse entre actualizaciones.

.EXAMPLE
  ./backup.ps1
  ./backup.ps1 -OutputDir D:\pz-backups
#>
[CmdletBinding()]
param(
    [string]$OutputDir = "$PSScriptRoot/../backups",
    [string]$ContainerName = "pz-b42-server"
)

$OutputDir = if (Test-Path $OutputDir) { (Resolve-Path $OutputDir).Path } else {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    (Resolve-Path $OutputDir).Path
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$file  = "pz-server-config-$stamp.tar.gz"

Write-Host "Snapshot del volumen pz-server-config -> $OutputDir\$file" -ForegroundColor Cyan

# Pausa el contenedor para una snapshot consistente
$running = docker ps --filter "name=$ContainerName" --format '{{.Names}}'
if ($running) {
    Write-Host "Pausando contenedor para snapshot consistente..." -ForegroundColor Yellow
    docker pause $ContainerName | Out-Null
}

# Linux paths inside the WSL VM are case-sensitive
$wslOut = "/" + ($OutputDir -replace '\\','/' -replace ':','').ToLower()

docker run --rm `
    -v pz-server-config:/data:ro `
    -v "${OutputDir}:/backup" `
    alpine:3.20 sh -c "cd /data && tar czf /backup/$file ."

if ($running) {
    docker unpause $ContainerName | Out-Null
}

if (Test-Path "$OutputDir\$file") {
    $size = (Get-Item "$OutputDir\$file").Length / 1MB
    Write-Host ("OK. {0:N1} MB" -f $size) -ForegroundColor Green
} else {
    Write-Host "ERROR: snapshot no se creo." -ForegroundColor Red
    exit 1
}
