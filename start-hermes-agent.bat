@echo off
setlocal enabledelayedexpansion
title Albedo - Hermes Agent Mode

:: ============================================================
::  Albedo Hermes Agent - Agentic mode via WSL2
::  Connects to local llama-server at 127.0.0.1:8080
:: ============================================================

:: Check if WSL2 is installed
wsl --status >nul 2>&1
if errorlevel 1 (
    echo WSL2 is not installed.
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $r = [System.Windows.Forms.MessageBox]::Show('WSL2 is required for Hermes Agent mode.`n`nClick OK to install it now. Your PC will need to restart afterwards, then run this bat again.', 'Albedo - WSL2 Required', 'OKCancel', 'Warning'); Write-Output $r" >nul 2>&1
    echo Installing WSL2...
    wsl --install
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('WSL2 installed. Please restart your PC, then run this bat file again to continue.', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1
    exit /b 0
)

:: Check if Hermes is installed in WSL
wsl -e bash -c "command -v hermes" >nul 2>&1
if errorlevel 1 (
    echo Hermes Agent not found. Installing...
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Installing Hermes Agent (first time only, takes a minute)...', 'Albedo Setup', 'OK', 'Information')" >nul 2>&1
    wsl -e bash -c "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
    if errorlevel 1 (
        powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Failed to install Hermes Agent. Check your internet connection and try again.', 'Albedo Setup', 'OK', 'Error')" >nul 2>&1
        exit /b 1
    )
)

:: Write hermes config pointing to local llama-server
:: From WSL2, Windows localhost is accessible via 127.0.0.1 (mirrored networking) or host.docker.internal
wsl -e bash -c "mkdir -p ~/.hermes && cat > ~/.hermes/cli-config.yaml << 'EOF'
model: local/albedo
provider: llamacpp
base_url: http://127.0.0.1:8080/v1
api_key: none
context_length: 32768
EOF"

:: Make sure llama-server is running, warn if not
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8080/health' -TimeoutSec 2; } catch { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Warning: No AI model appears to be running at port 8080.`n`nPlease start one of the AI modes first (For Coding, For Balanced, etc.) then run Hermes Agent.', 'Albedo - Model Not Running', 'OK', 'Warning') }" >nul 2>&1

echo.
echo ============================================================
echo  Albedo Hermes Agent
echo  Connected to local AI at http://127.0.0.1:8080
echo  Type your message and press Enter. Type 'exit' to quit.
echo ============================================================
echo.

:: Launch hermes in WSL
wsl -e bash -c "source ~/.bashrc 2>/dev/null; hermes"

endlocal
