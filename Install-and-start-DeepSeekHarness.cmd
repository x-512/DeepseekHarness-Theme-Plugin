@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-to-harness.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. Confirm DeepSeek Harness is installed, then select its folder.
  pause
)
