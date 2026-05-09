@echo off
echo ============================================
echo  Configuracion inicial de playit.gg
echo ============================================
echo.
echo Solo necesario la primera vez (o si borraste el secret).
echo.
echo Se abrira playit.exe. Aparecera una URL del tipo:
echo    https://playit.gg/claim/XXXXXXXXXX
echo.
echo Copia esa URL y abrela en tu navegador.
echo Inicia sesion en playit.gg y dale "Claim Agent".
echo.
echo Una vez vinculado, cierra esta ventana y usa
echo start_with_playit.bat para iniciar todo junto.
echo.
pause

set PZ_DIR=%USERPROFILE%\pz-server
"%PZ_DIR%\playit\playit.exe"
