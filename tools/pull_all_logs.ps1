$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
if (-not $fenix) {
    Write-Host "No fenix device found"
    exit 1
}
$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like "*Internal Storage*" -or $_.Name -like "*Primary*" } | Select-Object -First 1
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$garminFolder = $garmin.GetFolder

if (-not (Test-Path "tmp_logs")) {
    New-Item -ItemType Directory -Path "tmp_logs" | Out-Null
}
Remove-Item -Force tmp_logs\*.* -ErrorAction SilentlyContinue

$destPath = (Resolve-Path "tmp_logs").Path
$destShell = $shell.Namespace($destPath)

# Check GARMIN root for ERR_LOG or crash logs
foreach ($item in $garminFolder.Items()) {
    if ($item.Name -like "*ERR*" -or $item.Name -like "*CRASH*" -or $item.Name -like "*LOG*") {
        Write-Host "Found in GARMIN: $($item.Name)"
        $destShell.CopyHere($item, 16)
    }
}

# Check GARMIN\Apps\LOGS
$apps = $garminFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
if ($apps) {
    $logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1
    if ($logs) {
        foreach ($item in $logs.GetFolder.Items()) {
            Write-Host "Found in Apps\LOGS: $($item.Name)"
            $destShell.CopyHere($item, 16)
        }
    }
}
Start-Sleep -Seconds 3
