@echo off
setlocal
title Survival Log - ติดตั้งมอดภาษาไทย
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ThaiPrototype.ps1"
if errorlevel 1 (
  echo.
  echo ติดตั้งไม่สำเร็จ กรุณาตรวจสอบข้อความด้านบน
) else (
  echo.
  echo ติดตั้งมอดภาษาไทยสำเร็จแล้ว กรุณาเปิดเกมใหม่
)
echo.
pause
