@echo off
setlocal
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test_pr8.ps1" %*
set "rc=%errorlevel%"
if "%~1"=="" pause
endlocal & exit /b %rc%
