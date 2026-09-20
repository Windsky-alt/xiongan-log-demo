@echo off
rem ASCII-only on purpose: cmd.exe parses .bat with the OEM codepage (936 on
rem Chinese Windows), so UTF-8 Chinese here would become garbage paths.
rem All Chinese prompts live in the .ps1 (UTF-8).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
