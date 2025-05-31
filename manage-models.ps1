# LLaMA Box Model Manager
# Usage: powershell -ExecutionPolicy Bypass -File manage-models.ps1 <command> [model-name]

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("pull", "list", "remove", "info", "search", "browse")]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$ModelName,
    
    [string]$InstallDir = "$env:USERPROFILE\.llamabox",
    [int]$SearchLimit = 10
)

$ErrorActionPreference = "Stop"

# Color output functions
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

# Load model registry
function Get-ModelRegistry {
    $registry_path = "$InstallDir\models\registry.json"
    if (!(Test-Path $registry_path)) {
        Write-Error "Model registry not found at: $registry_path"
        Write-Error "Please run the installer first."
        throw "Registry not found"
    }
    
    return Get-Content $registry_path | ConvertFrom-Json
}

# Download model from Hugging Face
function Get-Model($model_info, $model_name) {
    $models_dir = "$InstallDir\models\files"
    $model_path = "$models_dir\$($model_info.filename)"
    
    if (Test-Path $model_path) {
        Write-Warning "Model already exists: $model_path"
        return $model_path
    }
    
    Write-Info "Downloading model: $model_name"
    Write-Info "Repository: $($model_info.hf_repo)"
    Write-Info "File: $($model_info.filename)"
    Write-Info "Size: ~$($model_info.size_gb) GB"
    
    # Construct Hugging Face URL
    $hf_url = "https://huggingface.co/$($model_info.hf_repo)/resolve/main/$($model_info.filename)"
    
    Write-Info "Download URL: $hf_url"
    Write-Info "Destination: $model_path"
    Write-Warning "This may take a while depending on your internet connection..."
    
    # Ensure models directory exists
    if (!(Test-Path $models_dir)) {
        New-Item -ItemType Directory -Path $models_dir -Force | Out-Null
    }
    
    # Download with progress
    try {
        Write-Info "Starting download..."
        $webClient = New-Object System.Net.WebClient
        
        # Add progress tracking (simplified)
        $start_time = Get-Date
        $webClient.DownloadFile($hf_url, $model_path)
        $end_time = Get-Date
        $duration = $end_time - $start_time
        
        Write-Info "Download completed in $($duration.TotalMinutes.ToString('F1')) minutes"
        
        # Verify file size
        $file_info = Get-Item $model_path
        $size_mb = [math]::Round($file_info.Length / 1MB, 1)
        Write-Info "Downloaded file size: $size_mb MB"
        
        return $model_path
        
    } catch {
        Write-Error "Download failed: $($_.Exception.Message)"
        Write-Info "You can manually download from: $hf_url"
        
        # Clean up partial download
        if (Test-Path $model_path) {
            Remove-Item $model_path -Force
        }
        throw
    }
}

