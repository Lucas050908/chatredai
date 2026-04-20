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
set "MODEL_URL=https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf"

:: Spring opsaetning over hvis alt allerede er installeret
if exist "%PY%" if exist "%MODEL_FILE%" goto :start_server

echo.
echo  ================================================
echo   ChatRedAI - Forste gangs opsaetning
echo   Downloader noedvendige programmer...
echo  ================================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"
if not exist "%PYTHON_DIR%" mkdir "%PYTHON_DIR%"
if not exist "%MODEL_DIR%" mkdir "%MODEL_DIR%"

:: Aktiver TLS 1.2
echo Aktiverer TLS 1.2 support...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v "DefaultSecureProtocols" /t REG_DWORD /d 2688 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "Enabled" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v "DisabledByDefault" /t REG_DWORD /d 0 /f >nul 2>&1

set "ARCH=win32"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=amd64"
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH=amd64"

if "%ARCH%"=="amd64" (
    set "PY_URL=https://www.python.org/ftp/python/3.8.10/python-3.8.10-embed-amd64.zip"
) else (
    set "PY_URL=https://www.python.org/ftp/python/3.8.10/python-3.8.10-embed-win32.zip"
)

:: ---- Python installation ----
if exist "%PY%" goto :install_packages

echo [1/5] Downloader Python 3.8 (%ARCH%)...
certutil -urlcache -split -f "%PY_URL%" "%DEPS%\python.zip" >nul 2>&1
if not exist "%DEPS%\python.zip" (
    powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; (New-Object Net.WebClient).DownloadFile('%PY_URL%', '%DEPS%\python.zip') }" 2>nul
)
if not exist "%DEPS%\python.zip" goto :download_fejl
for %%F in ("%DEPS%\python.zip") do set "ZIPSIZE=%%~zF"
if %ZIPSIZE% LSS 1000000 ( del "%DEPS%\python.zip" >nul 2>&1 && goto :download_fejl )

echo [2/5] Udpakker Python...
echo Dim oApp, oZip, oDst > "%DEPS%\unzip.vbs"
echo Set oApp = CreateObject("Shell.Application") >> "%DEPS%\unzip.vbs"
echo Set oZip = oApp.Namespace("%DEPS%\python.zip") >> "%DEPS%\unzip.vbs"
echo Set oDst = oApp.Namespace("%PYTHON_DIR%") >> "%DEPS%\unzip.vbs"
echo oDst.CopyHere oZip.Items(), 1044 >> "%DEPS%\unzip.vbs"
echo WScript.Sleep 25000 >> "%DEPS%\unzip.vbs"
cscript //nologo "%DEPS%\unzip.vbs"
del "%DEPS%\unzip.vbs" >nul 2>&1
del "%DEPS%\python.zip" >nul 2>&1
if not exist "%PY%" ( echo FEJL: Udpakning mislykkedes! & pause & exit /b 1 )

echo [3/5] Konfigurerer Python...
for %%F in ("%PYTHON_DIR%\*._pth") do (
    powershell -ExecutionPolicy Bypass -Command "$c = Get-Content '%%F'; $c -replace '#import site','import site' | Set-Content '%%F'"
)
certutil -urlcache -split -f "https://bootstrap.pypa.io/pip/3.8/get-pip.py" "%DEPS%\get-pip.py" >nul 2>&1
if not exist "%DEPS%\get-pip.py" ( echo FEJL: Kunne ikke downloade pip! & pause & exit /b 1 )
"%PY%" "%DEPS%\get-pip.py" --no-warn-script-location -q
del "%DEPS%\get-pip.py" >nul 2>&1

:install_packages
echo [4/5] Installerer Flask og AI motor...
"%PY%" -m pip install "flask>=2.3,<3" --no-warn-script-location -q
if errorlevel 1 ( echo FEJL: Flask installation fejlede! & pause & exit /b 1 )

:: Installer llama-cpp-python (forudbygget Windows wheel - ingen kompilering)
"%PY%" -m pip install llama-cpp-python --prefer-binary --no-warn-script-location -q
if errorlevel 1 (
    echo.
    echo  ADVARSEL: llama-cpp-python kunne ikke installeres automatisk.
    echo  Proever alternativ metode...
    "%PY%" -m pip install llama-cpp-python --prefer-binary --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu --no-warn-script-location -q
)

:: ---- Model download ----
if exist "%MODEL_FILE%" goto :check_model_size

echo [5/5] Downloader DeepSeek R1 7B model (ca. 5 GB)...
echo       Dette vil tage lang tid - lad vinduet vaere aabent!
echo.
certutil -urlcache -split -f "%MODEL_URL%" "%MODEL_FILE%"
if not exist "%MODEL_FILE%" (
    powershell -ExecutionPolicy Bypass -Command "& { try { [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072) } catch {}; (New-Object Net.WebClient).DownloadFile('%MODEL_URL%', '%MODEL_FILE%') }" 2>nul
)
if not exist "%MODEL_FILE%" (
    echo.
    echo  FEJL: Kunne ikke downloade AI modellen!
    echo.
    echo  Download manuelt fra din browser:
    echo  %MODEL_URL%
    echo.
    echo  Gem filen som: %MODEL_FILE%
    echo  Koor start.bat igen bagefter.
    echo.
    pause
    exit /b 1
)

:check_model_size
for %%F in ("%MODEL_FILE%") do set "MSIZE=%%~zF"
if %MSIZE% LSS 100000000 (
    echo.
    echo  FEJL: Model filen er for lille - download fejlede.
    del "%MODEL_FILE%" >nul 2>&1
    echo  Hent manuelt: %MODEL_URL%
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
echo  Hent manuelt: %PY_URL%
echo  Gem som: %DEPS%\python.zip og koor start.bat igen.
echo.
pause
exit /b 1

:start_server
echo  ================================================
echo   ChatRedAI starter med DeepSeek AI...
echo   Abn din browser pa: http://localhost:5000
echo   (Foerste svar kan tage op til 1 minut)
echo   Luk dette vindue for at stoppe.
echo  ================================================
echo.

start /b cmd /c "timeout /t 3 /nobreak >nul && start \"\" \"http://localhost:5000\""
"%PY%" "%ROOT%\backend\app.py"

if errorlevel 1 (
    echo.
    echo  Serveren stoppede med en fejl.
    pause
)
