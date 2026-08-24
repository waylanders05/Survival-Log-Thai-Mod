@echo off
setlocal
title Survival Log Thai Mod Uninstaller
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-ThaiPrototype.ps1"
if errorlevel 1 goto uninstall_failed
echo.
echo Uninstallation complete.
goto finish
:uninstall_failed
echo.
echo Uninstallation failed. See the message above.
:finish
pause