# List available and installed models
function Show-Models {
    $registry = Get-ModelRegistry
    $models_dir = "$InstallDir\models\files"
    
    Write-Host "`nAVAILABLE MODELS:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    foreach ($model_name in $registry.PSObject.Properties.Name) {
        $model_info = $registry.$model_name
        $model_path = "$models_dir\$($model_info.filename)"
        $installed = Test-Path $model_path
        $status = if ($installed) { "INSTALLED" } else { "AVAILABLE" }
        $status_color = if ($installed) { "Green" } else { "Yellow" }
        
        Write-Host "  $model_name" -NoNewline
        Write-Host " [$status]" -ForegroundColor $status_color
        Write-Host "    Repository: $($model_info.hf_repo)"
        Write-Host "    File: $($model_info.filename)"
        Write-Host "    Size: ~$($model_info.size_gb) GB"
        Write-Host "    Template: $($model_info.chat_template)"
        if ($installed) {
            $file_info = Get-Item $model_path
            $size_mb = [math]::Round($file_info.Length / 1MB, 1)
            Write-Host "    Local size: $size_mb MB" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    # Show total disk usage
    if (Test-Path $models_dir) {
        $total_size = (Get-ChildItem $models_dir -File | Measure-Object -Property Length -Sum).Sum
        $total_gb = [math]::Round($total_size / 1GB, 2)
        Write-Host "Total disk usage: $total_gb GB" -ForegroundColor Cyan
    }
}

# Show model information
function Show-ModelInfo($model_name) {
    $registry = Get-ModelRegistry
    
    if (!$registry.$model_name) {
        Write-Error "Unknown model: $model_name"
        Write-Info "Available models: $($registry.PSObject.Properties.Name -join ', ')"
        return
    }
    
    $model_info = $registry.$model_name
    $models_dir = "$InstallDir\models\files"
    $model_path = "$models_dir\$($model_info.filename)"
    $installed = Test-Path $model_path
    
    Write-Host "`nMODEL INFORMATION: $model_name" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Repository: $($model_info.hf_repo)"
    Write-Host "Filename: $($model_info.filename)"
    Write-Host "Expected size: ~$($model_info.size_gb) GB"
    Write-Host "Chat template: $($model_info.chat_template)"
    Write-Host "Status: $(if ($installed) { 'INSTALLED' } else { 'NOT INSTALLED' })" -ForegroundColor $(if ($installed) { 'Green' } else { 'Red' })
    
    if ($installed) {
        $file_info = Get-Item $model_path
        $size_mb = [math]::Round($file_info.Length / 1MB, 1)
        Write-Host "Local path: $model_path" -ForegroundColor Green
        Write-Host "Local size: $size_mb MB" -ForegroundColor Green
        Write-Host "Modified: $($file_info.LastWriteTime)" -ForegroundColor Green
    } else {
        Write-Host "Download URL: https://huggingface.co/$($model_info.hf_repo)/resolve/main/$($model_info.filename)"
    }
}

# Search Hugging Face for models
function Search-HuggingFaceModels($search_term) {
    Write-Info "Searching Hugging Face for: $search_term"
    
    # Primary search with GGUF prefix
    $search_gguf = "GGUF $search_term"
    $encoded_search = [System.Web.HttpUtility]::UrlEncode($search_gguf)
    $search_url = "https://huggingface.co/api/models?search=$encoded_search&limit=$SearchLimit"
    
    try {
        $response = Invoke-RestMethod -Uri $search_url -Method Get -TimeoutSec 10
        $models = @()
        
        foreach ($model in $response) {
            $models += $model.id
        }
        
        # If too few results, try without GGUF prefix
        if ($models.Count -le 3) {
            Write-Info "Expanding search without GGUF prefix..."
            $encoded_search2 = [System.Web.HttpUtility]::UrlEncode($search_term)
            $search_url2 = "https://huggingface.co/api/models?search=$encoded_search2&limit=6"
            
            $response2 = Invoke-RestMethod -Uri $search_url2 -Method Get -TimeoutSec 10
            foreach ($model in $response2) {
                if ($models -notcontains $model.id) {
                    $models += $model.id
                }
            }
        }
        
        if ($models.Count -eq 0) {
            Write-Warning "No models found for: $search_term"
            return @()
        }
        
        Write-Host "`nSEARCH RESULTS FOR '$search_term':" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $models.Count; $i++) {
            Write-Host "  [$($i+1)] $($models[$i])"
        }
        
        return $models
        
    } catch {
        Write-Error "Search failed: $($_.Exception.Message)"
        return @()
    }
}

