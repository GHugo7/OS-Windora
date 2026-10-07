@echo off
rem Windora : fabrique un ISO (ou prepare une cle USB) qui installe Windows ET Windora.
rem   creer-iso.cmd             demande l'ISO officiel de Windows 11, cree Windora-....iso
rem   creer-iso.cmd -Cle E:     prepare une cle USB d'installation de Windows (lecteur E:)
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0iso\creer-iso.ps1" %*
echo.
pause
