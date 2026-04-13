@echo off
setlocal enabledelayedexpansion
title Albedo Setup

:: ============================================================
::  ALBEDO - AI Setup Installer
:: ============================================================

:: Welcome dialog
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Welcome to Albedo AI setup!`n`nThis installer will:`n  - Download required tools (Python, Git if missing)`n  - Download AI models (~20GB total)`n  - Set up your AI assistant`n`nMake sure you have a stable internet connection before continuing.', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1

:: Folder picker
for /f "delims=" %%i in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Choose where to install Albedo AI (needs ~25GB free space)'; $f.RootFolder = [System.Environment+SpecialFolder]::MyComputer; if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath } else { Write-Output 'CANCELLED' }"') do set INSTALL_DIR=%%i

if "%INSTALL_DIR%"=="CANCELLED" (
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Setup cancelled.', 'Albedo Setup', 'OK', 'Warning')" >nul 2>&1
    exit /b 0
)

set ALBEDO_DIR=%INSTALL_DIR%\Albedo
set MODELS_DIR=%ALBEDO_DIR%\models
set BIN_DIR=%ALBEDO_DIR%\bin

powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Installing to: %ALBEDO_DIR%`n`nSetup will now begin. This may take a while depending on your internet speed.`nDo NOT close any windows that appear.', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1

:: Create directories
mkdir "%ALBEDO_DIR%" 2>nul
mkdir "%MODELS_DIR%" 2>nul
mkdir "%BIN_DIR%" 2>nul

echo [Albedo] Starting setup... > "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CHECK / INSTALL GIT
:: ============================================================
echo Checking for Git...
git --version >nul 2>&1
if errorlevel 1 (
    echo Git not found. Installing...
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Git is not installed. Installing Git now...', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1
    winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Failed to install Git. Please install it manually from https://git-scm.com and re-run setup.', 'Albedo Setup', 'OK', 'Error')" >nul 2>&1
        exit /b 1
    )
    :: Refresh PATH
    call refreshenv 2>nul
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
)
echo Git OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CHECK / INSTALL PYTHON
:: ============================================================
echo Checking for Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo Python not found. Installing...
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Python is not installed. Installing Python now...', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1
    winget install --id Python.Python.3.12 -e --source winget --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Failed to install Python. Please install it manually from https://python.org and re-run setup.', 'Albedo Setup', 'OK', 'Error')" >nul 2>&1
        exit /b 1
    )
    set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts"
)
echo Python OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  INSTALL HUGGINGFACE HUB
:: ============================================================
echo Installing huggingface_hub...
python -m pip install huggingface_hub --quiet
echo huggingface_hub OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CLONE REPO (gets bin + configs)
:: ============================================================
echo Cloning Albedo repo...
git clone https://github.com/TechnoClasher/Turboquant-LLAMA-Windows "%ALBEDO_DIR%\repo" --depth 1 --quiet
if errorlevel 1 (
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Failed to clone repo. Check your internet connection and try again.', 'Albedo Setup', 'OK', 'Error')" >nul 2>&1
    exit /b 1
)

:: Copy bin files from repo
xcopy /E /I /Y "%ALBEDO_DIR%\repo\bin\*" "%BIN_DIR%\" >nul

echo Repo cloned OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  DOWNLOAD MODELS
:: ============================================================
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Now downloading AI models (~20GB total).`n`nThis will take a while. You can minimize this window.`nSetup will notify you when it''s done.', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1

echo Downloading model 1/3: Coding (OmniCoder 9B)...
python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='Ngixdev/OmniCoder-Qwen3.5-9B-Claude-4.6-Opus-Uncensored-v2-GGUF', filename='OmniCoder-Claude-uncensored-V2-Q4_K_M.gguf', local_dir='%MODELS_DIR%')"
echo Model 1 OK >> "%ALBEDO_DIR%\install.log"

echo Downloading model 2/3: Uncensored General (Qwen3.5 4B)...
python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='Ngixdev/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive', filename='Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-Q8_0.gguf', local_dir='%MODELS_DIR%')"
echo Model 2 OK >> "%ALBEDO_DIR%\install.log"

echo Downloading model 3/3: Balanced General (Qwen3.5 9B)...
python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='bartowski/Qwen_Qwen3.5-9B-GGUF', filename='Qwen_Qwen3.5-9B-Q6_K.gguf', local_dir='%MODELS_DIR%')"
echo Model 3 OK >> "%ALBEDO_DIR%\install.log"

:: ============================================================
::  CREATE START AI FOLDER ON DESKTOP
:: ============================================================
set DESKTOP=%USERPROFILE%\Desktop\START AI - Albedo
mkdir "%DESKTOP%" 2>nul

:: Write the three launch bats
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
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Albedo is ready!`n`nFind the START AI - Albedo folder on your Desktop.`n`nHow to use:`n  1. Double-click one of the bat files to start the AI`n  2. Wait ~10 seconds for it to load`n  3. Double-click Open Chat to use it in your browser`n`nEnjoy!', 'Albedo Setup Complete', 'OK', 'Information')" >nul 2>&1

endlocal