# Browse model files and auto-select best quantization
function Get-ModelFiles($repo_id) {
    Write-Info "Fetching model files for: $repo_id"
    
    $api_url = "https://huggingface.co/api/models/$repo_id/tree/main?recursive=true"
    
    try {
        $response = Invoke-RestMethod -Uri $api_url -Method Get -TimeoutSec 15
        $gguf_files = @()
        
        foreach ($file in $response) {
            if ($file.type -eq "file" -and $file.path -like "*.gguf") {
                # Skip multi-part files except the first part
                if ($file.path -like "*-of-0*" -and $file.path -notlike "*00001*") {
                    continue
                }
                
                $gguf_files += @{
                    path = $file.path
                    size = $file.size
                    size_gb = [math]::Round($file.size / 1GB, 2)
                }
            }
        }
        
        if ($gguf_files.Count -eq 0) {
            Write-Warning "No GGUF files found in repository: $repo_id"
            return $null
        }
        
        # Auto-select best quantization (following the Python priority)
        $quant_priority = @("q4k", "q4_k", "q4", "q3", "q5", "q6", "q8")
        $selected_file = $gguf_files[0]  # fallback
        
        foreach ($quant in $quant_priority) {
            foreach ($file in $gguf_files) {
                if ($file.path.ToLower() -like "*$quant*") {
                    $selected_file = $file
                    Write-Info "Auto-selected quantization: $quant"
                    break
                }
            }
            if ($selected_file.path.ToLower() -like "*$quant*") {
                break
            }
        }
        
        Write-Host "`nAVAILABLE FILES IN $repo_id" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        
        for ($i = 0; $i -lt $gguf_files.Count; $i++) {
            $file = $gguf_files[$i]
            $marker = if ($file.path -eq $selected_file.path) { " [RECOMMENDED]" } else { "" }
            Write-Host "  [$($i+1)] $($file.path) ($($file.size_gb) GB)$marker" -ForegroundColor $(if ($marker) { "Green" } else { "White" })
        }
        
        return @{
            files = $gguf_files
            selected = $selected_file
            repo_id = $repo_id
        }
        
    } catch {
        Write-Error "Failed to fetch model files: $($_.Exception.Message)"
        return $null
    }
}

# Interactive model browsing
function Start-ModelBrowser($search_term) {
    if (!$search_term) {
        $search_term = Read-Host "Enter search term"
        if (!$search_term.Trim()) {
            Write-Warning "Search term required"
            return
        }
    }
    
    # Search for models
    $models = Search-HuggingFaceModels $search_term
    if ($models.Count -eq 0) {
        return
    }
    
    # Let user select model
    Write-Host "`nSelect a model (1-$($models.Count)) or press Enter for #1:"
    $selection = Read-Host
    
    if (!$selection.Trim()) {
        $selection = "1"
    }
    
    try {
        $model_index = [int]$selection - 1
        if ($model_index -lt 0 -or $model_index -ge $models.Count) {
            Write-Error "Invalid selection"
            return
        }
    } catch {
        Write-Error "Invalid selection"
        return
    }
    
    $selected_repo = $models[$model_index]
    Write-Info "Selected: $selected_repo"
    
    # Browse model files
    $model_data = Get-ModelFiles $selected_repo
    if (!$model_data) {
        return
    }
    
    # Let user select file or use recommended
    Write-Host "`nSelect file (1-$($model_data.files.Count)) or press Enter for recommended:"
    $file_selection = Read-Host
    
    $selected_file = $model_data.selected  # default to recommended
    
    if ($file_selection.Trim()) {
        try {
            $file_index = [int]$file_selection - 1
            if ($file_index -ge 0 -and $file_index -lt $model_data.files.Count) {
                $selected_file = $model_data.files[$file_index]
            }
        } catch {
            Write-Warning "Invalid file selection, using recommended"
        }
    }
    
    Write-Info "Selected file: $($selected_file.path) ($($selected_file.size_gb) GB)"
    
    # Confirm download
    Write-Warning "This will download $($selected_file.size_gb) GB. Continue? (y/N)"
    $confirm = Read-Host
    
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        # Download the model
        $download_url = "https://huggingface.co/$($model_data.repo_id)/resolve/main/$($selected_file.path)"
        $models_dir = "$InstallDir\models\files"
        $local_filename = Split-Path $selected_file.path -Leaf
        $local_path = "$models_dir\$local_filename"
        
        Write-Info "Downloading from: $download_url"
        Write-Info "Saving to: $local_path"
        
        # Ensure directory exists
        if (!(Test-Path $models_dir)) {
            New-Item -ItemType Directory -Path $models_dir -Force | Out-Null
        }
        
        try {
            $start_time = Get-Date
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($download_url, $local_path)
            $end_time = Get-Date
            $duration = $end_time - $start_time
            
            Write-Info "Download completed in $($duration.TotalMinutes.ToString('F1')) minutes"
            
            # Verify file size
            $file_info = Get-Item $local_path
            $actual_size_gb = [math]::Round($file_info.Length / 1GB, 2)
            Write-Info "Downloaded: $actual_size_gb GB"
            
            # Add to registry for future reference
            Add-ToRegistry $selected_repo $local_filename $selected_file.size_gb
            
        } catch {
            Write-Error "Download failed: $($_.Exception.Message)"
            if (Test-Path $local_path) {
                Remove-Item $local_path -Force
            }
        }
    } else {
        Write-Info "Download cancelled"
    }
}

