@echo off
rem Windora : double-cliquez sur ce fichier pour installer.
rem Options possibles, par exemple :  installer.cmd -NoLook -NoSlim
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
echo.
pause
