$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
    $apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
    if ($apps) {
        $destDir = (Resolve-Path "tmp_activity").Path
        $destFolder = $shell.Namespace($destDir)

        $data = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'DATA' }
        if ($data) {
            foreach ($item in $data.GetFolder.Items()) {
                if ($item.Name -like '*ComOn*') {
                    Write-Host "Copying $($item.Name)..."
                    $destFolder.CopyHere($item, 16)
                }
            }
        }

        $logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' }
        if ($logs) {
            foreach ($item in $logs.GetFolder.Items()) {
                if ($item.Name -like '*ComOn*' -or $item.Name -like '*CIQ*') {
                    Write-Host "Copying $($item.Name)..."
                    $destFolder.CopyHere($item, 16)
                }
            }
        }
    }
}
