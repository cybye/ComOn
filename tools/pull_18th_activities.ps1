$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$activity = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Activity" } | Select-Object -First 1

$destDir = (Resolve-Path "tmp_activity").Path
$destFolder = $shell.Namespace($destDir)

$items = @($activity.GetFolder.Items()) | Where-Object { $_.Name -like "2026-10-18*.fit" }
foreach ($item in $items) {
    Write-Host "Copying $($item.Name) ($($item.Size) bytes)..."
    $destFolder.CopyHere($item, 16)
}
Start-Sleep -Seconds 3
Write-Host "Done copying 2026-10-18 activities."
