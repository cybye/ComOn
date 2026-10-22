$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
if (-not $fenix) {
    Write-Host "No fenix device found"
    exit 1
}
$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like "*Internal Storage*" -or $_.Name -like "*Primary*" } | Select-Object -First 1
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1

if (-not (Test-Path "tmp_logs")) {
    New-Item -ItemType Directory -Path "tmp_logs" | Out-Null
}

$destPath = (Resolve-Path "tmp_logs").Path
$destShell = $shell.Namespace($destPath)

foreach ($item in $logs.GetFolder.Items()) {
    Write-Host "Found log: $($item.Name)"
    if ($item.Name -like "*ComOn*" -or $item.Name -like "*CIQ*") {
        $destShell.CopyHere($item, 16)
        Write-Host "Copied $($item.Name) to tmp_logs"
    }
}
Start-Sleep -Seconds 2
