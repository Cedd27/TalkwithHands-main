@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "BACKEND_DIR=%PROJECT_DIR%backend"
set "API_URL=http://127.0.0.1:4000"

echo Starting Talk with Hands backend...
start "Talk with Hands Backend" /min cmd /k "cd /d "%BACKEND_DIR%" && node server.js"

echo.
echo Opening Talk with Hands in Chrome.
echo Please wait. The first run can take 1-3 minutes.
echo.

cd /d "%PROJECT_DIR%"
flutter run -d chrome --dart-define=API_BASE_URL=%API_URL%

pause
