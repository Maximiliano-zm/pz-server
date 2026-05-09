@echo off
echo ============================================
echo  Servidor Project Zomboid B42 + playit.gg tunnel
echo ============================================
echo.

set PZ_DIR=%USERPROFILE%\pz-server
set PLAYIT=%PZ_DIR%\playit\playit.exe
set TOML=%LOCALAPPDATA%\playit_gg\playit.toml

if not exist "%PLAYIT%" (
    echo ERROR: playit.exe no encontrado en %PLAYIT%
    echo Descarga el agente desde: https://playit.gg/download
    pause
    exit /b 1
)

if not exist "%TOML%" (
    echo ERROR: playit.toml no encontrado en %TOML%
    echo Vincula el agente primero ejecutando setup_playit.bat
    pause
    exit /b 1
)

echo [1/4] Cerrando instancias previas de playit (si las hay)...
taskkill /IM playit.exe /F >NUL 2>&1

echo [2/4] Iniciando playit.gg tunnel (TUI) en ventana aparte...
start "playit tunnel" "%PLAYIT%"

echo [3/4] Esperando 5 segundos a que el tunnel se establezca...
timeout /t 5 /nobreak >NUL

echo [4/4] Levantando contenedor Project Zomboid...
cd /d "%PZ_DIR%"
docker compose up -d
if errorlevel 1 (
    echo.
    echo ERROR: docker compose up fallo. Verifica que Docker Desktop este corriendo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Servidor PZ + playit listos
echo ============================================
echo  Direccion publica:  businesses-cope.gl.at.ply.gg:42274
echo  Direccion LAN:      127.0.0.1:16261
echo  Container:          pz-b42-server (docker)
echo.
echo  Logs en vivo:       docker logs -f pz-b42-server
echo  Parar todo:         stop_with_playit.bat
echo ============================================
echo.
pause
