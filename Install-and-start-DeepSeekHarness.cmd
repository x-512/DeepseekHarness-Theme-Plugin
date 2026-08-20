@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-to-harness.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. Check the internet connection and available disk space, then run this file again.
  pause
)
