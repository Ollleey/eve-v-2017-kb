@echo off
REM Launch PogoWatch GUI (normal rights - enough for logging/monitoring)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0PogoWatch.ps1"
