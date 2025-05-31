param(
    [string]$InstallDir = "$env:USERPROFILE\.koboldcpp",
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

$KOBOLDCPP_VERSION = "latest"
$GITHUB_REPO = "LostRuins/koboldcpp"
$DEFAULT_PORT = 5001
$DEFAULT_MODEL = "llama3:8b"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Info($message) { Write-ColorOutput Green "INFO: $message" }
function Write-Warning($message) { Write-ColorOutput Yellow "WARNING: $message" }
function Write-Error($message) { Write-ColorOutput Red "ERROR: $message" }

# Banner
Write-Host @"
======================================================
                 KoboldCpp Installer                       
             OpenWebUI Compatible AI Backend                
======================================================
"@ -ForegroundColor Cyan

Write-Info "Starting KoboldCpp installation..."
Write-Info "Install directory: $InstallDir"

function Initialize-Directories {
    Write-Info "Creating directory structure..."
    
    $dirs = @(
        $InstallDir,
        "$InstallDir\bin",
        "$InstallDir\models",
        "$InstallDir\config",
        "$InstallDir\logs",
        "$InstallDir\scripts"
    )
    
    foreach ($dir in $dirs) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Info "Created: $dir"
        }
    }
}

function Get-UserHardwareChoice {
    Write-Host "`nSelect your hardware configuration:" -ForegroundColor Yellow
    Write-Host "1. CPU only (standard)" -ForegroundColor Cyan
    Write-Host "2. NVIDIA GPU (CUDA)" -ForegroundColor Cyan
    Write-Host ""
    
    $valid_choices = @('1', '2', '3', '4')
    $choice = $null
    
    while ($choice -notin $valid_choices) {
        $choice = Read-Host "Enter your choice (1-4)"
        if ($choice -notin $valid_choices) {
            Write-Warning "Invalid choice. Please enter 1, 2, 3, or 4."
        }
    }
    
    $hardware_info = @{
        backend = ""
        display_name = ""
        binary_suffix = ""
        gpu_flag = ""
    }
    
    switch ($choice) {
        '1' {
            $hardware_info.backend = "cpu"
            $hardware_info.display_name = "CPU only"
            $hardware_info.binary_suffix = ""
            $hardware_info.gpu_flag = ""
        }
        '2' {
            $hardware_info.backend = "cuda"
            $hardware_info.display_name = "NVIDIA GPU (CUDA)"
            $hardware_info.binary_suffix = "_cu12"
            $hardware_info.gpu_flag = "--usecublas"
        }
        '3' {
            $hardware_info.backend = "vulkan"
            $hardware_info.display_name = "AMD/Intel GPU (Vulkan)"
            $hardware_info.binary_suffix = ""
            $hardware_info.gpu_flag = "--usevulkan"
        }
        '4' {
            $hardware_info.backend = "clblast"
            $hardware_info.display_name = "AMD GPU (CLBlast)"
            $hardware_info.binary_suffix = ""
            $hardware_info.gpu_flag = "--useclblast"
        }
    }
    
    Write-Info "Selected: $($hardware_info.display_name)"
    return $hardware_info
}

function Get-KoboldCppBinary() {
    Write-Info "Downloading KoboldCpp binary..."
    
    $binary_name = "koboldcpp_cu12.exe"
    $download_url = "https://github.com/LostRuins/koboldcpp/releases/latest/download/$binary_name"
    $binary_path = "$InstallDir\bin\koboldcpp.exe"
    
    Write-Info "Downloading from: $download_url"
    Write-Info "Installing to: $binary_path"
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($download_url, $binary_path)
        Write-Info "Binary downloaded successfully"
    } catch {
        Write-Error "Failed to download binary: $($_.Exception.Message)"
        Write-Info "You may need to manually download from: https://github.com/LostRuins/koboldcpp/releases/latest/download/"
        throw
    }
    
    try {
        $version_output = & $binary_path --version 2>&1
        Write-Info "KoboldCpp version: $version_output"
    } catch {
        Write-Warning "Binary verification failed, but continuing..."
    }
}



