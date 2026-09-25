$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17) # ssfDRIVES

$retries = 5
$fenix = $null
while ($retries -gt 0 -and -not $fenix) {
    $items = @($computer.Items())
    $fenix = $items | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
    if (-not $fenix) {
        Write-Host "Waiting for device... Found: $(($items | ForEach-Object { $_.Name }) -join ', ')"
        Start-Sleep -Seconds 2
        $retries--
    }
}

if (-not $fenix) {
    Write-Error "Fenix device not found via MTP after retries"
    exit 1
}

Write-Host "Found device: $($fenix.Name)"
$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
$activity = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Activity' }

if (-not $activity) {
    Write-Error "Activity folder not found"
    exit 1
}

# List files sorted by Name descending (Garmin uses YYYY-MM-DD-HH-MM-SS.fit)
$items = @($activity.GetFolder.Items())
$sorted = $items | Where-Object { $_.Name -like '*.fit' } | Sort-Object -Property Name -Descending
Write-Host "Recent activities found (by filename):"
for ($i = 0; $i -lt [Math]::Min(10, $sorted.Count); $i++) {
    $item = $sorted[$i]
    Write-Host "  [$i] $($item.Name) ($($item.Size) bytes)"
}

if ($sorted.Count -gt 0) {
    $latest = $sorted[0]
    $destDir = (Resolve-Path "tmp_activity").Path
    Write-Host "Copying latest file: $($latest.Name) to $destDir..."
    $destFolder = $shell.Namespace($destDir)
    $destFolder.CopyHere($latest, 16)
    Start-Sleep -Seconds 2
    Write-Host "Copied $($latest.Name) successfully."
}
