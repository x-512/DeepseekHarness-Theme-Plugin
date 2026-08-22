@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-to-harness.ps1"
if errorlevel 1 (
  echo.
  echo 安装失败，请确认已安装 DeepSeek Harness，或选择正确的安装目录。
  pause
)
