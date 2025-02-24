# PowerShell script to download and setup CrushFTP
$ErrorActionPreference = "Stop"

# Define variables
$crushftpUrl = "https://www.crushftp.com/early11/J/CrushFTP11.zip"
$downloadPath = Join-Path $PSScriptRoot "CrushFTP11.zip"
$extractPath = $PSScriptRoot

Write-Host "Downloading CrushFTP..."
try {
    Invoke-WebRequest -Uri $crushftpUrl -OutFile $downloadPath
    Write-Host "Download completed successfully"
} catch {
    Write-Error "Failed to download CrushFTP: $_"
    exit 1
}

Write-Host "Extracting ZIP file..."
try {
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
    Write-Host "Extraction completed successfully"
} catch {
    Write-Error "Failed to extract ZIP file: $_"
    exit 1
}

Write-Host "Setting up CrushFTP admin user..."
try {
    $crushftpExe = Join-Path $extractPath "CrushFTP11\CrushFTP.exe"
    $process = Start-Process -FilePath $crushftpExe -ArgumentList '-a', 'crushadmin', 'password' -PassThru -NoNewWindow
    
    # Wait for the process to complete or timeout after 30 seconds
    if (-not $process.WaitForExit(30000)) {
        Write-Host "Process is taking too long, terminating..."
        $process.Kill()
    }
    
    if ($process.ExitCode -ne 0) {
        Write-Error "CrushFTP setup failed with exit code: $($process.ExitCode)"
        exit 1
    }
    
    Write-Host "CrushFTP admin user setup completed successfully"
} catch {
    Write-Error "Failed to setup CrushFTP admin user: $_"
    exit 1
}

Write-Host "Setting up Windows Firewall rule for CrushFTP..."
try {
    $crushftpExe = Join-Path $extractPath "CrushFTP11\CrushFTP.exe"
    
    # Remove existing rule if it exists
    Remove-NetFirewallRule -Name "CrushFTP11_Program" -ErrorAction SilentlyContinue
    
    # Create new rule for the program
    New-NetFirewallRule -Name "CrushFTP11_Program" `
        -DisplayName "CrushFTP 11" `
        -Direction Inbound `
        -Action Allow `
        -Program $crushftpExe `
        -Enabled True
    
    Write-Host "Firewall rule created successfully"

} catch {
    Write-Error "Failed to create firewall rule: $_"
    exit 1
}

Write-Host "Starting CrushFTP in daemon mode..."
try {
    $crushftpExe = Join-Path $extractPath "CrushFTP11\CrushFTP.exe"
    
    # Start CrushFTP in daemon mode
    $process = Start-Process -FilePath $crushftpExe -ArgumentList '-d' -PassThru -NoNewWindow
    
    # Give it a moment to start
    Start-Sleep -Seconds 5
    
    if ($process.HasExited) {
        Write-Error "CrushFTP daemon failed to start"
        exit 1
    }
    
    Write-Host "CrushFTP daemon started successfully"

} catch {
    Write-Error "Failed to start CrushFTP daemon: $_"
    exit 1
}

Write-Host "Setup completed successfully! CrushFTP is now running in daemon mode."
