@echo off
setlocal
title Survival Log Thai Mod Installer
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ThaiPrototype.ps1"
if errorlevel 1 goto install_failed
echo.
echo Installation complete. Please restart the game.
goto finish
:install_failed
echo.
echo Installation failed. See the message above.
:finish
pause
