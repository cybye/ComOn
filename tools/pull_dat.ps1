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
            $item = $data.GetFolder.Items() | Where-Object { $_.Name -eq 'ComOnDatafield.DAT' }
            if ($item) {
                $destDir = (Resolve-Path "tmp_activity").Path
                $destFolder = $shell.Namespace($destDir)
                Write-Host "Copying ComOnDatafield.DAT..."
                $destFolder.CopyHere($item, 16)
                Start-Sleep -Seconds 3
                Write-Host "Done!"
            } else {
                Write-Host "ComOnDatafield.DAT not found in DATA"
            }
        }
    }
}
