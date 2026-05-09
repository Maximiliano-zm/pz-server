@echo off
echo ============================================
echo  Parando Project Zomboid + playit.gg tunnel
echo ============================================
echo.

set PZ_DIR=%USERPROFILE%\pz-server

echo [1/2] Parando contenedor PZ (espera stop_grace_period 60s)...
cd /d "%PZ_DIR%"
docker compose stop

echo [2/2] Cerrando playit.gg tunnel...
taskkill /IM playit.exe /F >NUL 2>&1

echo.
echo Listo. PZ y playit detenidos.
pause
