@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title ReClip Portable - Build Installer Package

REM ============================================================
REM  Builds a lightweight installer ZIP from the full build.
REM  Output: dist\ReClip-Portable-Installer.zip (~100 KB)
REM ============================================================

set "BASE=%~dp0"
set "DIST=%BASE%dist"
set "STAGE=%DIST%\ReClip-Portable"
set "ZIP=%DIST%\ReClip-Portable-Installer.zip"

echo.
echo  Building ReClip Portable Installer Package...
echo.

REM Clean
if exist "%DIST%" rmdir /s /q "%DIST%" >nul 2>nul
mkdir "%STAGE%"
mkdir "%STAGE%\app"
mkdir "%STAGE%\app\templates"
mkdir "%STAGE%\app\static"

REM Copy app source (no downloads, no __pycache__)
echo  Copying app source...
copy /y "%BASE%app\app.py" "%STAGE%\app\" >nul
copy /y "%BASE%app\requirements.txt" "%STAGE%\app\" >nul
copy /y "%BASE%app\templates\index.html" "%STAGE%\app\templates\" >nul
copy /y "%BASE%app\static\favicon.svg" "%STAGE%\app\static\" >nul

REM Copy scripts
echo  Copying scripts...
copy /y "%BASE%install-reclip.bat" "%STAGE%\" >nul
copy /y "%BASE%start-reclip-autobrowser.bat" "%STAGE%\start-reclip.bat" >nul
copy /y "%BASE%update-ytdlp.bat" "%STAGE%\" >nul

REM Create README
> "%STAGE%\README.txt" echo ReClip Portable Installer
>>"%STAGE%\README.txt" echo ========================
>>"%STAGE%\README.txt" echo.
>>"%STAGE%\README.txt" echo Quick Start:
>>"%STAGE%\README.txt" echo   1. Run install-reclip.bat (downloads ~350 MB: Python + FFmpeg + deps)
>>"%STAGE%\README.txt" echo   2. After install, run start-reclip.bat
>>"%STAGE%\README.txt" echo   3. Open http://127.0.0.1:8899
>>"%STAGE%\README.txt" echo.
>>"%STAGE%\README.txt" echo Requirements:
>>"%STAGE%\README.txt" echo   - Windows 10/11
>>"%STAGE%\README.txt" echo   - Internet connection (for first install only)
>>"%STAGE%\README.txt" echo   - ~500 MB disk space after install
>>"%STAGE%\README.txt" echo.
>>"%STAGE%\README.txt" echo Update yt-dlp (if YouTube stops working):
>>"%STAGE%\README.txt" echo   Run update-ytdlp.bat
>>"%STAGE%\README.txt" echo.
>>"%STAGE%\README.txt" echo Source: https://github.com/perejaslav/ReClip-Portable
>>"%STAGE%\README.txt" echo Upstream: https://github.com/averygan/reclip

REM Zip it
echo.
echo  Creating ZIP...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Compress-Archive -Path '%STAGE%\*' -DestinationPath '%ZIP%' -Force"

if exist "%ZIP%" (
    for %%F in ("%ZIP%") do (
        echo.
        echo  ============================================
        echo   Done! Installer package created:
        echo   %ZIP%
        echo   Size: %%~zF bytes
        echo  ============================================
    )
) else (
    echo  [ERROR] ZIP was not created.
)

REM Cleanup staging
rmdir /s /q "%STAGE%" >nul 2>nul

echo.
pause
