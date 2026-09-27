$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1

function Scan-Folder($folder, [string]$indent) {
    $subItems = @($folder.GetFolder.Items())
    foreach ($item in $subItems) {
        if ($item.IsFolder) {
            Write-Host "$indent [DIR] $($item.Name)"
            if ($item.Name -notmatch "MAPS|TEXT|COURSES|WORKOUTS|WIFI|NEWFILES|MONITOR|GOLF|DEBUG|RECORDS|SLEEP|HISTORY") {
                Scan-Folder $item "$indent  "
            }
        } else {
            if ($item.Name -like "*.prg" -or $item.Name -like "*ComOn*") {
                Write-Host "$indent [FILE] $($item.Name) - $($item.Size) bytes"
            }
        }
    }
}

Scan-Folder $gFolder ""
