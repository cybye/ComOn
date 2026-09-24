$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
    $apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
    if ($apps) {
        $data = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'DATA' }
        if ($data) {
            $folder = $data.GetFolder
            foreach ($item in $folder.Items()) {
                if ($item.Name -like '*ComOn*') {
                    # Shell detail 3 is Date Modified
                    $dateMod = $folder.GetDetailsOf($item, 3)
                    Write-Host "$($item.Name) : DateModified = $dateMod"
                }
            }
        }
    }
}
