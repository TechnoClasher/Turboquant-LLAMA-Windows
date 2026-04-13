@echo off
setlocal enabledelayedexpansion
title Albedo Update

powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Albedo Updater`n`nThis will update your AI engine files (bin folder).`nYour models will NOT be touched.`n`nMake sure no AI is currently running before continuing.', 'Albedo Update', 'OK', 'Information')" >nul 2>&1

:: Find existing install
for /f "delims=" %%i in ('powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Select your Albedo install folder (the one containing the models and bin folders)'; $f.RootFolder = [System.Environment+SpecialFolder]::MyComputer; if ($f.ShowDialog() -eq ''OK'') { Write-Output $f.SelectedPath } else { Write-Output ''CANCELLED'' }"') do set ALBEDO_DIR=%%i

if "%ALBEDO_DIR%"=="CANCELLED" (
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Update cancelled.', 'Albedo Update', 'OK', 'Warning')" >nul 2>&1
    exit /b 0
)

set BIN_DIR=%ALBEDO_DIR%\bin

:: Delete old bin
echo Removing old bin folder...
rmdir /s /q "%BIN_DIR%" 2>nul
mkdir "%BIN_DIR%"

:: Pull latest repo
echo Fetching latest files...
if exist "%ALBEDO_DIR%\repo" (
    rmdir /s /q "%ALBEDO_DIR%\repo"
)
git clone https://github.com/TechnoClasher/Turboquant-LLAMA-Windows "%ALBEDO_DIR%\repo" --depth 1 --quiet
if errorlevel 1 (
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Failed to download update. Check your internet connection and try again.', 'Albedo Update', 'OK', 'Error')" >nul 2>&1
    exit /b 1
)

:: Copy new bin
xcopy /E /I /Y "%ALBEDO_DIR%\repo\bin\*" "%BIN_DIR%\" >nul


powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Update complete!`n`nYour AI engine has been updated. Your models are untouched.`nYou can now start Albedo as usual.', 'Albedo Update', 'OK', 'Information')" >nul 2>&1

endlocal
