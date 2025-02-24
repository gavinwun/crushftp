# Monitor script for CrushFTP
$ErrorActionPreference = "Stop"

# Log file setup
$logFile = Join-Path $PSScriptRoot "crushftp_monitor.log"
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
    Write-Host "$timestamp - $Message"
}

# Configuration
$crushftpPath = Join-Path $PSScriptRoot "CrushFTP11\CrushFTP.exe"
$processName = "CrushFTP"

while ($true) {
    try {
        $process = Get-Process $processName -ErrorAction SilentlyContinue
        
        if (-not $process) {
            Write-Log "CrushFTP is not running. Starting it..."
            $process = Start-Process -FilePath $crushftpPath -ArgumentList "-d" -PassThru -NoNewWindow -Wait

            # Check if the process completed successfully (exit code 0)
            if ($process.ExitCode -eq 0) {
                Write-Log "CrushFTP started successfully"
            } else {
                Write-Error "CrushFTP failed to start with exit code: $($process.ExitCode)"
                exit 1
            }
        }
        
        # Check every 30 seconds
        Start-Sleep -Seconds 30
        
    } catch {
        Write-Log "Error: $_"
        Start-Sleep -Seconds 30  # Still wait before next check even if there's an error
    }
}
