@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "BACKEND_DIR=%PROJECT_DIR%backend"
set "API_URL=http://127.0.0.1:4000"
set "WEB_PORT=5173"
set "WEB_URL=http://127.0.0.1:%WEB_PORT%"

echo Starting Talk with Hands backend...
start "Talk with Hands Backend" /min cmd /k "cd /d "%BACKEND_DIR%" && node server.js"

echo Starting Flutter admin app in web-desktop mode...
start "Talk with Hands Admin Web" /min cmd /k "cd /d "%PROJECT_DIR%" && flutter run -d web-server --web-port=%WEB_PORT% --dart-define=API_BASE_URL=%API_URL%"

echo Waiting for the app to warm up...
timeout /t 12 /nobreak >nul

set "CHROME_EXE=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME_EXE%" set "CHROME_EXE=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"

if exist "%CHROME_EXE%" (
  start "Talk with Hands Admin Panel" "%CHROME_EXE%" --app=%WEB_URL%
) else (
  start "" "%WEB_URL%"
)

echo.
echo Login, open the menu, then click Admin Panel.
echo Backend: %API_URL%
echo App: %WEB_URL%
pause
