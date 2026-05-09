@echo off
echo ============================================
echo  Servidor Project Zomboid B42 (solo LAN)
echo ============================================
echo.

set PZ_DIR=%USERPROFILE%\pz-server

cd /d "%PZ_DIR%"
docker compose up -d
if errorlevel 1 (
    echo.
    echo ERROR: docker compose up fallo. Verifica que Docker Desktop este corriendo.
    pause
    exit /b 1
)

echo.
echo Servidor PZ levantado en LAN: 127.0.0.1:16261
echo Logs en vivo: docker logs -f pz-b42-server
echo.
pause
