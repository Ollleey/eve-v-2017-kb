@echo off
REM Launch PogoWatch elevated (only needed if you want the "Rescan HW" button
REM to run without a separate UAC prompt each time)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0PogoWatch.ps1"
