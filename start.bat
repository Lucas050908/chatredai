@echo off
setlocal EnableDelayedExpansion
title ChatRedAI
color 0C

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "DEPS=%ROOT%\deps"
set "PYTHON_DIR=%DEPS%\python"
set "PY=%PYTHON_DIR%\python.exe"
set "MODEL_DIR=%ROOT%\model"
set "MODEL_FILE=%MODEL_DIR%\model.gguf"
set "LLAMA_DIR=%ROOT%\llama"
set "LLAMA_EXE=%LLAMA_DIR%\llama-server.exe"

if exist "%PY%" if exist "%LLAMA_EXE%" if exist "%MODEL_FILE%" goto :start_server

echo.
echo  ================================================
echo   ChatRedAI - Forste gangs opsaetning
echo  ================================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"
if not exist "%PYTHON_DIR%" mkdir "%PYTHON_DIR%"
if not exist "%MODEL_DIR%" mkdir "%MODEL_DIR%"
if not exist "%LLAMA_DIR%" mkdir "%LLAMA_DIR%"

:: Aktiver TLS 1.2
echo Aktiverer TLS 1.2...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v "DefaultSecureProtocols" /t REG_DWORD /d 2688 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "Enabled" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "DisabledByDefault" /t REG_DWORD /d 0 /f >nul 2>&1

set "ARCH=win32"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=amd64"
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH=amd64"

:: ==== PYTHON ====
if exist "%PY%" goto :llama_setup

if "%ARCH%"=="amd64" (
    set "PY_URL=https://www.python.org/ftp/python/3.8.10/python-3.8.10-embed-amd64.zip"
) else (
    set "PY_URL=https://www.python.org/ftp/python/3.8.10/python-3.8.10-embed-win32.zip"
)

echo [1/4] Downloader Python 3.8...
certutil -urlcache -split -f "%PY_URL%" "%DEPS%\python.zip" >nul 2>&1
if not exist "%DEPS%\python.zip" goto :python_fejl
for %%F in ("%DEPS%\python.zip") do if %%~zF LSS 1000000 ( del "%DEPS%\python.zip" >nul 2>&1 && goto :python_fejl )

echo [2/4] Udpakker Python...
echo Dim oApp, oZip, oDst > "%DEPS%\unzip.vbs"
echo Set oApp = CreateObject("Shell.Application") >> "%DEPS%\unzip.vbs"
echo Set oZip = oApp.Namespace("%DEPS%\python.zip") >> "%DEPS%\unzip.vbs"
echo Set oDst = oApp.Namespace("%PYTHON_DIR%") >> "%DEPS%\unzip.vbs"
echo oDst.CopyHere oZip.Items(), 1044 >> "%DEPS%\unzip.vbs"
echo WScript.Sleep 25000 >> "%DEPS%\unzip.vbs"
cscript //nologo "%DEPS%\unzip.vbs"
del "%DEPS%\unzip.vbs" >nul 2>&1 & del "%DEPS%\python.zip" >nul 2>&1
if not exist "%PY%" ( echo FEJL: Python udpakning fejlede! & pause & exit /b 1 )

echo [3/4] Konfigurerer Python og pip...
for %%F in ("%PYTHON_DIR%\*._pth") do (
    powershell -ExecutionPolicy Bypass -Command "$c=Get-Content '%%F'; $c -replace '#import site','import site' | Set-Content '%%F'"
)
certutil -urlcache -split -f "https://bootstrap.pypa.io/pip/3.8/get-pip.py" "%DEPS%\get-pip.py" >nul 2>&1
"%PY%" "%DEPS%\get-pip.py" --no-warn-script-location -q
del "%DEPS%\get-pip.py" >nul 2>&1

echo [4/4] Installerer Flask...
"%PY%" -m pip install "flask>=2.3,<3" --no-warn-script-location -q

:: ==== LLAMA.CPP SERVER ====
:llama_setup
if exist "%LLAMA_EXE%" goto :model_setup

