@echo off
echo ============================================
echo  Servidor Project Zomboid B42 + playit.gg + ngrok
echo ============================================
echo.

set PZ_DIR=%USERPROFILE%\pz-server
set PLAYIT=%PZ_DIR%\playit\playit.exe
set TOML=%LOCALAPPDATA%\playit_gg\playit.toml
set NGROK=C:\ngrok\ngrok.exe

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

if not exist "%NGROK%" (
    echo ERROR: ngrok.exe no encontrado en %NGROK%
    pause
    exit /b 1
)

echo [1/5] Cerrando instancias previas de playit y ngrok (si las hay)...
taskkill /IM playit.exe /F >NUL 2>&1
taskkill /IM ngrok.exe /F >NUL 2>&1

echo [2/5] Iniciando playit.gg tunnel (TUI) en ventana aparte...
start "playit tunnel" "%PLAYIT%"

echo [3/5] Iniciando ngrok tcp 27015 en ventana aparte...
start "ngrok tunnel" "%NGROK%" tcp 27015

echo [4/5] Esperando 8 segundos a que los tunnels se establezcan...
timeout /t 8 /nobreak >NUL

echo [5/5] Levantando contenedor Project Zomboid...
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
echo  Servidor PZ + playit + ngrok listos
echo ============================================
echo  Direccion playit:   businesses-cope.gl.at.ply.gg:42274
echo  Direccion LAN:      127.0.0.1:16261
echo  Container:          pz-b42-server (docker)
echo.
echo  URL ngrok (cambia cada reinicio):
echo    http://127.0.0.1:4040  ^<-- abre esto en el navegador para ver la URL actual
echo.
echo  Logs en vivo:       docker logs -f pz-b42-server
echo  Parar todo:         stop_with_playit.bat
echo ============================================
echo.
pause
