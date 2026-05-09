# Servidor Project Zomboid Build 42 Unstable (Docker)

Servidor PZ B42 unstable para 20 jugadores con 75 mods (colección Workshop `3719673645`), PvP libre, privado con contraseña, optimizado para correr en una VM Windows 11 con 40 GB de RAM via Docker Desktop + WSL2.

## Ramas del repo

- **`prod`** — config que corre en la VM en producción.
- **`dev`** — iteración local con defaults reducidos (Xmx=8G, MaxPlayers=10) para validar mods y configs sin necesitar 40 GB.
- **`test`** — solo para probar puntualmente un cambio de configuración antes de mergear a `prod`.

## Estructura

```
pz-server/
├── docker-compose.yml          # servicio único, image indifferentbroccoli/projectzomboid-server-docker
├── .env                        # contraseñas + RAM (NO commitear)
├── .wslconfig.example          # copiar a %UserProfile%\.wslconfig
├── start.bat                   # arranque rápido solo LAN (docker compose up -d)
├── start_with_playit.bat       # arranque público vía túnel playit.gg + Docker
├── stop_with_playit.bat        # apaga PZ y cierra el túnel playit
├── setup_playit.bat            # vinculación inicial del agente playit.gg
├── mods-line.txt               # output de extract-mod-ids (línea Mods= lista para pegar)
├── config/
│   ├── servertest.ini          # config principal (PvP, anti-cheat, mods, RCON)
│   └── servertest_SandboxVars.lua  # zombies, animales, B42 nuevo
├── playit/
│   └── playit.exe              # agente playit.gg (túnel para sortear CGNAT)
├── scripts/
│   ├── extract-mod-ids.ps1     # genera Mods= leyendo cada mod.info
│   ├── extract.sh              # variante shell (WSL) para extraer mod IDs
│   ├── apply-config.ps1        # vuelca config/ al volumen Docker
│   └── backup.ps1              # tar.gz del volumen Saves
└── README.md
```

## RAM

Política agresiva sobre VM de 40 GB:

| Componente | RAM |
|---|---|
| JVM PZ (`-Xms15G -Xmx30G`) | 30 GB |
| `mem_limit` del contenedor (heap + native + JIT) | 32 GB |
| WSL2 kernel + Docker engine | ~2 GB |
| Windows 11 (sin cliente Steam corriendo) | ~4 GB |
| Buffer | 2 GB |
| **Total** | **40 GB** |

Si aparecen GC pauses largas u OOM kills, edita `.env`:
```env
MEMORY_XMS_GB=12
MEMORY_XMX_GB=24
```
y `docker compose up -d`.

## Despliegue paso a paso (PC Windows 11 de 30 GB)

### 1. Pre-requisitos
- Docker Desktop con backend WSL2.
- WSL2 instalado (`wsl --install` si no).

### 2. Configurar WSL2
Copia `.wslconfig.example` a `%UserProfile%\.wslconfig` y reinicia WSL:
```powershell
Copy-Item .wslconfig.example $env:UserProfile\.wslconfig
wsl --shutdown
```
Re-abre Docker Desktop.

### 3. Configurar contraseñas
Edita `.env` y pon contraseñas reales para `ADMIN_PASSWORD`, `SERVER_PASSWORD`, `RCON_PASSWORD`.

### 4. Primer arranque (descarga PZ + mods)
```powershell
docker compose up -d
docker compose logs -f
```
**Esperar 15-40 minutos.** El contenedor descarga PZ (rama unstable) y los 75 mods desde Workshop. Cuando veas algo como `Server initialized`, parar para inyectar configs:
```powershell
docker compose stop
```

### 5. Generar línea Mods=
```powershell
./scripts/extract-mod-ids.ps1
```
Genera `mods-line.txt` con dos versiones (con y sin backslash). Copia la línea **sin backslash** y pégala en `config/servertest.ini` reemplazando la línea `Mods=`.

### 6. Aplicar configs y arrancar
```powershell
./scripts/apply-config.ps1
docker compose up -d
docker compose logs -f
```

### 7. Abrir puertos
- **Firewall Windows**: permitir entrante UDP 16261, 16262 y TCP 27015 (RCON).
- **Router**: NAT a la IP local del PC en los mismos puertos.
- Si tu ISP usa CGNAT, usa el flujo playit.gg integrado (ver siguiente sección), Tailscale Funnel o un VPS con WireGuard de relay.

## Arranque rápido con scripts `.bat`

Para evitar acordarse de los comandos de Docker existen tres scripts en la raíz:

| Script | Cuándo usarlo |
|---|---|
| `start.bat` | Arranque solo LAN — equivalente a `docker compose up -d` y mostrar logs. |
| `start_with_playit.bat` | Arranque público: levanta el túnel playit.gg en una ventana TUI aparte y luego el contenedor. |
| `stop_with_playit.bat` | Apaga el contenedor PZ (con `stop_grace_period` 60s) y cierra el agente playit.gg. |
| `setup_playit.bat` | Solo la primera vez: abre `playit.exe` para reclamar el agente vía URL `https://playit.gg/claim/...`. |

Los scripts asumen que el repo está en `%USERPROFILE%\pz-server`.

## playit.gg (túnel para CGNAT)

Para servidores detrás de CGNAT (IP pública 100.x.x.x) o sin acceso al router, el repo incluye el agente `playit/playit.exe`.

