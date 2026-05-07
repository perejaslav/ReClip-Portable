@echo off
setlocal
cd /d "%~dp0"

echo Starting ReClip Portable...
echo Open in browser: http://127.0.0.1:8899
echo.

if not exist "python\python.exe" (
  echo ERROR: python\python.exe not found.
  echo This file must be placed inside the ReClip-Portable folder.
  pause
  exit /b 1
)

if not exist "app\app.py" (
  echo ERROR: app\app.py not found.
  echo This file must be placed inside the ReClip-Portable folder.
  pause
  exit /b 1
)

set "PATH=%CD%\python;%CD%\python\Scripts;%CD%\ffmpeg\bin;%PATH%"
set "PYTHON=%CD%\python\python.exe"
set "FFMPEG_LOCATION=%CD%\ffmpeg\bin"
set "URL=http://127.0.0.1:8899"

rem Open browser in a separate background process after a short delay.
start "" cmd /c "timeout /t 2 /nobreak >nul & start "" "%URL%""

cd /d "%CD%\app"
"%PYTHON%" app.py

echo.
echo ReClip stopped.
pause
