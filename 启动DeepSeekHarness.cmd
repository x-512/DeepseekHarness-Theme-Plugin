@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher\start.ps1"
if errorlevel 1 (
  echo.
  echo DeepSeek Harness 启动失败，请确认已安装 Google Chrome。
  pause
)