### Setup inicial
1. Ejecuta `setup_playit.bat`.
2. Copia la URL `https://playit.gg/claim/XXXXXXXXXX` que imprime el agente.
3. Inicia sesión en playit.gg en el navegador y dale **Claim Agent**.
4. Configura un **Tunnel** UDP→16261 (Project Zomboid) en el dashboard de playit.gg.
5. Cierra la TUI. El secret queda guardado en `%LOCALAPPDATA%\playit_gg\playit.toml`.

### Uso diario
- **Arrancar**: `start_with_playit.bat` — levanta túnel + Docker.
- **Parar**: `stop_with_playit.bat`.

La dirección pública (formato `xxx-xxx.gl.at.ply.gg:PORT`) la asigna playit.gg en el dashboard y se imprime al final de `start_with_playit.bat`.

## Verificación

```powershell
# Estado
docker ps

# Logs
docker logs -f pz-b42-server

# Mods cargados (debería listar 75)
docker logs pz-b42-server 2>&1 | Select-String -Pattern 'loaded mod' | Measure-Object

# Memoria en vivo
docker stats pz-b42-server

# JVM args efectivos
docker exec pz-b42-server cat /project-zomboid/ProjectZomboid64.json
```

Conexión cliente:
1. Project Zomboid → Join Server
2. IP: `IP_PUBLICA` (o `127.0.0.1` para test local)
3. Puerto: `16261`
4. Account password: el `SERVER_PASSWORD` del `.env`

## Operación

### Backup antes de cada update unstable
```powershell
./scripts/backup.ps1
docker compose pull
docker compose up -d
```

### Cambiar mods sin perder save
```powershell
docker compose stop
# Edita config/servertest.ini (WorkshopItems= y Mods=)
./scripts/apply-config.ps1
```

### Comandos admin in-game (consola PZ)
- `/setaccesslevel "USER" admin` — promover a admin
- `/grantadmin "USER"` — alias
- `/save` — fuerza guardado
- `/quit` — apaga el server limpio
- `/teleportto X,Y,Z` — TP
- `/kick "USER"` / `/banuser "USER"` — moderación

## Balance de zombies

El servidor venía configurado con zombies muy duros y los jugadores reportaron que los oían demasiado lejos. Tuneo actual en `config/servertest_SandboxVars.lua`:

| Variable | Valor | Nota |
|---|---|---|
| `Hearing` | `3` (Poor) | Antes `2` (Normal). Bajado por feedback de los jugadores. |
| `Memory` | `3` (Short) | Antes `2`. Olvidan al jugador antes — se desenganchan más rápido. |
| `Sight` | `2` (Normal) | Sin cambios. |
| `Cognition` | `3` (Basic) | Sin cambios — ya estaba en el escalón más estúpido. |
| `FollowSoundDistance` | `50` | Antes `100`. Distancia (tiles) a la que un sonido los atrae. |

Si los jugadores piden subir o bajar la dificultad, esos cuatro valores son los primeros a tocar. Tras editar el `.lua`, aplicar con `./scripts/apply-config.ps1` y reiniciar el contenedor.

## Caveats

- **B42 unstable**: saves pueden romperse entre updates. Backup antes de pull.
- **Modlist**: 75 mods cargan en ~15-40 min en primer arranque (WSL2). No matar.
- **20 jugadores**: cap soft impuesto por TIS en B42 unstable, no subir.
- **Inventory Tetris FIX (3713662067)** y **CommonSense FIX (3714335263)** deben ir DESPUÉS de los mods originales — el orden de tier ya lo cumple.
- **Lockstep**: todos los clientes en la misma B42.x que el server.
- **CGNAT**: si tu IP pública es 100.x.x.x es CGNAT — necesitas relay externo.

## Modlist (75 mods, colección 3719673645)

Frameworks/Libs (Tier 1): errorMagnifier, Mod Update and Alert System, that DAMN Library, TchernoLib, Starlit Library, NeatUI Framework

UI (Tier 2): Equipment UI, Inventory Tetris + 3 add-ons + FIX, Modern Status, Wear Anything, Clean HotBar, Minimal Sidebar

QoL/Crafting (Tier 3): Intuitive Crafting, Neat Crafting, Common Sense + FIX, Swap It, Repair Any Clothes, Calorie Fix, Propane Torch Fix, Replace Bandage, Rain Cleans Blood, Faster Cloth Ripping, Map Legend UI, Hide Menu Debug, Skill Recovery Journal, Has Been Read

Gameplay (Tier 4): More Traits, More Item Information, Become Desensitized, Immersive Suicide, Exercise With Corpses, RPGSkillTree, Alcohol Fluid Fix

Combat (Tier 5): Simple Silencers, Universal Simple Silencers, Auto Reload, Better Flashlights, Simple Flashlight on Belt, GaelGunStore

NPCs (Tier 6): Bandits NPC, Bandits Creator, Dynamic Trading

Vehículos (Tier 7-8): Vanilla animated, '88 Hilux, '93 F-Series, '89 Bronco, Defender 90/110, Road Runner, Step-Van, Project RV Interior, Trailers!, Realistic Dashboard, Effortless Towing, Auto Refueling, Better Auto Mechanics, Dismantle Any Car, Faster Hood

Misc (Tier 9): More Damaged Objects, Here Goes the Sun, TwisTonFire minimap, Proximity Inventory, Mini Health Panel, Item Condition Overlay, Karas Auto Fishing, Bolt Cutters, Pry Open, Ladders?!
