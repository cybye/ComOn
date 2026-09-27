$shell = New-Object -ComObject Shell.Application
$devices = $shell.NameSpace(17).Items()
$garmin = $null
foreach ($dev in $devices) {
    if ($dev.Name -match "fenix" -or $dev.Name -match "Garmin") {
        $garmin = $dev
        break
    }
}
if (-not $garmin) {
    Write-Host "Garmin device not found"
    exit 1
}

function Get-SubFolder($parent, [string]$name) {
    $folder = $parent.GetFolder
    if (-not $folder) { return $null }
    foreach ($item in $folder.Items()) {
        if ($item.Name -eq $name -and $item.IsFolder) {
            return $item
        }
    }
    return $null
}

$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$garminFolder = Get-SubFolder $storage "GARMIN"
$dest = "U:\code\ComOn\data"

if ($garminFolder) {
    $actFolder = Get-SubFolder $garminFolder "ACTIVITY"
    if ($actFolder) {
        $items = @($actFolder.GetFolder.Items())
        # Filter for files named 2026-09-26*
        $todayFiles = $items | Where-Object { $_.Name -like "2026-09-26*.fit" } | Sort-Object { $_.Name } -Descending
        foreach ($f in $todayFiles) {
            Write-Host "Today FIT: $($f.Name)"
        }
        $latest = $todayFiles | Select-Object -First 1
        if ($latest) {
            Write-Host "Copying $($latest.Name)..."
            $shell.NameSpace($dest).CopyHere($latest, 16)
            Start-Sleep -Seconds 1
            Write-Host "Done copying $($latest.Name)"
        }
    }
    
    $appsFolder = Get-SubFolder $garminFolder "Apps"
    if ($appsFolder) {
        $logsFolder = Get-SubFolder $appsFolder "LOGS"
        if ($logsFolder) {
            foreach ($log in $logsFolder.GetFolder.Items()) {
                if ($log.Name -eq "ComOnDataField_fenix847mm.TXT" -or $log.Name -eq "CIQ_LOG.YML") {
                    Write-Host "Copying $($log.Name)..."
                    $shell.NameSpace($dest).CopyHere($log, 16)
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}
Write-Host "Finished."
