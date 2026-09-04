@echo off
REM Launch Eve V Fix-It from the script (self-elevating). Use this if you don't
REM want to run the .exe, or Defender / SmartScreen flags it.
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0EveVFixIt.ps1"
