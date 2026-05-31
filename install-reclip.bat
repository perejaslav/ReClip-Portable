@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title ReClip Portable Installer

REM ============================================================
REM  ReClip Portable Installer v1.1
REM  Downloads Python, FFmpeg, Flask, yt-dlp on first run.
REM  ~12 KB installer -> ~500 MB installed
REM ============================================================

set "BASE=%~dp0"
set "LOG=%BASE%install.log"
set "PY_VER=3.12.10"

set "PY_URL=https://www.python.org/ftp/python/%PY_VER%/python-%PY_VER%-embed-amd64.zip"
set "GETPIP_URL=https://bootstrap.pypa.io/get-pip.py"
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

set "PYZIP=%BASE%_tmp_python.zip"
set "GETPIP=%BASE%_tmp_getpip.py"
set "FFZIP=%BASE%_tmp_ffmpeg.zip"

echo.
echo  ============================================
echo   ReClip Portable Installer
echo   Downloads ~350 MB on first run
echo  ============================================
echo.

if not exist "%BASE%app\app.py" (
    echo  [ERROR] app\app.py not found.
    echo  This installer must be in the same folder as the app\ directory.
    pause
    exit /b 1
)

REM === Check if already installed ===
if exist "%BASE%python\python.exe" (
    if exist "%BASE%ffmpeg\bin\ffmpeg.exe" (
        echo  ReClip is already installed.
        echo.
        set /p "CHOICE=  Re-install dependencies? (y/N): "
        if /i not "!CHOICE!"=="y" (
            echo  Skipped. Run start-reclip.bat to launch.
            pause
            exit /b 0
        )
        echo.
    )
)

> "%LOG%" echo ReClip Portable Installer log - %DATE% %TIME%

REM === Step 1: Download and extract Python ===
echo  [1/5] Downloading Python %PY_VER% embeddable (~8 MB)...
call :download "%PY_URL%" "%PYZIP%" || goto :fail

echo  [2/5] Extracting Python...
if exist "%BASE%python" rmdir /s /q "%BASE%python" >nul 2>nul
mkdir "%BASE%python"
call :extract "%PYZIP%" "%BASE%python" || goto :fail

if not exist "%BASE%python\python.exe" (
    echo  [ERROR] python.exe not found after extraction.
    goto :fail
)

REM Enable site-packages in embeddable Python (uncomment "import site")
set "PTH="
for %%F in ("%BASE%python\python*._pth") do set "PTH=%%~fF"
if not defined PTH (
    echo  [ERROR] ._pth file not found.
    goto :fail
)
"%BASE%python\python.exe" -c "import pathlib,glob; p=glob.glob(r'%BASE%python\python*._pth')[0]; t=pathlib.Path(p).read_text(); t=t.replace('#import site','import site'); pathlib.Path(p).write_text(t+'\nLib\site-packages\n' if 'Lib\site-packages' not in t else t); print('._pth patched')" >>"%LOG%" 2>&1

REM === Step 2: Install pip and Python deps ===
echo  [3/5] Installing pip, Flask, yt-dlp...
call :download "%GETPIP_URL%" "%GETPIP%" || goto :fail
"%BASE%python\python.exe" "%GETPIP%" --no-warn-script-location >>"%LOG%" 2>&1
if errorlevel 1 (
    echo  [ERROR] pip installation failed. See install.log.
    goto :fail
)

"%BASE%python\python.exe" -m pip install --upgrade pip setuptools wheel --no-warn-script-location >>"%LOG%" 2>&1
"%BASE%python\python.exe" -m pip install --upgrade flask "yt-dlp[default]" --no-warn-script-location >>"%LOG%" 2>&1
if errorlevel 1 (
    echo  [ERROR] Dependency installation failed. See install.log.
    goto :fail
)

REM === Step 3: Download and extract FFmpeg ===
echo  [4/5] Downloading FFmpeg (~180 MB, may take a minute)...
call :download "%FFMPEG_URL%" "%FFZIP%" || goto :fail

