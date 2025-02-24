# Monitor script for CrushFTP
$ErrorActionPreference = "Stop"

# Log file setup
$logFile = Join-Path $PSScriptRoot "crushftp_monitor-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').log"

Start-Transcript -Path $logFile

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $Message"
}

# Configuration
$crushftpPath = Join-Path $PSScriptRoot "CrushFTP11\CrushFTP.exe"
$processName = "CrushFTP"
$global:crushftpProcess = $null

# Create an event to wait on
$script:exitEvent = New-Object System.Threading.ManualResetEvent($false)

# Handler for task scheduler stop
$parentPid = $pid
Write-Log "Monitor script started with PID: $parentPid"

# This script runs the cleanup when the parent process exits
$cleanupScript = {
    param($parentPid, $logPath)
    
    # Wait for parent process to exit
    Wait-Process -Id $parentPid
    
    # Start transcript in the new process
    Start-Transcript -Path $logPath -Append
    
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Parent process $parentPid exited, performing cleanup..."
    
    # Find and stop CrushFTP process
    try {
        $crushProc = Get-Process "CrushFTP" -ErrorAction SilentlyContinue
        if ($crushProc) {
            Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Stopping CrushFTP process..."
            Stop-Process -InputObject $crushProc -Force
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Error during cleanup: $_"
    }
    
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Cleanup completed"
    Stop-Transcript
}

# Start the cleanup monitor process
Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command & {$cleanupScript} $parentPid '$logFile'" -WindowStyle Hidden

try {
    while ($true) {
        try {
            $process = Get-Process $processName -ErrorAction SilentlyContinue
            
            if (-not $process) {
                Write-Log "CrushFTP is not running. Starting it..."
                $global:crushftpProcess = Start-Process -FilePath $crushftpPath -ArgumentList "-d" -PassThru -NoNewWindow
                
                # Wait a moment to check if process started successfully
                Start-Sleep -Seconds 5
                
                if (-not $global:crushftpProcess.HasExited) {
                    Write-Log "CrushFTP started successfully"
                } else {
                    Write-Error "CrushFTP failed to start with exit code: $($global:crushftpProcess.ExitCode)"
                    exit 1
                }
            } else {
                $global:crushftpProcess = $process
            }
            
            # Check every 30 seconds
            Start-Sleep -Seconds 30
            
        } catch {
            Write-Log "Error: $_"
            Start-Sleep -Seconds 30  # Still wait before next check even if there's an error
        }
    }
} finally {
    Stop-Transcript
}