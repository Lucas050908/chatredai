@echo off
setlocal EnableDelayedExpansion
title ChatRedAI
color 0C

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "DEPS=%ROOT%\deps"
set "PYTHON_DIR=%DEPS%\python"
set "PY=%PYTHON_DIR%\python.exe"

if exist "%PY%" goto :start_server

echo.
echo  ================================================
echo   ChatRedAI - Forste gangs opsaetning
echo   Downloader noedvendige programmer...
echo   (Kraver internetforbindelse)
echo  ================================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"
if not exist "%PYTHON_DIR%" mkdir "%PYTHON_DIR%"

:: Aktiver TLS 1.2 i Windows (kræver admin - ignoreres hvis ikke tilgængeligt)
echo Aktiverer TLS 1.2 support...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v "DefaultSecureProtocols" /t REG_DWORD /d 2688 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "Enabled" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "DisabledByDefault" /t REG_DWORD /d 0 /f >nul 2>&1

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

:: Metode 1: certutil (bruger WinINet - mest kompatibel med Win7)
certutil -urlcache -split -f "%PY_URL%" "%DEPS%\python.zip" >nul 2>&1

:: Metode 2: PowerShell med numerisk TLS vaerdi (omgaar enum-problem)
if not exist "%DEPS%\python.zip" (
    powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; (New-Object Net.WebClient).DownloadFile('%PY_URL%', '%DEPS%\python.zip') }" 2>nul
)

if not exist "%DEPS%\python.zip" (
    echo.
    echo  FEJL: Kunne ikke downloade Python automatisk.
    echo.
    echo  Windows 7 kraever TLS 1.2 for at downloade fra python.org.
    echo  Hent manuelt:
    echo  %PY_URL%
    echo.
    echo  Gem filen som: %DEPS%\python.zip
    echo  Kør derefter start.bat igen.
    echo.
    pause
    exit /b 1
)

echo [2/4] Udpakker Python...
:: Shell.Application virker på ALLE Windows versioner (XP og nyere)
powershell -ExecutionPolicy Bypass -Command "& { $sh = New-Object -ComObject Shell.Application; $zip = $sh.Namespace('%DEPS%\python.zip'); $dst = $sh.Namespace('%PYTHON_DIR%'); $dst.CopyHere($zip.Items(), 20); $limit = 60; do { Start-Sleep -Seconds 1; $limit-- } while (($dst.Items().Count -lt $zip.Items().Count) -and ($limit -gt 0)) }"
del "%DEPS%\python.zip" >nul 2>&1

if not exist "%PY%" (
    echo.
    echo  FEJL: Udpakning af Python mislykkedes!
    echo.
    pause
    exit /b 1
)

echo [3/4] Konfigurerer Python...
powershell -ExecutionPolicy Bypass -Command "& { Get-ChildItem '%PYTHON_DIR%' -Filter '*._pth' | ForEach-Object { $p = $_.FullName; (Get-Content $p) -replace '#import site', 'import site' | Set-Content $p } }"

:: Download pip
certutil -urlcache -split -f "https://bootstrap.pypa.io/pip/3.8/get-pip.py" "%DEPS%\get-pip.py" >nul 2>&1
if not exist "%DEPS%\get-pip.py" (
    powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; (New-Object Net.WebClient).DownloadFile('https://bootstrap.pypa.io/pip/3.8/get-pip.py', '%DEPS%\get-pip.py') }" 2>nul
)
if not exist "%DEPS%\get-pip.py" (
    echo.
    echo  FEJL: Kunne ikke downloade pip!
    echo.
    pause
    exit /b 1
)
"%PY%" "%DEPS%\get-pip.py" --no-warn-script-location -q
del "%DEPS%\get-pip.py" >nul 2>&1

echo [4/4] Installerer Flask...
"%PY%" -m pip install "flask>=2.3,<3" --no-warn-script-location -q
if errorlevel 1 (
    echo.
    echo  FEJL: Kunne ikke installere Flask!
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

start /b cmd /c "timeout /t 2 /nobreak >nul && start \"\" \"http://localhost:5000\""
"%PY%" "%ROOT%\backend\app.py"

if errorlevel 1 (
    echo.
    echo  Serveren stoppede med en fejl.
    pause
)
