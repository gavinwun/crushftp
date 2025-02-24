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

Write-Host "Setting up CrushFTP monitor..."
try {
    $crushftpExe = Join-Path $extractPath "CrushFTP11\CrushFTP.exe"
    $monitorScript = Join-Path $PSScriptRoot "monitor_crushftp.ps1"
    
    # Remove existing scheduled task if it exists
    Unregister-ScheduledTask -TaskName "CrushFTP_Monitor" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed existing scheduled task"
    
    # Create a new scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$monitorScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    
    Register-ScheduledTask -TaskName "CrushFTP_Monitor" `
                         -Action $action `
                         -Trigger $trigger `
                         -Principal $principal `
                         -Settings $settings `
                         -Description "Monitors and maintains CrushFTP daemon process"
    
    Write-Host "Scheduled task created successfully"

    Start-ScheduledTask -TaskName "CrushFTP_Monitor"

} catch {
    Write-Error "Failed to setup CrushFTP monitor: $_"
    exit 1
}

Write-Host "Setup completed successfully! CrushFTP is now running with monitoring enabled."
