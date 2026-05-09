# run.md — Despliegue automatizado del servidor PZ B42

> Instrucciones para que un agente (Claude Code u otro) levante este servidor desde cero dentro de una VM Windows 11 con 40 GB de RAM.
>
> **Objetivo:** dejar el contenedor `pz-b42-server` corriendo, con los 75 mods cargados, escuchando en UDP 16261/16262 y TCP 27015, accesible con la contraseña del `.env`.
>
> **No interactivo:** todos los pasos son deterministas. Si un paso falla, ver la sección **Troubleshooting** al final.

---

## 0. Pre-condiciones

Antes de empezar, verificar:

```powershell
# Windows 11 actualizado
[System.Environment]::OSVersion.Version

# RAM disponible (debe ser ≥ 38 GB)
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB

# Virtualización habilitada en BIOS
(Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled

# WSL instalado (si devuelve nada, instalar: `wsl --install`)
wsl --status

# Docker Desktop instalado (si no, descargar https://www.docker.com/products/docker-desktop/)
docker --version
```

Si falta algo, instalarlo antes de continuar. Reiniciar tras instalar WSL/Docker Desktop.

---

## 1. Clonar el repo

Elegir rama:
- `prod` → producción real (lo normal)
- `dev` → iteración local con RAM reducida
- `test` → solo cuando se vaya a probar un cambio puntual de config

```powershell
$BRANCH = 'prod'              # cambiar si aplica
cd $env:USERPROFILE
git clone -b $BRANCH https://github.com/Maximiliano-zm/pz-server.git
cd pz-server
```

Verificación:
```powershell
git rev-parse --abbrev-ref HEAD     # debe imprimir el nombre de la rama
git log --oneline -1                # último commit existe
```

---

## 2. Configurar WSL2

```powershell
Copy-Item .wslconfig.example "$env:USERPROFILE\.wslconfig" -Force
wsl --shutdown
```

Reabrir Docker Desktop. Esperar 30 s a que el daemon arranque.

Verificación:
```powershell
docker info --format '{{.MemTotal}}' | ForEach-Object { [math]::Round($_/1GB,1) }
# Esperado: ~32-34 GB (memoria asignada al WSL2 según .wslconfig)
```

Si devuelve mucho menos: Docker Desktop no leyó el .wslconfig. Reiniciar Docker Desktop manualmente desde la bandeja de sistema.

---

## 3. Crear `.env` con contraseñas reales

`.env` está gitignoreado y NO viene en el clone. Crearlo:

```powershell
@"
ADMIN_PASSWORD=$([guid]::NewGuid().ToString('N').Substring(0,16))
SERVER_PASSWORD=$([guid]::NewGuid().ToString('N').Substring(0,12))
RCON_PASSWORD=$([guid]::NewGuid().ToString('N').Substring(0,16))

MEMORY_XMS_GB=15
MEMORY_XMX_GB=30
"@ | Out-File -FilePath .env -Encoding ascii -NoNewline
```

Mostrar al operador las contraseñas generadas (las necesitará para conectarse / administrar):
```powershell
Get-Content .env
```

> **Si la rama es `dev`:** las defaults del compose ya son menores; podés dejar `MEMORY_XMS_GB` y `MEMORY_XMX_GB` sin definir o ajustarlos a 4/8.

---

## 4. Validar el compose antes del primer arranque

```powershell
docker compose config | Select-String -Pattern 'image:|MEMORY_XMS_GB:|MEMORY_XMX_GB:|SERVER_BRANCH:|MAX_PLAYERS:'
```

Esperado: ver `image: indifferentbroccoli/...`, `SERVER_BRANCH: unstable`, `MEMORY_XMX_GB: "30"` (o el valor del .env), `MAX_PLAYERS: "20"`.

---

## 5. Primer arranque (descarga PZ + 75 mods)

```powershell
docker compose up -d
```

**Esperar 15-40 minutos.** El contenedor descarga PZ rama unstable + 75 mods de Workshop. NO matar.

Monitorear progreso y detectar fin del primer arranque automáticamente:

```powershell
# Espera hasta ver "Server initialized" en logs (timeout 60 min)
$deadline = (Get-Date).AddMinutes(60)
while ((Get-Date) -lt $deadline) {
    $logs = docker logs pz-b42-server 2>&1 | Out-String
    if ($logs -match 'Server initialized|server started|server is now ready') {
        Write-Host "Primer arranque OK." -ForegroundColor Green
        break
    }
    Start-Sleep 30
}
```

Verificación post-arranque:
```powershell
docker ps --filter 'name=pz-b42-server' --format 'table {{.Names}}\t{{.Status}}'
docker logs pz-b42-server --tail 50
```

---

## 6. Inyectar configs y `Mods=`

Parar el contenedor para que PZ no reescriba el ini al apagar:
```powershell
docker compose stop
```

Generar la línea `Mods=`:
```powershell
./scripts/extract-mod-ids.ps1
Get-Content ./mods-line.txt
```

Buscar en `mods-line.txt` la línea que empieza con `Mods=` (versión SIN backslash) y copiarla. Reemplazar la línea `Mods=` vacía en `config/servertest.ini`:

