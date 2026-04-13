@echo off
setlocal disabledelayedexpansion
title Albedo Upgrade

powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Albedo Upgrade`n`nThis will:`n  - Download new Gemma 4B model (~6GB)`n  - Install llama-swap (smart model switcher)`n  - Install Open WebUI (skills, artifacts, web search)`n`nYour existing models will NOT be deleted.`nMake sure no AI is currently running.', 'Albedo Upgrade', 'OK', 'Information')" >nul 2>&1

:: Pick install folder
for /f "delims=" %%i in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Select your Albedo install folder (the one containing models and bin folders)'; $f.RootFolder = [System.Environment+SpecialFolder]::MyComputer; if ($f.ShowDialog() -eq ''OK'') { Write-Output $f.SelectedPath } else { Write-Output ''CANCELLED'' }"') do set ALBEDO_DIR=%%i

if "%ALBEDO_DIR%"=="CANCELLED" (
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Upgrade cancelled.', 'Albedo Upgrade', 'OK', 'Warning')" >nul 2>&1
    exit /b 0
)

set MODELS_DIR=%ALBEDO_DIR%\models
set BIN_DIR=%ALBEDO_DIR%\bin
set DESKTOP=%USERPROFILE%\Desktop\START AI - Albedo

:: ============================================================
::  UPDATE BIN FROM REPO
:: ============================================================
echo Updating bin files...
if exist "%ALBEDO_DIR%\repo" rmdir /s /q "%ALBEDO_DIR%\repo"

git clone https://github.com/TechnoClasher/Turboquant-LLAMA-Windows "%ALBEDO_DIR%\repo" --depth 1 --quiet
if errorlevel 1 (
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Failed to fetch update. Check your internet connection and try again.', 'Albedo Upgrade', 'OK', 'Error')" >nul 2>&1
    exit /b 1
)

xcopy /E /I /Y "%ALBEDO_DIR%\repo\bin\*" "%BIN_DIR%\" >nul

:: ============================================================
::  DOWNLOAD NEW MODEL - Gemma 4E4B
:: ============================================================
if not exist "%MODELS_DIR%\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf" (
    echo Downloading Gemma 4E4B model (~6GB^)...
    python -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='HauhauCS/Gemma-4-E4B-Uncensored-HauhauCS-Aggressive', filename='Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf', local_dir='%MODELS_DIR%')"
) else (
    echo Gemma model already exists, skipping...
)

:: ============================================================
::  INSTALL LLAMA-SWAP
:: ============================================================
echo Installing llama-swap...
winget install --id mostlygeek.llama-swap -e --source winget --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
if errorlevel 1 (
    :: Try direct download if winget fails
    echo Winget failed, downloading llama-swap directly...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/mostlygeek/llama-swap/releases/latest/download/llama-swap-windows-amd64.zip' -OutFile '%ALBEDO_DIR%\llama-swap.zip'" >nul 2>&1
    powershell -Command "Expand-Archive -Path '%ALBEDO_DIR%\llama-swap.zip' -DestinationPath '%BIN_DIR%' -Force" >nul 2>&1
    del "%ALBEDO_DIR%\llama-swap.zip" >nul 2>&1
)

:: ============================================================
::  INSTALL OPEN WEBUI
:: ============================================================
echo Installing Open WebUI (this may take a few minutes^)...
python -m pip install open-webui --quiet

:: ============================================================
::  WRITE LLAMA-SWAP CONFIG
:: ============================================================
echo Writing llama-swap config...
(
echo models:
echo   coding:
echo     cmd: "%BIN_DIR%\llama-server.exe" --port ${PORT} -m "%MODELS_DIR%\OmniCoder-Claude-uncensored-V2-Q4_K_M.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 -np 1
echo     aliases: ["OmniCoder", "coder"]
echo   general:
echo     cmd: "%BIN_DIR%\llama-server.exe" --port ${PORT} -m "%MODELS_DIR%\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -c 32768 -np 1
echo     aliases: ["Gemma", "gemma4"]
echo   balanced:
echo     cmd: "%BIN_DIR%\llama-server.exe" --port ${PORT} -m "%MODELS_DIR%\Qwen_Qwen3.5-9B-Q6_K.gguf" -ngl 99 --reasoning off -fa 1 -ctk q8_0 -ctv turbo4 -c 32768 -np 1
echo     aliases: ["Qwen", "qwen9b"]
) > "%ALBEDO_DIR%\config.yaml"

:: ============================================================
::  REWRITE DESKTOP SHORTCUTS
:: ============================================================
if not exist "%DESKTOP%" mkdir "%DESKTOP%"

:: Main launcher - starts llama-swap + open-webui
(
echo @echo off
echo title Albedo AI
echo echo Starting Albedo...
echo echo.
echo echo Available models:
echo echo   coding   - OmniCoder 9B ^(best for code^)
echo echo   general  - Gemma 4E4B ^(fast general purpose^)
echo echo   balanced - Qwen 9B ^(balanced quality^)
echo echo.
echo echo Open WebUI will open in your browser automatically.
echo echo To switch models, use the model selector in the chat.
echo echo.
echo start "llama-swap" llama-swap --config "%ALBEDO_DIR%\config.yaml" --listen 127.0.0.1:8080
echo timeout /t 3 /nobreak ^>nul
echo start "Open WebUI" python -m uvicorn open_webui.main:app --host 127.0.0.1 --port 3000
echo timeout /t 5 /nobreak ^>nul
echo start http://127.0.0.1:3000
echo echo.
echo echo Albedo is running. Close this window to shut everything down.
echo pause ^>nul
echo taskkill /f /im llama-swap.exe ^>nul 2^>^&1
echo taskkill /f /im python.exe ^>nul 2^>^&1
) > "%DESKTOP%\Start Albedo.bat"

(
echo @echo off
echo start http://127.0.0.1:3000
) > "%DESKTOP%\Open Chat.bat"

:: Remove old single-model bats if they exist
del "%DESKTOP%\For Coding - Albedo.bat" >nul 2>&1
del "%DESKTOP%\For Uncensored General - Albedo.bat" >nul 2>&1
del "%DESKTOP%\For Balanced General - Albedo.bat" >nul 2>&1

:: ============================================================
::  DONE
:: ============================================================
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Albedo upgrade complete!`n`nHow to use:`n  1. Double-click Start Albedo on your Desktop`n  2. Wait ~15 seconds for everything to load`n  3. Open Chat will launch automatically`n`nIn the chat, switch models using the selector at the top:`n  - coding  ^= OmniCoder 9B`n  - general ^= Gemma 4E4B`n  - balanced ^= Qwen 9B`n`nSkills, artifacts and web search are available in Open WebUI settings.', 'Albedo Upgrade Complete', 'OK', 'Information')" >nul 2>&1

endlocal
