@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher\install-shortcuts.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. Keep this folder extracted and make sure Google Chrome is installed.
  pause
)
