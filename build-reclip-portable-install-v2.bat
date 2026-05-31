@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM ReClip Portable Builder for Windows 11 - v2
REM Creates a self-contained folder: ReClip-Portable
REM Includes: ReClip app, embeddable Python, FFmpeg, Flask, yt-dlp
REM Fixes: robust FFmpeg extraction/copy, better diagnostics, no fragile PATH assumptions
REM ============================================================

set "ROOT=%~dp0ReClip-Portable"
set "BUILD_TMP=%~dp0_reclip_build_tmp"
set "PY_URL=https://www.python.org/ftp/python/3.12.10/python-3.12.10-embeddable-amd64.zip"
set "GETPIP_URL=https://bootstrap.pypa.io/get-pip.py"
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "RECLIP_URL=https://github.com/averygan/reclip/archive/refs/heads/main.zip"

set "PYZIP=%BUILD_TMP%\python-embed.zip"
set "GETPIP=%BUILD_TMP%\get-pip.py"
set "FFZIP=%BUILD_TMP%\ffmpeg.zip"
set "RECLIPZIP=%BUILD_TMP%\reclip.zip"
set "LOG=%~dp0reclip-portable-build.log"

cd /d "%~dp0"

echo === ReClip Portable Builder for Windows 11 v2 ===
echo.
echo This script will create:
echo   %ROOT%
echo.
echo Log file:
echo   %LOG%
echo.

> "%LOG%" echo ReClip Portable Builder v2 log
>> "%LOG%" echo Started: %DATE% %TIME%
>> "%LOG%" echo Root: %ROOT%

if exist "%ROOT%" (
    echo [ERROR] Folder already exists:
    echo   %ROOT%
    echo.
    echo To avoid deleting your files, this builder will not overwrite it.
    echo Rename/delete ReClip-Portable, then run this BAT again.
    goto :fail
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] PowerShell was not found. This script requires Windows PowerShell.
    goto :fail
)

where tar.exe >nul 2>nul
if errorlevel 1 (
    echo [INFO] tar.exe was not found. PowerShell Expand-Archive will be used.
) else (
    echo [INFO] tar.exe found. It will be used for zip extraction where possible.
)

echo [1/10] Preparing folders...
if exist "%BUILD_TMP%" rmdir /s /q "%BUILD_TMP%" >nul 2>nul
mkdir "%BUILD_TMP%" || goto :fail
mkdir "%ROOT%" || goto :fail
mkdir "%ROOT%\python" || goto :fail
mkdir "%ROOT%\ffmpeg\bin" || goto :fail
mkdir "%ROOT%\app" || goto :fail
mkdir "%ROOT%\data\downloads" || goto :fail
mkdir "%ROOT%\logs" || goto :fail

echo.
echo [2/10] Downloading portable Python...
call :download "%PY_URL%" "%PYZIP%" || goto :fail

echo.
echo [3/10] Extracting portable Python...
call :extract_zip "%PYZIP%" "%ROOT%\python" || goto :fail

if not exist "%ROOT%\python\python.exe" (
    echo [ERROR] python.exe was not extracted correctly.
    goto :fail
)

