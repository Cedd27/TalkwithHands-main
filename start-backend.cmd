@echo off
cd /d "%~dp0"
echo Starting TalkWithHands auth backend...
echo.
npm.cmd start
echo.
echo Backend stopped. Press any key to close this window.
pause >nul
