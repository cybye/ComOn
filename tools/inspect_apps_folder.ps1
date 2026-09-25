$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
    $apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
    if ($apps) {
        Write-Host "=== Items in GARMIN\Apps ==="
        foreach ($item in $apps.GetFolder.Items()) {
            Write-Host "  $($item.Name) ($($item.Size) bytes)"
            if ($item.Name -eq 'LOGS' -or $item.Name -eq 'Data' -or $item.Name -eq 'TEMP') {
                Write-Host "    --- Inside $($item.Name) ---"
                foreach ($sub in $item.GetFolder.Items()) {
                    Write-Host "      $($sub.Name) ($($sub.Size) bytes)"
                }
            }
        }
    }
}
