<#
.SYNOPSIS
  Extrae los Mod IDs textuales de los mods descargados via Workshop por el
  servidor PZ Build 42 dentro del contenedor `pz-b42-server`.

.DESCRIPTION
  Tras el primer arranque del contenedor (que descarga los 75 mods), este
  script:
    1. Lista cada carpeta /project-zomboid-config/Workshop/<workshop_id>/mods/<mod>/
    2. Lee `id=` de cada `mod.info`
    3. Mapea cada Workshop ID al Mod ID textual
    4. Emite la línea `Mods=` en el ORDEN DE TIER definido en el plan
       (frameworks → core → fixes → vehículos → contenido)
    5. Genera dos versiones: con y sin backslash (B42 puede requerir `\`)

.EXAMPLE
  ./extract-mod-ids.ps1
  ./extract-mod-ids.ps1 -ContainerName pz-b42-server -OutputFile ../mods-line.txt

.NOTES
  Requiere que el contenedor esté corriendo (o al menos que el volumen
  pz-server-config esté poblado).
#>
[CmdletBinding()]
param(
    [string]$ContainerName = "pz-b42-server",
    [string]$OutputFile = "$PSScriptRoot/../mods-line.txt"
)

# Orden de tier (Workshop IDs). El que NO aparezca aquí se añade al final.
$tierOrder = @(
    # Tier 1 - Frameworks/Libs
    '2896041179','3077900375','3171167894','3389605231','3378285185','3508537032',
    # Tier 2 - UI/Core mechanics (FIX al final del tier)
    '2950902979','3397561666','3044609444','3448345776','3713662067','3451167732','3503201938','3461263912','3642084851',
    # Tier 3 - QoL/Crafting (FIX al final del tier)
    '3486217110','3502080466','2875848298','3714335263','2366717227','2142622992','2907834593','2883755057','2944344655','2956146279','3414409419','2710167561','3554048011','2503622437','2544353492',
    # Tier 4 - Gameplay/Traits
    '1299328280','3494474677','3388017161','3426448380','3404074048','3621388762','3683880154',
    # Tier 5 - Combat/Firearms
    '3309896124','3634876505','3389448389','3420478458','3394588830','3616176188',
    # Tier 6 - NPCs/Trading (caros)
    '3268487204','3469292499','3635333613',
    # Tier 7 - Vehículos
    '3281755175','3435796523','3073430075','2886833398','2443275640','2441990998','3642935062','3614034284','3543229299','3330403100',
    # Tier 8 - Vehicle utilities
    '3635591071','3442862183','3632134603','3635856965','3428369137','2584112711',
    # Tier 9 - Mapas/Misc
    '3413150945','3618557184','3572564421','3669550831','2866258937','3641048285','3642554378','3671176591','3579640010','3629835761'
)

Write-Host "Buscando mods descargados en el contenedor $ContainerName..." -ForegroundColor Cyan

$running = docker ps --filter "name=$ContainerName" --format '{{.Names}}'
if (-not $running) {
    Write-Host "El contenedor no esta corriendo. Arrancando temporalmente para inspeccionar el volumen..." -ForegroundColor Yellow
    $useEphemeral = $true
} else {
    $useEphemeral = $false
}

# Comando shell para listar todos los mod.info y emitir 'workshopId<TAB>modId' por linea.
$shellCmd = @'
find /project-zomboid-config/Workshop -mindepth 4 -maxdepth 5 -name 'mod.info' 2>/dev/null | while read f; do
  wsid=$(echo "$f" | sed -nE 's|.*/Workshop/([0-9]+)/.*|\1|p')
  modid=$(grep -E '^id=' "$f" | head -1 | sed 's/^id=//; s/[\r ]//g')
  if [ -n "$wsid" ] && [ -n "$modid" ]; then
    printf '%s\t%s\n' "$wsid" "$modid"
  fi
done
'@

if ($useEphemeral) {
    $raw = docker run --rm -v pz-server-config:/project-zomboid-config alpine:3.20 sh -c $shellCmd
} else {
    $raw = docker exec $ContainerName sh -c $shellCmd
}

if (-not $raw) {
    Write-Host "ERROR: no se encontraron mod.info. Verifica que el primer arranque haya bajado los mods." -ForegroundColor Red
    exit 1
}

# Construir mapa workshopId -> @(modIds) (un workshop puede contener varios mods)
$map = @{}
foreach ($line in ($raw -split "`n")) {
    $parts = $line.Trim() -split "`t"
    if ($parts.Count -ne 2) { continue }
    $ws, $mid = $parts
    if (-not $map.ContainsKey($ws)) { $map[$ws] = @() }
    $map[$ws] += $mid
}

# Construir Mods= en el orden de tier
$ordered = @()
foreach ($ws in $tierOrder) {
    if ($map.ContainsKey($ws)) {
        $ordered += $map[$ws]
        $map.Remove($ws)
    } else {
        Write-Host "WARN: Workshop $ws no descargado todavia." -ForegroundColor Yellow
    }
}
# Cualquier mod extra que el contenedor haya bajado pero no esté en el tier
foreach ($ws in $map.Keys) {
    Write-Host "INFO: mod extra $ws no estaba en tier list, lo añado al final." -ForegroundColor DarkYellow
    $ordered += $map[$ws]
}

$plain     = "Mods=" + ($ordered -join ';')
$withSlash = "Mods=" + (($ordered | ForEach-Object { "\$_" }) -join ';')

$body = @"
# Generado por extract-mod-ids.ps1 el $(Get-Date -Format 'yyyy-MM-dd HH:mm')
# Total mods: $($ordered.Count)

# === Version SIN backslash (probar primero) ===
$plain

# === Version CON backslash (B42.13.1+ algunos hosts la requieren) ===
$withSlash
"@

$body | Out-File -FilePath $OutputFile -Encoding utf8 -Force
Write-Host ""
Write-Host "OK: $($ordered.Count) mods detectados. Resultado en $OutputFile" -ForegroundColor Green
Write-Host "Pega la linea 'Mods=' en config/servertest.ini y luego ejecuta apply-config.ps1." -ForegroundColor Cyan
