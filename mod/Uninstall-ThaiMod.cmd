@echo off
setlocal
title Survival Log - ถอนมอดภาษาไทย
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-ThaiPrototype.ps1"
if errorlevel 1 (
  echo.
  echo ถอนการติดตั้งไม่สำเร็จ กรุณาตรวจสอบข้อความด้านบน
) else (
  echo.
  echo ถอนมอดภาษาไทยสำเร็จแล้ว
)
echo.
pause