echo.
echo  Downloader llama.cpp AI server fra GitHub...
echo  (soeger efter nyeste Windows version)
powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; $wc = New-Object Net.WebClient; $wc.Headers['User-Agent'] = 'Mozilla/5.0'; $json = $wc.DownloadString('https://api.github.com/repos/ggerganov/llama.cpp/releases/latest'); if ($json -match '(https://github\.com/ggerganov/llama\.cpp/releases/download/[^\""]*bin-win-avx[^\""]*x64[^\""]*\.zip)') { $wc.DownloadFile($Matches[1], '%DEPS%\llama.zip') } }" 2>nul

if not exist "%DEPS%\llama.zip" (
    echo  Prover noavx version...
    powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; $wc = New-Object Net.WebClient; $wc.Headers['User-Agent'] = 'Mozilla/5.0'; $json = $wc.DownloadString('https://api.github.com/repos/ggerganov/llama.cpp/releases/latest'); if ($json -match '(https://github\.com/ggerganov/llama\.cpp/releases/download/[^\""]*bin-win[^\""]*x64[^\""]*\.zip)') { $wc.DownloadFile($Matches[1], '%DEPS%\llama.zip') } }" 2>nul
)

if not exist "%DEPS%\llama.zip" (
    echo.
    echo  FEJL: Kunne ikke downloade llama.cpp!
    echo  Hent manuelt fra: https://github.com/ggerganov/llama.cpp/releases
    echo  Download en "bin-win-avx-x64.zip" fil og udpak llama-server.exe til:
    echo  %LLAMA_DIR%\llama-server.exe
    echo.
    pause
    exit /b 1
)

echo  Udpakker llama.cpp...
echo Dim oApp, oZip, oDst > "%DEPS%\unzip.vbs"
echo Set oApp = CreateObject("Shell.Application") >> "%DEPS%\unzip.vbs"
echo Set oZip = oApp.Namespace("%DEPS%\llama.zip") >> "%DEPS%\unzip.vbs"
echo Set oDst = oApp.Namespace("%LLAMA_DIR%") >> "%DEPS%\unzip.vbs"
echo oDst.CopyHere oZip.Items(), 1044 >> "%DEPS%\unzip.vbs"
echo WScript.Sleep 15000 >> "%DEPS%\unzip.vbs"
cscript //nologo "%DEPS%\unzip.vbs"
del "%DEPS%\unzip.vbs" >nul 2>&1 & del "%DEPS%\llama.zip" >nul 2>&1

:: Flet evt. undermappe op
for /d %%D in ("%LLAMA_DIR%\llama-*") do (
    if not exist "%LLAMA_EXE%" (
        xcopy "%%D\*" "%LLAMA_DIR%\" /q /y >nul 2>&1
    )
)

if not exist "%LLAMA_EXE%" (
    echo FEJL: llama-server.exe ikke fundet efter udpakning!
    pause
    exit /b 1
)

:: ==== MODEL ====
:model_setup
if exist "%MODEL_FILE%" goto :check_model

echo.
echo  ================================================
echo   AI MODEL SKAL DOWNLOADES MANUELT
echo.
echo   1. Abn din browser og ga til:
echo   https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF
echo.
echo   2. Download filen:
echo   DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf  (ca. 5 GB)
echo.
echo   3. Gem filen som:
echo   %MODEL_FILE%
echo.
echo   4. Tryk en vilkaarlig tast her naar filen er gemt
echo  ================================================
echo.
:vent_model
if exist "%MODEL_FILE%" goto :check_model
pause
if exist "%MODEL_FILE%" goto :check_model
echo  Filen blev ikke fundet. Prøv igen...
goto :vent_model

:check_model
for %%F in ("%MODEL_FILE%") do set "MSIZE=%%~zF"
if %MSIZE% LSS 100000000 (
    echo FEJL: Modelfil er for lille - download fejlede!
    del "%MODEL_FILE%" >nul 2>&1
    goto :model_setup
)

echo.
echo  Opsaetning faerdig!
echo.

:start_server
echo  ================================================
echo   ChatRedAI starter med DeepSeek AI...
echo   Abn din browser pa: http://localhost:5000
echo   Foerste svar kan tage 1-2 minutter (model indlaeses)
echo   Luk dette vindue for at stoppe.
echo  ================================================
echo.

start /b cmd /c "timeout /t 3 /nobreak >nul && start \"\" \"http://localhost:5000\""
"%PY%" "%ROOT%\backend\app.py"

if errorlevel 1 ( echo. & echo  Serveren stoppede med fejl. & pause )