echo.
echo [4/10] Enabling site-packages in embedded Python...
set "PTH_FILE="
for %%F in ("%ROOT%\python\python*._pth") do set "PTH_FILE=%%~fF"
if not defined PTH_FILE (
    echo [ERROR] Could not find python ._pth file.
    goto :fail
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p='%PTH_FILE%'; $c=Get-Content -LiteralPath $p; $c=$c -replace '^#import site$','import site'; if(-not ($c -contains 'Lib\site-packages')) { $c += 'Lib\site-packages' }; Set-Content -LiteralPath $p -Value $c -Encoding ASCII" 1>>"%LOG%" 2>>&1 || goto :fail

echo.
echo [5/10] Installing pip into portable Python...
call :download "%GETPIP_URL%" "%GETPIP%" || goto :fail
"%ROOT%\python\python.exe" "%GETPIP%" --no-warn-script-location 1>>"%LOG%" 2>>&1 || goto :fail

echo.
echo [6/10] Installing Python dependencies: Flask and yt-dlp...
"%ROOT%\python\python.exe" -m pip install --upgrade pip setuptools wheel --no-warn-script-location || goto :fail
"%ROOT%\python\python.exe" -m pip install --upgrade flask "yt-dlp[default]" --no-warn-script-location || goto :fail

echo.
echo [7/10] Downloading FFmpeg portable build...
call :download "%FFMPEG_URL%" "%FFZIP%" || goto :fail

echo.
echo [8/10] Extracting FFmpeg and copying binaries...
mkdir "%BUILD_TMP%\ffmpeg_extract" || goto :fail
call :extract_zip "%FFZIP%" "%BUILD_TMP%\ffmpeg_extract" || goto :fail

REM Use PowerShell for reliable recursive search/copy on Windows paths.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src='%BUILD_TMP%\ffmpeg_extract'; $dst='%ROOT%\ffmpeg\bin'; $ffmpeg=Get-ChildItem -LiteralPath $src -Recurse -Filter ffmpeg.exe -File | Select-Object -First 1; $ffprobe=Get-ChildItem -LiteralPath $src -Recurse -Filter ffprobe.exe -File | Select-Object -First 1; if(-not $ffmpeg){ throw 'ffmpeg.exe not found in archive' }; if(-not $ffprobe){ throw 'ffprobe.exe not found in archive' }; Copy-Item -LiteralPath $ffmpeg.FullName -Destination (Join-Path $dst 'ffmpeg.exe') -Force; Copy-Item -LiteralPath $ffprobe.FullName -Destination (Join-Path $dst 'ffprobe.exe') -Force; Write-Host ('Copied: ' + $ffmpeg.FullName); Write-Host ('Copied: ' + $ffprobe.FullName)" 1>>"%LOG%" 2>>&1 || goto :fail

if not exist "%ROOT%\ffmpeg\bin\ffmpeg.exe" (
    echo [ERROR] ffmpeg.exe was not copied.
    goto :fail
)
if not exist "%ROOT%\ffmpeg\bin\ffprobe.exe" (
    echo [ERROR] ffprobe.exe was not copied.
    goto :fail
)

echo.
echo [9/10] Downloading ReClip source code...
call :download "%RECLIP_URL%" "%RECLIPZIP%" || goto :fail
mkdir "%BUILD_TMP%\reclip_extract" || goto :fail
call :extract_zip "%RECLIPZIP%" "%BUILD_TMP%\reclip_extract" || goto :fail

set "RECLIP_SRC="
for /d %%D in ("%BUILD_TMP%\reclip_extract\reclip-*") do set "RECLIP_SRC=%%~fD"
if not defined RECLIP_SRC (
    echo [ERROR] ReClip source folder was not found after extraction.
    goto :fail
)

xcopy "!RECLIP_SRC!\*" "%ROOT%\app\" /E /I /Y >nul || goto :fail

if not exist "%ROOT%\app\app.py" (
    echo [ERROR] app.py was not found in ReClip source.
    goto :fail
)

echo.
echo [10/10] Patching ReClip for portable Windows launch...
call :write_patch_script || goto :fail
"%ROOT%\python\python.exe" "%BUILD_TMP%\patch_reclip.py" "%ROOT%\app\app.py" || goto :fail

call :write_start_script || goto :fail
call :write_update_script || goto :fail
call :write_readme || goto :fail

echo.
echo [CHECK] Testing portable yt-dlp...
"%ROOT%\python\python.exe" -m yt_dlp --version || goto :fail

echo.
echo [CHECK] Testing portable FFmpeg...
"%ROOT%\ffmpeg\bin\ffmpeg.exe" -version >nul 2>nul || goto :fail
"%ROOT%\ffmpeg\bin\ffprobe.exe" -version >nul 2>nul || goto :fail
echo FFmpeg OK.

echo.
echo Cleaning temporary files...
rmdir /s /q "%BUILD_TMP%" >nul 2>nul

echo.
echo === DONE ===
echo Portable build was created here:
echo   %ROOT%
echo.
echo To run ReClip, open:
echo   %ROOT%\start-reclip.bat
echo.
echo You can copy the whole ReClip-Portable folder to another Windows 11 PC.
echo.
pause
exit /b 0

:download
set "URL=%~1"
set "OUT=%~2"
echo Downloading:
echo   %URL%
>> "%LOG%" echo Downloading: %URL%
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%URL%' -OutFile '%OUT%'" 1>>"%LOG%" 2>>&1
if errorlevel 1 (
    echo [ERROR] Download failed:
    echo   %URL%
    echo See log:
    echo   %LOG%
    exit /b 1
)
if not exist "%OUT%" (
    echo [ERROR] Downloaded file not found:
    echo   %OUT%
    exit /b 1
)
exit /b 0

:extract_zip
set "ZIPFILE=%~1"
set "DESTDIR=%~2"
>> "%LOG%" echo Extracting: %ZIPFILE% to %DESTDIR%
where tar.exe >nul 2>nul
if not errorlevel 1 (
    tar -xf "%ZIPFILE%" -C "%DESTDIR%" 1>>"%LOG%" 2>>&1
    if not errorlevel 1 exit /b 0
    echo [WARN] tar extraction failed. Trying PowerShell Expand-Archive...
    >> "%LOG%" echo tar failed, trying Expand-Archive
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%ZIPFILE%' -DestinationPath '%DESTDIR%' -Force" 1>>"%LOG%" 2>>&1
if errorlevel 1 (
    echo [ERROR] Zip extraction failed:
    echo   %ZIPFILE%
    echo See log:
    echo   %LOG%
    exit /b 1
)
exit /b 0

:write_patch_script
> "%BUILD_TMP%\patch_reclip.py" echo import pathlib, re, sys
>> "%BUILD_TMP%\patch_reclip.py" echo app_path = pathlib.Path(sys.argv[1])
>> "%BUILD_TMP%\patch_reclip.py" echo text = app_path.read_text(encoding="utf-8")
>> "%BUILD_TMP%\patch_reclip.py" echo original = text
>> "%BUILD_TMP%\patch_reclip.py" echo if "import sys" not in text:
>> "%BUILD_TMP%\patch_reclip.py" echo ^    text = text.replace("import os\n", "import os\nimport sys\n", 1) if "import os\n" in text else "import sys\n" + text
>> "%BUILD_TMP%\patch_reclip.py" echo text = text.replace('["yt-dlp"', '[sys.executable, "-m", "yt_dlp"')
>> "%BUILD_TMP%\patch_reclip.py" echo text = text.replace("['yt-dlp'", "[sys.executable, '-m', 'yt_dlp'")
>> "%BUILD_TMP%\patch_reclip.py" echo text = text.replace('(\"yt-dlp\"', '(sys.executable, \"-m\", \"yt_dlp\"')
>> "%BUILD_TMP%\patch_reclip.py" echo text = text.replace("('yt-dlp'", "(sys.executable, '-m', 'yt_dlp'")
>> "%BUILD_TMP%\patch_reclip.py" echo if text == original:
>> "%BUILD_TMP%\patch_reclip.py" echo ^    print("WARNING: No yt-dlp command pattern was changed. The app may already be patched or upstream changed app.py.")
>> "%BUILD_TMP%\patch_reclip.py" echo app_path.write_text(text, encoding="utf-8")
>> "%BUILD_TMP%\patch_reclip.py" echo print("Patch step completed.")
exit /b 0

:write_start_script
> "%ROOT%\start-reclip.bat" echo @echo off
>> "%ROOT%\start-reclip.bat" echo setlocal EnableExtensions
>> "%ROOT%\start-reclip.bat" echo chcp 65001 ^>nul
>> "%ROOT%\start-reclip.bat" echo set "BASE=%%~dp0"
>> "%ROOT%\start-reclip.bat" echo set "PATH=%%BASE%%python;%%BASE%%python\Scripts;%%BASE%%ffmpeg\bin;%%PATH%%"
>> "%ROOT%\start-reclip.bat" echo set "PYTHONUTF8=1"
>> "%ROOT%\start-reclip.bat" echo set "PYTHONNOUSERSITE=1"
>> "%ROOT%\start-reclip.bat" echo set "RECLIP_DOWNLOAD_DIR=%%BASE%%data\downloads"
>> "%ROOT%\start-reclip.bat" echo cd /d "%%BASE%%app"
>> "%ROOT%\start-reclip.bat" echo echo === ReClip Portable ===
>> "%ROOT%\start-reclip.bat" echo echo Open in browser: http://127.0.0.1:8899
>> "%ROOT%\start-reclip.bat" echo echo To stop: press Ctrl+C or close this window.
>> "%ROOT%\start-reclip.bat" echo echo.
>> "%ROOT%\start-reclip.bat" echo "%%BASE%%python\python.exe" -m yt_dlp --version ^>nul 2^>nul
>> "%ROOT%\start-reclip.bat" echo if errorlevel 1 ^(
>> "%ROOT%\start-reclip.bat" echo     echo [ERROR] yt-dlp is not available in portable Python.
>> "%ROOT%\start-reclip.bat" echo     pause
>> "%ROOT%\start-reclip.bat" echo     exit /b 1
>> "%ROOT%\start-reclip.bat" echo ^)
>> "%ROOT%\start-reclip.bat" echo "%%BASE%%ffmpeg\bin\ffmpeg.exe" -version ^>nul 2^>nul
>> "%ROOT%\start-reclip.bat" echo if errorlevel 1 ^(
>> "%ROOT%\start-reclip.bat" echo     echo [ERROR] Portable FFmpeg was not found.
>> "%ROOT%\start-reclip.bat" echo     pause
>> "%ROOT%\start-reclip.bat" echo     exit /b 1
>> "%ROOT%\start-reclip.bat" echo ^)
>> "%ROOT%\start-reclip.bat" echo "%%BASE%%python\python.exe" app.py
>> "%ROOT%\start-reclip.bat" echo echo.
>> "%ROOT%\start-reclip.bat" echo echo ReClip stopped.
>> "%ROOT%\start-reclip.bat" echo pause
exit /b 0

:write_update_script
> "%ROOT%\update-ytdlp.bat" echo @echo off
>> "%ROOT%\update-ytdlp.bat" echo setlocal EnableExtensions
>> "%ROOT%\update-ytdlp.bat" echo chcp 65001 ^>nul
>> "%ROOT%\update-ytdlp.bat" echo set "BASE=%%~dp0"
>> "%ROOT%\update-ytdlp.bat" echo set "PATH=%%BASE%%python;%%BASE%%python\Scripts;%%BASE%%ffmpeg\bin;%%PATH%%"
>> "%ROOT%\update-ytdlp.bat" echo echo Updating yt-dlp inside portable ReClip...
>> "%ROOT%\update-ytdlp.bat" echo "%%BASE%%python\python.exe" -m pip install --upgrade "yt-dlp[default]" --no-warn-script-location
>> "%ROOT%\update-ytdlp.bat" echo echo.
>> "%ROOT%\update-ytdlp.bat" echo "%%BASE%%python\python.exe" -m yt_dlp --version
>> "%ROOT%\update-ytdlp.bat" echo pause
exit /b 0

:write_readme
> "%ROOT%\README-PORTABLE.txt" echo ReClip Portable for Windows 11
>> "%ROOT%\README-PORTABLE.txt" echo.
>> "%ROOT%\README-PORTABLE.txt" echo How to run:
>> "%ROOT%\README-PORTABLE.txt" echo   1. Open start-reclip.bat
>> "%ROOT%\README-PORTABLE.txt" echo   2. Open http://127.0.0.1:8899 in your browser
>> "%ROOT%\README-PORTABLE.txt" echo   3. To stop ReClip, press Ctrl+C in the console window
>> "%ROOT%\README-PORTABLE.txt" echo.
>> "%ROOT%\README-PORTABLE.txt" echo How to move to another PC:
>> "%ROOT%\README-PORTABLE.txt" echo   Copy the whole ReClip-Portable folder.
>> "%ROOT%\README-PORTABLE.txt" echo   Do not copy only app or only python.
>> "%ROOT%\README-PORTABLE.txt" echo.
>> "%ROOT%\README-PORTABLE.txt" echo Downloads folder:
>> "%ROOT%\README-PORTABLE.txt" echo   data\downloads
>> "%ROOT%\README-PORTABLE.txt" echo.
>> "%ROOT%\README-PORTABLE.txt" echo If YouTube stops working:
>> "%ROOT%\README-PORTABLE.txt" echo   Run update-ytdlp.bat
exit /b 0

:fail
echo.
echo === ERROR ===
echo The portable build was not completed.
echo.
echo Log file:
echo   %LOG%
echo.
echo Copy everything from this window and also send reclip-portable-build.log if it exists.
echo.
pause
exit /b 1