function Install-Open-WebUI() {
   
    Write-Host "`nInstall Open-WebUI?" -ForegroundColor Yellow
    Write-Host "1. Yes" -ForegroundColor Cyan
    Write-Host "2. No" -ForegroundColor Cyan
    Write-Host ""
    
    $valid_choices = @('1', '2')
    $choice = $null
    while ($choice -notin $valid_choices) {
        $choice = Read-Host "Enter your choice (1, 2)"
        if ($choice -notin $valid_choices) {
            Write-Warning "Invalid choice. Please enter 1 or 2."
        }
    }
    
    
    switch ($choice) {
        '1' {
			start-process -WorkingDirectory "$InstallDir\scripts" "install-open-webui.bat"
        }
        '2' {
            Write-Info "Skipping Open-WebUI install..."
        }
    }
}
function Open-Kobold(){
    Clear-Host
    Write-Host "================ KoboldCpp Setup ================" -ForegroundColor Yellow
	Write-Host ""
	Write-Host "The KoboldCpp Launcher is going to start." -ForegroundColor Cyan
	Write-Host "1. Click on the Model Search button and find a model to load as your default" -ForegroundColor Cyan
	Write-Host "2. Configure any addition settings like Context Size" -ForegroundColor Cyan
	Write-Host "3. Save the configuration, named default.kcpps in User\.koboldcpp\config" -ForegroundColor Cyan
    Write-Host ""
	Write-Host "                  Press Enter when ready!" -ForegroundColor Cyan
    Read-Host "Press Enter"
	Start-Process "$InstallDir\bin\koboldcpp.exe"
}

function New-HelperScripts() {
    Write-Info "Creating helper scripts..."
    
    $open_webui_install_script = @"
@echo off
setlocal enabledelayedexpansion

set "VENV_NAME=nobold_env"

set "PYTHON_PATH=python"

%PYTHON_PATH% --version >nul 2>&1
if errorlevel 1 (
    echo Python is not found. Please ensure Python is installed and added to your PATH.
    pause
    exit /b 1
)


if not exist "%VENV_NAME%\Scripts\activate.bat" (
    echo Creating new virtual environment: %VENV_NAME%
    %PYTHON_PATH% -m venv %VENV_NAME%
    if errorlevel 1 (
        echo Failed to create virtual environment. Please check your Python installation.
        pause
        exit /b 1
    )
) else (
    echo Virtual environment %VENV_NAME% already exists.
)

call "%VENV_NAME%\Scripts\activate.bat"

python -m pip install --upgrade pip

pip install open-webui
if errorlevel 1 (
    echo Failed to install some packages. Please check your internet connection and requirements.txt file.
    pause
    exit /b 1
)

deactivate
exit /b 1
"@
	$open_webui_install_script | Set-Content "$InstallDir\scripts\install-open-webui.bat"
    $open_webui_start_script = @"
@echo off
setlocal enabledelayedexpansion
set "OPENAI_API_BASE_URL=http://localhost:5001/v1"
set "ENABLE_OPENAI_API=True"
set "VENV_NAME=nobold_env"

set "PYTHON_PATH=python"

%PYTHON_PATH% --version >nul 2>&1
if errorlevel 1 (
    echo Python is not found. Please ensure Python is installed and added to your PATH.
    pause
    exit /b 1
)


if not exist "%VENV_NAME%\Scripts\activate.bat" (
    echo Creating new virtual environment: %VENV_NAME%
    %PYTHON_PATH% -m venv %VENV_NAME%
    if errorlevel 1 (
        echo Failed to create virtual environment. Please check your Python installation.
        pause
        exit /b 1
    )
) else (
    echo Virtual environment %VENV_NAME% already exists.
)

call "%VENV_NAME%\Scripts\activate.bat"

open-webui serve

"@
	$open_webui_start_script | Set-Content "$InstallDir\scripts\open-webui-start.bat"
	
	$start_script = @"
@echo off
echo Starting KoboldCpp...
cd /d "$InstallDir"
.\bin\koboldcpp.exe --config default.kcpps
"@
    $start_script | Set-Content "$InstallDir\scripts\start.bat"

    
    $stop_script = @"
@echo off
echo Stopping KoboldCpp...
taskkill /f /im koboldcpp.exe 2>nul
echo KoboldCpp stopped.
"@
    $stop_script | Set-Content "$InstallDir\scripts\stop.bat"
    
    $download_model_script = @"
@echo off
setlocal enabledelayedexpansion
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& "./manage-models.ps1 browse
"@
    $download_model_script | Set-Content "$InstallDir\scripts\download-model.bat"
    
    Write-Info "Helper scripts created in: $InstallDir\scripts\"
}

