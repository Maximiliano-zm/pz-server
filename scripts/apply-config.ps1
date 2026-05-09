<#
.SYNOPSIS
  Copia los archivos de config/ al volumen pz-server-config sobreescribiendo
  los que el servidor genero en el primer arranque.

.DESCRIPTION
  Procedimiento:
    1. Para el contenedor (si está corriendo) para que PZ no reescriba el ini.
    2. Copia config/servertest.ini, config/servertest_SandboxVars.lua y
       config/servertest_spawnregions.lua al volumen.
    3. Re-arranca.

.EXAMPLE
  ./apply-config.ps1
#>
[CmdletBinding()]
param(
    [string]$ContainerName = "pz-b42-server",
    [string]$ConfigDir = "$PSScriptRoot/../config"
)

$ConfigDir = (Resolve-Path $ConfigDir).Path
Write-Host "Aplicando configs desde $ConfigDir ..." -ForegroundColor Cyan

# Stop container si está corriendo (PZ reescribe el ini al apagarse)
$running = docker ps --filter "name=$ContainerName" --format '{{.Names}}'
if ($running) {
    Write-Host "Parando contenedor $ContainerName ..." -ForegroundColor Yellow
    docker stop $ContainerName | Out-Null
}

# Copiar via contenedor efímero alpine montando el volumen
$files = @('servertest.ini','servertest_SandboxVars.lua','servertest_spawnregions.lua')
foreach ($f in $files) {
    $local = Join-Path $ConfigDir $f
    if (-not (Test-Path $local)) {
        Write-Host "INFO: $f no existe localmente, se omite." -ForegroundColor DarkYellow
        continue
    }
    Write-Host "  -> $f" -ForegroundColor Green
    # Pasar el archivo via stdin a un sh -c "cat > /dest/file"
    $destPath = "/project-zomboid-config/Server/$f"
    Get-Content -Raw -LiteralPath $local | docker run --rm -i `
        -v pz-server-config:/project-zomboid-config `
        alpine:3.20 sh -c "mkdir -p /project-zomboid-config/Server && cat > $destPath"
}

Write-Host ""
Write-Host "Listo. Arrancando contenedor ..." -ForegroundColor Cyan
docker start $ContainerName | Out-Null
Write-Host "OK. Sigue logs con: docker logs -f $ContainerName" -ForegroundColor Green