# Add model to local registry
function Add-ToRegistry($repo_id, $filename, $size_gb) {
    $registry_path = "$InstallDir\models\registry.json"
    $registry = @{}
    
    if (Test-Path $registry_path) {
        $registry = Get-Content $registry_path | ConvertFrom-Json -AsHashtable
    }
    
    # Create friendly name from repo
    $friendly_name = ($repo_id -split '/')[-1].ToLower()
    $friendly_name = $friendly_name -replace '[^a-z0-9]', ''
    
    # Avoid name conflicts
    $counter = 1
    $original_name = $friendly_name
    while ($registry.ContainsKey($friendly_name)) {
        $friendly_name = "$original_name$counter"
        $counter++
    }
    
    $registry[$friendly_name] = @{
        hf_repo = $repo_id
        filename = $filename
        size_gb = $size_gb
        chat_template = "auto"
        added_date = (Get-Date).ToString("yyyy-MM-dd")
    }
    
    $registry | ConvertTo-Json -Depth 10 | Set-Content $registry_path
    Write-Info "Added to registry as: $friendly_name"
}

# Remove installed model
function Remove-Model($model_name) {
    $registry = Get-ModelRegistry
    
    if (!$registry.$model_name) {
        Write-Error "Unknown model: $model_name"
        return
    }
    
    $model_info = $registry.$model_name
    $models_dir = "$InstallDir\models\files"
    $model_path = "$models_dir\$($model_info.filename)"
    
    if (!(Test-Path $model_path)) {
        Write-Warning "Model not installed: $model_name"
        return
    }
    
    $file_info = Get-Item $model_path
    $size_mb = [math]::Round($file_info.Length / 1MB, 1)
    
    Write-Warning "This will remove $model_name ($size_mb MB)"
    $confirm = Read-Host "Are you sure? (y/N)"
    
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Remove-Item $model_path -Force
        Write-Info "Model removed: $model_name"
    } else {
        Write-Info "Cancelled"
    }
}

# Main command processing
try {
    # Load System.Web for URL encoding
    Add-Type -AssemblyName System.Web
    
    switch ($Command) {
        "list" {
            Show-Models
        }
        "search" {
            if (!$ModelName) {
                Write-Error "Search term required"
                Write-Info "Usage: manage-models.ps1 search <search-term>"
                exit 1
            }
            Search-HuggingFaceModels $ModelName | Out-Null
        }
        "browse" {
            Start-ModelBrowser $ModelName
        }
        "pull" {
            if (!$ModelName) {
                Write-Error "Model name required for pull command"
                Write-Info "Usage: manage-models.ps1 pull <model-name>"
                Write-Info "Or use: manage-models.ps1 browse <search-term>"
                exit 1
            }
            
            $registry = Get-ModelRegistry
            if (!$registry.$ModelName) {
                Write-Error "Unknown model: $ModelName"
                Write-Info "Available models: $($registry.PSObject.Properties.Name -join ', ')"
                Write-Info "Or search for new models: manage-models.ps1 browse <search-term>"
                exit 1
            }
            
            $model_info = $registry.$ModelName
            $model_path = Get-Model $model_info $ModelName
            Write-Info "Model ready: $model_path"
        }
        "info" {
            if (!$ModelName) {
                Write-Error "Model name required for info command"
                exit 1
            }
            Show-ModelInfo $ModelName
        }
        "remove" {
            if (!$ModelName) {
                Write-Error "Model name required for remove command"
                exit 1
            }
            Remove-Model $ModelName
        }
    }
} catch {
    Write-Error "Command failed: $($_.Exception.Message)"
    exit 1
}