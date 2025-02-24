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
    $process = Start-Process -FilePath $crushftpExe -ArgumentList '-a', 'crushadmin', 'password' -PassThru -NoNewWindow -Wait
    
    # Check if the process completed successfully (exit code 0)
    if ($process.ExitCode -eq 0) {
        Write-Host "CrushFTP admin user setup completed successfully"
    } else {
        Write-Error "CrushFTP setup failed with exit code: $($process.ExitCode)"
        exit 1
    }
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

Write-Host "Installing CrushFTP as a Windows Service..."
try {
    $crushftpExe = Join-Path $extractPath "CrushFTP11\CrushFTP.exe"

    $serviceName = "CrushFTP"
    
    # First, stop and remove any existing CrushFTP service
    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $serviceName
        Write-Host "Removed existing CrushFTP service"
    }
    
    # Create the service using sc.exe
    $binPath = "`"$crushftpExe`" -d" # TODO - Fix this startup command otherwise might just have to have a separate process check and keep the daemon online without windows service
    sc.exe create $serviceName displayname= "CrushFTP Server" start= auto binpath= $binPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create CrushFTP service. Exit code: $LASTEXITCODE"
        exit 1
    }
    Write-Host "CrushFTP service created successfully"

    # Set the service description
    sc.exe description $serviceName "CrushFTP File Transfer Server running in daemon mode"
    
    # Start the service
    Start-Service -Name $serviceName
    Write-Host "CrushFTP service started successfully"

} catch {
    Write-Error "Failed to setup CrushFTP service: $_"
    exit 1
}

Write-Host "Setup completed successfully! CrushFTP is now running as a Windows service."
