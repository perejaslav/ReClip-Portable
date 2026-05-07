@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "BASE=%~dp0"
set "PATH=%BASE%python;%BASE%python\Scripts;%BASE%ffmpeg\bin;%PATH%"
echo Updating yt-dlp inside portable ReClip...
"%BASE%python\python.exe" -m pip install --upgrade "yt-dlp[default]" --no-warn-script-location
echo.
"%BASE%python\python.exe" -m yt_dlp --version
pause