function Add-ToPath {
    Write-Info "Adding KoboldCpp to PATH..."
    
    $current_path = [Environment]::GetEnvironmentVariable("PATH", "User")
    $koboldcpp_path = "$InstallDir\bin"
    
    if ($current_path -notlike "*$koboldcpp_path*") {
        $new_path = "$current_path;$koboldcpp_path"
        [Environment]::SetEnvironmentVariable("PATH", $new_path, "User")
        Write-Info "Added to PATH: $koboldcpp_path"
        Write-Warning "Please restart your terminal to use 'koboldcpp' command"
    } else {
        Write-Info "Already in PATH"
    }
}

function Show-Instructions($config, $hardware_info) {
    

    Clear-Host
    Write-Host "================ Install Complete ================" -ForegroundColor Cyan
	Write-Host @"
KoboldCpp has been installed to: $InstallDir
Hardware configuration: $($hardware_info.display_name)

QUICK START:
1. Download a model:
   $InstallDir\scripts\download-model.bat

2. Start KoboldCpp with a model:
   $InstallDir\scripts\start-with-model.bat models\<model-file>.gguf

3. Or start without a model (you can load one through the web UI):
   $InstallDir\scripts\start.bat

4. Test the OpenAI-compatible API:
   curl http://localhost:$($config.port)/v1/models

5. Setup OpenWebUI:
   docker run -d -p 3000:8080 \
     -e OPENAI_API_BASE_URL=http://localhost:$($config.port)/v1 \
     -v open-webui:/app/backend/data \
     --name open-webui \
     ghcr.io/open-webui/open-webui:main

ENDPOINTS:
- KoboldCpp Web UI: http://localhost:$($config.port)
- OpenAI-compatible API: http://localhost:$($config.port)/v1
- Native KoboldCpp API: http://localhost:$($config.port)/api

ACCESS:
- KoboldCpp Interface: http://localhost:$($config.port)
- OpenWebUI: http://localhost:3000 (after setup)

NEXT STEPS:
- GPU users: Adjust --gpulayers parameter in start scripts if needed
- Download models from the registry or Hugging Face
- Configure advanced settings through the web interface

SUPPORT:
- Documentation: https://github.com/LostRuins/koboldcpp
- Issues: https://github.com/LostRuins/koboldcpp/issues
- KoboldAI Discord: https://koboldai.org/discord

"@ -ForegroundColor Green
}

try {
    Initialize-Directories
    #$hardware_info = Get-UserHardwareChoice
    Get-KoboldCppBinary
	Open-Kobold
    #$config = New-Configuration $hardware_info
    New-HelperScripts
	Install-Open-WebUI
	Copy-Item -Path ./manage-models.ps1 "$InstallDir\scripts\"
	#Start-Process -wait "$InstallDir\scripts\download-model.bat"
	Add-ToPath
    #Show-Instructions
    
    Write-Info "Installation completed successfully!"
} catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    Write-Error "Please check the error above and try again."
    exit 1
}