echo  [5/5] Extracting FFmpeg...
mkdir "%BASE%ffmpeg\bin" 2>nul
mkdir "%BASE%_tmp_ffex" 2>nul
call :extract "%FFZIP%" "%BASE%_tmp_ffex" || goto :fail

REM Copy ffmpeg.exe and ffprobe.exe from extracted tree
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$ff=Get-ChildItem -LiteralPath '%BASE%_tmp_ffex' -Recurse -Filter ffmpeg.exe -File | Select -First 1;" ^
    "$fp=Get-ChildItem -LiteralPath '%BASE%_tmp_ffex' -Recurse -Filter ffprobe.exe -File | Select -First 1;" ^
    "if(-not $ff){throw 'ffmpeg.exe not found'}; if(-not $fp){throw 'ffprobe.exe not found'};" ^
    "Copy-Item $ff.FullName '%BASE%ffmpeg\bin\ffmpeg.exe' -Force;" ^
    "Copy-Item $fp.FullName '%BASE%ffmpeg\bin\ffprobe.exe' -Force;" ^
    "Write-Host '  Copied ffmpeg.exe + ffprobe.exe'" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo  [ERROR] FFmpeg extraction failed. See install.log.
    goto :fail
)

REM === Verify ===
echo.
echo  Verifying...
set "OK=1"
"%BASE%python\python.exe" -m yt_dlp --version >nul 2>&1
if errorlevel 1 (
    echo  [WARN] yt-dlp not working. Run update-ytdlp.bat later.
    set "OK=0"
) else (
    for /f "tokens=*" %%V in ('"%BASE%python\python.exe" -m yt_dlp --version') do echo  yt-dlp: %%V
)
"%BASE%ffmpeg\bin\ffmpeg.exe" -version >nul 2>&1
if errorlevel 1 (
    echo  [WARN] FFmpeg not working.
    set "OK=0"
) else (
    echo  ffmpeg: OK
)

REM === Cleanup temp files ===
del /f /q "%PYZIP%" 2>nul
del /f /q "%GETPIP%" 2>nul
del /f /q "%FFZIP%" 2>nul
rmdir /s /q "%BASE%_tmp_ffex" 2>nul

if not exist "%BASE%app\downloads" mkdir "%BASE%app\downloads"

echo.
if "%OK%"=="1" (
    echo  ============================================
    echo   Installation complete!
    echo.
    echo   Run:   start-reclip.bat
    echo   Open:  http://127.0.0.1:8899
    echo  ============================================
) else (
    echo  Installation finished with warnings.
    echo  Check install.log for details.
)
echo.
pause
exit /b 0


REM ============================================================
REM  Helper functions
REM ============================================================

:download
set "DURL=%~1"
set "DOUT=%~2"
>> "%LOG%" echo download: %DURL%
where curl >nul 2>nul
if not errorlevel 1 (
    curl -L --fail --retry 3 -o "%DOUT%" "%DURL%" >>"%LOG%" 2>&1
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DURL%' -OutFile '%DOUT%'" >>"%LOG%" 2>&1
)
if not exist "%DOUT%" (
    echo  [ERROR] Download failed: %DURL%
    echo  Check install.log and your internet connection.
    exit /b 1
)
exit /b 0

:extract
set "EZ=%~1"
set "ED=%~2"
>> "%LOG%" echo extract: %EZ% into %ED%
where tar >nul 2>nul
if not errorlevel 1 (
    tar -xf "%EZ%" -C "%ED%" >>"%LOG%" 2>&1
    if not errorlevel 1 exit /b 0
    >> "%LOG%" echo tar failed, trying PowerShell
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%EZ%' -DestinationPath '%ED%' -Force" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo  [ERROR] Extraction failed: %EZ%
    exit /b 1
)
exit /b 0

:fail
echo.
echo  === INSTALLATION FAILED ===
echo  See install.log for details:
echo    %LOG%
echo.
pause
exit /b 1
