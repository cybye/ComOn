$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' }
if (-not $fenix) {
    Write-Error "Fenix not found"
    exit 1
}

$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }

# Create temporary empty log files locally
$tmpDir = (Resolve-Path "tmp_activity").Path
$dfLog = Join-Path $tmpDir "ComOnDatafield.TXT"
$appLog = Join-Path $tmpDir "ComOn.TXT"
Set-Content -Path $dfLog -Value ""
Set-Content -Path $appLog -Value ""

# Copy to GARMIN\Apps\LOGS
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' }
if ($logs) {
    Write-Host "Found GARMIN\Apps\LOGS, copying debug log files..."
    $logsFolder = $logs.GetFolder
    $logsFolder.CopyHere($dfLog, 16)
    Start-Sleep -Seconds 1
    $logsFolder.CopyHere($appLog, 16)
    Start-Sleep -Seconds 1
    Write-Host "Debug log files ComOnDatafield.TXT and ComOn.TXT created in GARMIN\Apps\LOGS successfully!"
} else {
    Write-Error "LOGS folder not found in GARMIN\Apps"
}
