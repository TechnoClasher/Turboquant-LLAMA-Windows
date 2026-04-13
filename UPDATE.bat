@echo off
setlocal disabledelayedexpansion
title Albedo Upgrade

powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Albedo Upgrade`n`nThis will:`n  - Download new Gemma 4B model (~6GB)`n  - Install Docker (if missing)`n  - Set up Vane AI search interface`n  - Update your desktop shortcuts`n`nYour existing models will NOT be deleted.`nMake sure no AI is currently running.', 'Albedo Upgrade', 'OK', 'Information')" >nul 2>&1

:: Pick install folder
for /f "delims=" %%i in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Select your Albedo install folder (the one containing models and bin folders)'; $f.RootFolder = [System.Environment+SpecialFolder]::MyComputer; if ($f.ShowDialog() -eq ''OK'') { Write-Output $f.SelectedPath } else { Write-Output ''CANCELLED'' }"') do set ALBEDO_DIR=%%i

if "%ALBEDO_DIR%"=="CANCELLED" (
    echo Upgrade cancelled.
    pause
    exit /b 0
)

set MODELS_DIR=%ALBEDO_DIR%\models
set BIN_DIR=%ALBEDO_DIR%\bin
set DESKTOP=%USERPROFILE%\Desktop\START AI - Albedo

echo Installing to: %ALBEDO_DIR%
echo.

:: ============================================================
::  UPDATE BIN FROM REPO
:: ============================================================
echo [1/5] Updating AI engine files...
if exist "%ALBEDO_DIR%\repo" rmdir /s /q "%ALBEDO_DIR%\repo"
git clone https://github.com/TechnoClasher/Turboquant-LLAMA-Windows "%ALBEDO_DIR%\repo" --depth 1
if errorlevel 1 (
    echo ERROR: Failed to fetch update from GitHub.
    echo Check your internet connection and try again.
    pause
    exit /b 1
)
xcopy /E /I /Y "%ALBEDO_DIR%\repo\bin\*" "%BIN_DIR%\" >nul
echo Engine updated.

:: ============================================================
::  DOWNLOAD NEW MODEL - Gemma 4E4B
:: ============================================================
echo [2/5] Checking models...
if not exist "%MODELS_DIR%\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf" (
    echo Downloading Gemma 4E4B model (~6GB^)...
    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive', filename='Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf', local_dir='%MODELS_DIR%')"
    if errorlevel 1 ( echo ERROR: Gemma model download failed. & pause & exit /b 1 )
) else (
    echo Gemma model already exists, skipping...
)

:: ============================================================
::  INSTALL DOCKER
:: ============================================================
echo [3/5] Checking for Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo Docker not found. Installing Docker Desktop...
    winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install Docker automatically.
        echo Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop
        echo Then re-run this updater.
        pause
        exit /b 1
    )
    echo.
    echo Docker Desktop installed.
    echo IMPORTANT: You need to restart your computer, then run this updater again to finish setup.
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Docker Desktop was just installed.`n`nYou MUST restart your computer and then run UPDATE.bat again to finish the setup.', 'Restart Required', 'OK', 'Warning')" >nul 2>&1
    pause
    exit /b 0
)
echo Docker found.

:: Make sure Docker engine is running
echo Starting Docker engine (if not already running^)...
powershell -Command "Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -ErrorAction SilentlyContinue" >nul 2>&1
:: Wait up to 30 seconds for Docker to be ready
set DOCKER_READY=0
for /l %%i in (1,1,15) do (
    docker info >nul 2>&1
    if not errorlevel 1 set DOCKER_READY=1
    if "!DOCKER_READY!"=="1" goto docker_ok
    echo Waiting for Docker... (%%i/15^)
    powershell -Command "Start-Sleep 2" >nul
)
:docker_ok
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker engine is not responding.
    echo Make sure Docker Desktop is running and try again.
    pause
    exit /b 1
)

:: ============================================================
::  PULL AND START VANE
:: ============================================================
echo [4/5] Setting up Vane...

:: Stop existing Vane container if running
docker stop albedo-vane >nul 2>&1
docker rm albedo-vane >nul 2>&1

:: Pull latest Vane image
echo Pulling Vane image...
docker pull itzcrazykns1337/vane:latest
if errorlevel 1 (
    echo ERROR: Failed to pull Vane image. Check your internet connection.
    pause
    exit /b 1
)

echo Vane ready.

:: ============================================================
::  REWRITE DESKTOP SHORTCUTS
:: ============================================================
echo [5/5] Updating desktop shortcuts...
if not exist "%DESKTOP%" mkdir "%DESKTOP%"

:: --- Coding model ---
(
echo @echo off
echo title Albedo - Coding Assistant
echo echo Starting Albedo Coding Assistant...
echo echo.
echo echo Starting AI model...
echo start "Albedo Model" "%BIN_DIR%\llama-server.exe" -m "%MODELS_DIR%\OmniCoder-Claude-uncensored-V2-Q4_K_M.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 --host 127.0.0.1 --port 8080 -np 1
echo echo Waiting for model to load...
echo powershell -Command "Start-Sleep 8"
echo echo Starting Vane interface...
echo docker run -d --rm -p 3000:3000 -v vane-data:/home/vane/data --add-host=host.docker.internal:host-gateway --name albedo-vane itzcrazykns1337/vane:latest >nul 2^>^&1
echo docker start albedo-vane >nul 2^>^&1
echo powershell -Command "Start-Sleep 5"
echo start http://127.0.0.1:3000
echo echo.
echo echo Albedo is running! Close this window to stop everything.
echo echo.
echo pause ^>nul
echo taskkill /f /fi "WINDOWTITLE eq Albedo Model" ^>nul 2^>^&1
echo docker stop albedo-vane ^>nul 2^>^&1
) > "%DESKTOP%\For Coding - Albedo.bat"

:: --- General model (Gemma) ---
(
echo @echo off
echo title Albedo - General Assistant
echo echo Starting Albedo General Assistant...
echo echo.
echo echo Starting AI model...
echo start "Albedo Model" "%BIN_DIR%\llama-server.exe" -m "%MODELS_DIR%\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -c 32768 --host 127.0.0.1 --port 8080 -np 1
echo echo Waiting for model to load...
echo powershell -Command "Start-Sleep 8"
echo echo Starting Vane interface...
echo docker run -d --rm -p 3000:3000 -v vane-data:/home/vane/data --add-host=host.docker.internal:host-gateway --name albedo-vane itzcrazykns1337/vane:latest >nul 2^>^&1
echo docker start albedo-vane >nul 2^>^&1
echo powershell -Command "Start-Sleep 5"
echo start http://127.0.0.1:3000
echo echo.
echo echo Albedo is running! Close this window to stop everything.
echo echo.
echo pause ^>nul
echo taskkill /f /fi "WINDOWTITLE eq Albedo Model" ^>nul 2^>^&1
echo docker stop albedo-vane ^>nul 2^>^&1
) > "%DESKTOP%\For General - Albedo.bat"

:: --- Balanced model ---
(
echo @echo off
echo title Albedo - Balanced Assistant
echo echo Starting Albedo Balanced Assistant...
echo echo.
echo echo Starting AI model...
echo start "Albedo Model" "%BIN_DIR%\llama-server.exe" -m "%MODELS_DIR%\Qwen_Qwen3.5-9B-Q6_K.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 --host 127.0.0.1 --port 8080 -np 1
echo echo Waiting for model to load...
echo powershell -Command "Start-Sleep 8"
echo echo Starting Vane interface...
echo docker run -d --rm -p 3000:3000 -v vane-data:/home/vane/data --add-host=host.docker.internal:host-gateway --name albedo-vane itzcrazykns1337/vane:latest >nul 2^>^&1
echo docker start albedo-vane >nul 2^>^&1
echo powershell -Command "Start-Sleep 5"
echo start http://127.0.0.1:3000
echo echo.
echo echo Albedo is running! Close this window to stop everything.
echo echo.
echo pause ^>nul
echo taskkill /f /fi "WINDOWTITLE eq Albedo Model" ^>nul 2^>^&1
echo docker stop albedo-vane ^>nul 2^>^&1
) > "%DESKTOP%\For Balanced - Albedo.bat"

:: Remove old shortcuts
del "%DESKTOP%\For Uncensored General - Albedo.bat" >nul 2>&1
del "%DESKTOP%\Start Albedo.bat" >nul 2>&1
del "%DESKTOP%\Open Chat.bat" >nul 2>&1

:: ============================================================
::  DONE
:: ============================================================
echo.
echo ============================================================
echo  Albedo upgrade complete!
echo.
echo  IMPORTANT - First time Vane setup:
echo  1. Run any model bat from your desktop
echo  2. When Vane opens in your browser, go to Settings
echo  3. Set API URL to: http://host.docker.internal:8080/v1
echo  4. You are ready to go!
echo ============================================================
echo.
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Albedo upgrade complete!`n`nIMPORTANT - First time Vane setup:`n  1. Run any model bat from your Desktop`n  2. When Vane opens, go to Settings`n  3. Set API URL to: http://host.docker.internal:8080/v1`n  4. Done!`n`nYou only need to do this once.', 'Albedo Upgrade Complete', 'OK', 'Information')" >nul 2>&1
pause
endlocal
