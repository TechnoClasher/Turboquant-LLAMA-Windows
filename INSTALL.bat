@echo off
setlocal disabledelayedexpansion
title Albedo Setup

:: ============================================================
::  ALBEDO - AI Setup Installer
:: ============================================================

powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Welcome to Albedo AI setup!`n`nThis installer will:`n  - Download required tools (Python, Git if missing)`n  - Download AI models (~20GB total)`n  - Set up your AI assistant`n`nMake sure you have a stable internet connection before continuing.', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1

:: Folder picker
for /f "delims=" %%i in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Choose where to install Albedo AI (needs ~25GB free space)'; $f.RootFolder = [System.Environment+SpecialFolder]::MyComputer; if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath } else { Write-Output 'CANCELLED' }"') do set INSTALL_DIR=%%i

if "%INSTALL_DIR%"=="CANCELLED" (
    echo Setup cancelled.
    pause
    exit /b 0
)

set ALBEDO_DIR=%INSTALL_DIR%\Albedo
set MODELS_DIR=%ALBEDO_DIR%\models
set BIN_DIR=%ALBEDO_DIR%\bin

echo Installing to: %ALBEDO_DIR%
echo.

:: Create directories
mkdir "%ALBEDO_DIR%" 2>nul
mkdir "%MODELS_DIR%" 2>nul
mkdir "%BIN_DIR%" 2>nul

echo [Albedo] Starting setup... > "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CHECK / INSTALL GIT
:: ============================================================
echo [1/6] Checking for Git...
git --version >nul 2>&1
if errorlevel 1 (
    echo Git not found. Installing via winget...
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install Git.
        echo Please install Git manually from https://git-scm.com then re-run setup.
        pause
        exit /b 1
    )
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
    echo Git installed. You may need to restart setup if the next step fails.
) else (
    echo Git found.
)
echo Git OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CHECK / INSTALL PYTHON
:: ============================================================
echo [2/6] Checking for Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo Python not found. Installing via winget...
    winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install Python.
        echo Please install Python manually from https://python.org then re-run setup.
        pause
        exit /b 1
    )
    set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts"
    echo Python installed.
) else (
    echo Python found.
)
echo Python OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  INSTALL HUGGINGFACE HUB
:: ============================================================
echo [3/6] Installing huggingface_hub...
python -m pip install huggingface_hub
if errorlevel 1 (
    echo.
    echo ERROR: Failed to install huggingface_hub.
    pause
    exit /b 1
)
echo huggingface_hub OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CLONE REPO (gets bin + configs)
:: ============================================================
echo [4/6] Downloading Albedo files from GitHub...
git clone https://github.com/TechnoClasher/Turboquant-LLAMA-Windows "%ALBEDO_DIR%\repo" --depth 1
if errorlevel 1 (
    echo.
    echo ERROR: Failed to clone repo.
    echo Check your internet connection and try again.
    pause
    exit /b 1
)

xcopy /E /I /Y "%ALBEDO_DIR%\repo\bin\*" "%BIN_DIR%\" >nul
echo Repo cloned OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  DOWNLOAD MODELS (skip if already present)
:: ============================================================
echo [5/6] Downloading AI models (this will take a while)...
echo You can minimize this window. Do NOT close it.
echo.

if not exist "%MODELS_DIR%\OmniCoder-Claude-uncensored-V2-Q4_K_M.gguf" (
    echo Downloading model 1/3: Coding - OmniCoder 9B...
    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='Ngixdev/OmniCoder-Qwen3.5-9B-Claude-4.6-Opus-Uncensored-v2-GGUF', filename='OmniCoder-Claude-uncensored-V2-Q4_K_M.gguf', local_dir='%MODELS_DIR%')"
    if errorlevel 1 ( echo ERROR: Model 1 download failed. & pause & exit /b 1 )
) else (
    echo Model 1/3 already exists, skipping...
)
echo Model 1 OK >> "%ALBEDO_DIR%\install.log"

if not exist "%MODELS_DIR%\Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-Q8_0.gguf" (
    echo Downloading model 2/3: General - Qwen 4B...
    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='Ngixdev/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive', filename='Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-Q8_0.gguf', local_dir='%MODELS_DIR%')"
    if errorlevel 1 ( echo ERROR: Model 2 download failed. & pause & exit /b 1 )
) else (
    echo Model 2/3 already exists, skipping...
)
echo Model 2 OK >> "%ALBEDO_DIR%\install.log"

if not exist "%MODELS_DIR%\Qwen_Qwen3.5-9B-Q6_K.gguf" (
    echo Downloading model 3/3: Balanced - Qwen 9B...
    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='bartowski/Qwen_Qwen3.5-9B-GGUF', filename='Qwen_Qwen3.5-9B-Q6_K.gguf', local_dir='%MODELS_DIR%')"
    if errorlevel 1 ( echo ERROR: Model 3 download failed. & pause & exit /b 1 )
) else (
    echo Model 3/3 already exists, skipping...
)
echo Model 3 OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CREATE START AI FOLDER ON DESKTOP
:: ============================================================
echo [6/6] Creating desktop shortcuts...
set DESKTOP=%USERPROFILE%\Desktop\START AI - Albedo
mkdir "%DESKTOP%" 2>nul

(
echo @echo off
echo title Albedo - Coding Assistant
echo echo Starting Albedo Coding Assistant...
echo echo Open http://127.0.0.1:8080 in your browser once loaded.
echo echo.
echo "%BIN_DIR%\llama-server.exe" -m "%MODELS_DIR%\OmniCoder-Claude-uncensored-V2-Q4_K_M.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 --host 127.0.0.1 --port 8080 -np 1
echo pause
) > "%DESKTOP%\For Coding - Albedo.bat"

(
echo @echo off
echo title Albedo - Uncensored General
echo echo Starting Albedo Uncensored...
echo echo Open http://127.0.0.1:8080 in your browser once loaded.
echo echo.
echo "%BIN_DIR%\llama-server.exe" -m "%MODELS_DIR%\Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-Q8_0.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 --host 127.0.0.1 --port 8080 -np 1
echo pause
) > "%DESKTOP%\For Uncensored General - Albedo.bat"

(
echo @echo off
echo title Albedo - Balanced General
echo echo Starting Albedo Balanced...
echo echo Open http://127.0.0.1:8080 in your browser once loaded.
echo echo.
echo "%BIN_DIR%\llama-server.exe" -m "%MODELS_DIR%\Qwen_Qwen3.5-9B-Q6_K.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 --host 127.0.0.1 --port 8080 -np 1
echo pause
) > "%DESKTOP%\For Balanced General - Albedo.bat"

(
echo @echo off
echo start http://127.0.0.1:8080
) > "%DESKTOP%\Open Chat.bat"

echo Desktop shortcuts created OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  DONE
:: ============================================================
echo.
echo ============================================================
echo  Albedo setup complete!
echo  Find the START AI - Albedo folder on your Desktop.
echo ============================================================
echo.
pause
endlocal
