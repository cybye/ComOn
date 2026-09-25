$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if (-not $fenix) { 
    Write-Host "Watch not found"
    exit 1 
}

$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' }

$targetDir = "C:\Users\cybye\Documents\antigravity\silly-planck\tmp_logs"
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
$destFolder = $shell.Namespace($targetDir)

if ($logs) {
    foreach ($lf in $logs.GetFolder.Items()) {
        if ($lf.Name -like '*CIQ*' -or $lf.Name -like '*ComOn*') {
            Write-Host "Pulling: $($lf.Name)"
            $destFolder.CopyHere($lf, 16)
        }
    }
}
Write-Host "Log pull complete"
