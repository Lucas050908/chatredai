@echo off
setlocal EnableDelayedExpansion
title ChatRedAI
color 0C
chcp 65001 >nul 2>&1

:: ============================================================
::  ChatRedAI - Windows 7+ launcher
::  Downloader automatisk Python 3.8 og Flask ved forste start
:: ============================================================

set "ROOT=%~dp0"
:: Fjern traeling backslash
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "DEPS=%ROOT%\deps"
set "PYTHON_DIR=%DEPS%\python"
set "PY=%PYTHON_DIR%\python.exe"

:: Allerede sat op?
if exist "%PY%" goto :start_server

echo.
echo  ================================================
echo   ChatRedAI - Forste gangs opsaetning
echo   Downloader noedvendige programmer...
echo   (Kraver internetforbindelse)
echo  ================================================
echo.

:: Opret mapper
if not exist "%DEPS%" mkdir "%DEPS%"
if not exist "%PYTHON_DIR%" mkdir "%PYTHON_DIR%"

:: Detekter 32-bit eller 64-bit Windows
set "ARCH=win32"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=amd64"
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH=amd64"

if "%ARCH%"=="amd64" (
    set "PY_URL=https://www.python.org/ftp/python/3.8.18/python-3.8.18-embed-amd64.zip"
) else (
    set "PY_URL=https://www.python.org/ftp/python/3.8.18/python-3.8.18-embed-win32.zip"
)

echo [1/4] Downloader Python 3.8 (%ARCH%)...
echo       Dette kan tage 1-2 minutter...
powershell -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%PY_URL%', '%DEPS%\python.zip') }"
if errorlevel 1 (
    echo.
    echo  FEJL: Kunne ikke downloade Python!
    echo  Tjek din internetforbindelse og proev igen.
    echo.
    pause
    exit /b 1
)

echo [2/4] Udpakker Python...
powershell -ExecutionPolicy Bypass -Command "& { Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory('%DEPS%\python.zip', '%PYTHON_DIR%') }"
if errorlevel 1 (
    echo.
    echo  FEJL: Kunne ikke udpakke Python!
    echo.
    pause
    exit /b 1
)
del "%DEPS%\python.zip" >nul 2>&1

:: Aktiver site-packages i den portable Python (fjern '#' fra '#import site')
echo [3/4] Konfigurerer Python...
powershell -ExecutionPolicy Bypass -Command "& { Get-ChildItem '%PYTHON_DIR%' -Filter '*._pth' | ForEach-Object { $p = $_.FullName; (Get-Content $p) -replace '#import site', 'import site' | Set-Content $p } }"

:: Download og installer pip (Python 3.8 kompatibel version)
powershell -ExecutionPolicy Bypass -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://bootstrap.pypa.io/pip/3.8/get-pip.py', '%DEPS%\get-pip.py') }"
if errorlevel 1 (
    echo.
    echo  FEJL: Kunne ikke downloade pip!
    echo.
    pause
    exit /b 1
)
"%PY%" "%DEPS%\get-pip.py" --no-warn-script-location -q
del "%DEPS%\get-pip.py" >nul 2>&1

echo [4/4] Installerer Flask (kan tage lidt tid)...
"%PY%" -m pip install "flask>=2.3,<3" --no-warn-script-location -q
if errorlevel 1 (
    echo.
    echo  FEJL: Kunne ikke installere Flask!
    echo  Tjek din internetforbindelse og proev igen.
    echo.
    pause
    exit /b 1
)

echo.
echo  Opsaetning faerdig!
echo.

:start_server
echo  ================================================
echo   ChatRedAI starter...
echo   Abn din browser pa: http://localhost:5000
echo   Luk dette vindue for at stoppe programmet.
echo  ================================================
echo.

:: Abn browser efter 2 sekunder
start /b cmd /c "timeout /t 2 /nobreak >nul && start \"\" \"http://localhost:5000\""

:: Start Flask-serveren
"%PY%" "%ROOT%\backend\app.py"

if errorlevel 1 (
    echo.
    echo  Serveren stoppede med en fejl.
    pause
)
