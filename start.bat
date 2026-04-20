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
echo  ================================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"
if not exist "%PYTHON_DIR%" mkdir "%PYTHON_DIR%"

:: Aktiver TLS 1.2 (kræver admin - fejler stille hvis ikke muligt)
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
certutil -urlcache -split -f "%PY_URL%" "%DEPS%\python.zip" >nul 2>&1
if not exist "%DEPS%\python.zip" (
    powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; (New-Object Net.WebClient).DownloadFile('%PY_URL%', '%DEPS%\python.zip') }" 2>nul
)
if not exist "%DEPS%\python.zip" goto :download_fejl

:: Tjek at filen er stor nok (mindst 1MB - ellers er det en fejlside)
for %%F in ("%DEPS%\python.zip") do set "ZIPSIZE=%%~zF"
if %ZIPSIZE% LSS 1000000 (
    del "%DEPS%\python.zip" >nul 2>&1
    goto :download_fejl
)

echo [2/4] Udpakker Python...
:: VBScript er mest palidelig til ZIP udpakning pa Windows 7
echo Dim oApp, oZip, oDst > "%DEPS%\unzip.vbs"
echo Set oApp = CreateObject("Shell.Application") >> "%DEPS%\unzip.vbs"
echo Set oZip = oApp.Namespace("%DEPS%\python.zip") >> "%DEPS%\unzip.vbs"
echo Set oDst = oApp.Namespace("%PYTHON_DIR%") >> "%DEPS%\unzip.vbs"
echo oDst.CopyHere oZip.Items(), 1044 >> "%DEPS%\unzip.vbs"
echo WScript.Sleep 25000 >> "%DEPS%\unzip.vbs"
cscript //nologo "%DEPS%\unzip.vbs"
del "%DEPS%\unzip.vbs" >nul 2>&1
del "%DEPS%\python.zip" >nul 2>&1

if not exist "%PY%" (
    echo.
    echo  FEJL: Udpakning af Python mislykkedes!
    echo.
    pause
    exit /b 1
)

echo [3/4] Konfigurerer Python...
echo import site >> "%PYTHON_DIR%\python38._pth" 2>nul
powershell -ExecutionPolicy Bypass -Command "Get-ChildItem '%PYTHON_DIR%' -Filter '*._pth' | ForEach-Object { $f = $_.FullName; $c = Get-Content $f; if ($c -notcontains 'import site') { $c + 'import site' | Set-Content $f } else { $c -replace '#import site','import site' | Set-Content $f } }" 2>nul

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
goto :start_server

:download_fejl
echo.
echo  FEJL: Kunne ikke downloade Python!
echo.
echo  Hent manuelt fra: %PY_URL%
echo  Gem som: %DEPS%\python.zip
echo  Kør start.bat igen bagefter.
echo.
pause
exit /b 1

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