```powershell
$modsLine = (Get-Content ./mods-line.txt | Where-Object { $_ -match '^Mods=[^\\]' } | Select-Object -First 1)
(Get-Content ./config/servertest.ini) -replace '^Mods=.*$', $modsLine | Set-Content ./config/servertest.ini
```

Aplicar configs al volumen:
```powershell
./scripts/apply-config.ps1
```

Re-arrancar y monitorizar:
```powershell
docker compose up -d
docker logs -f pz-b42-server
```

---

## 7. Verificación end-to-end

```powershell
# Mods cargados (debe acercarse a 75)
docker logs pz-b42-server 2>&1 | Select-String -Pattern 'LOADED MOD|loaded mod' | Measure-Object | Select-Object -ExpandProperty Count

# JVM args efectivos
docker exec pz-b42-server cat /project-zomboid/ProjectZomboid64.json 2>$null | Select-String -Pattern 'Xmx|Xms|UseZGC'

# RAM en vivo
docker stats pz-b42-server --no-stream
```

Si `Mods=` con backslash es necesario (algunos mods no cargan):
```powershell
$modsLine = (Get-Content ./mods-line.txt | Where-Object { $_ -match '^Mods=\\' } | Select-Object -First 1)
(Get-Content ./config/servertest.ini) -replace '^Mods=.*$', $modsLine | Set-Content ./config/servertest.ini
./scripts/apply-config.ps1
```

---

## 8. Abrir puertos

Firewall Windows (requiere PowerShell elevado):
```powershell
Start-Process powershell -Verb RunAs -ArgumentList @"
New-NetFirewallRule -DisplayName 'PZ Game UDP' -Direction Inbound -Protocol UDP -LocalPort 16261,16262 -Action Allow
New-NetFirewallRule -DisplayName 'PZ RCON TCP' -Direction Inbound -Protocol TCP -LocalPort 27015 -Action Allow
"@
```

Router: NAT/PAT en UDP 16261, UDP 16262 y TCP 27015 hacia la IP local de la VM.

Detectar CGNAT (si la IP pública vista por la VM no coincide con la IP del router, hay CGNAT):
```powershell
$wanIp = (Invoke-RestMethod 'https://api.ipify.org')
Write-Host "IP publica: $wanIp"
if ($wanIp -match '^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.') {
    Write-Host 'CGNAT detectado. Necesitas Playit.gg / Tailscale Funnel / VPS relay.' -ForegroundColor Yellow
}
```

---

## 9. Operación diaria

```powershell
# Backup antes de cualquier update unstable
./scripts/backup.ps1

# Actualizar PZ + restart
docker compose pull
docker compose up -d

# Logs en vivo
docker logs -f pz-b42-server

# Apagado limpio (espera 60 s al stop_grace_period)
docker compose stop
```

---

## Troubleshooting

| Síntoma | Causa probable | Acción |
|---|---|---|
| `docker info` da menos de 30 GB | `.wslconfig` no aplicado | `wsl --shutdown` y reabrir Docker Desktop |
| Container reinicia en loop tras 5 min | OOM kill | Editar `.env` con `MEMORY_XMX_GB=24 MEMORY_XMS_GB=12` y `docker compose up -d` |
| Mods no cargan, errores de checksum | Falta backslash en `Mods=` | Aplicar versión con backslash (paso 7) |
| Cliente no conecta | Firewall o CGNAT | Verificar reglas; si CGNAT usar relay |
| `extract-mod-ids.ps1` dice "no se encontraron mod.info" | Primer arranque incompleto | Esperar más tiempo, revisar logs por errores de Steam |
| GC pauses largas en logs | Heap demasiado grande para el host | Plan B: bajar a 24/12 |
| Saves corruptos tras update | Update unstable rompió save | Restaurar desde `backups/` (último tar.gz) |

---

## Resumen de comandos para un agente

Si todo va bien, el flujo completo es:

```powershell
$BRANCH = 'prod'
cd $env:USERPROFILE
git clone -b $BRANCH https://github.com/Maximiliano-zm/pz-server.git
cd pz-server
Copy-Item .wslconfig.example "$env:USERPROFILE\.wslconfig" -Force
wsl --shutdown
Start-Sleep 30
@"
ADMIN_PASSWORD=$([guid]::NewGuid().ToString('N').Substring(0,16))
SERVER_PASSWORD=$([guid]::NewGuid().ToString('N').Substring(0,12))
RCON_PASSWORD=$([guid]::NewGuid().ToString('N').Substring(0,16))
MEMORY_XMS_GB=15
MEMORY_XMX_GB=30
"@ | Out-File .env -Encoding ascii -NoNewline
docker compose up -d
# esperar 30-40 min al primer arranque, luego:
docker compose stop
./scripts/extract-mod-ids.ps1
$modsLine = (Get-Content ./mods-line.txt | Where-Object { $_ -match '^Mods=[^\\]' } | Select-Object -First 1)
(Get-Content ./config/servertest.ini) -replace '^Mods=.*$', $modsLine | Set-Content ./config/servertest.ini
./scripts/apply-config.ps1
docker compose up -d
```
