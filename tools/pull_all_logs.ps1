$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
    $apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
    if ($apps) {
        $logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' }
        if ($logs) {
            $targetDir = "tmp_logs"
            if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            $destFolder = $shell.Namespace($targetDir)
            foreach ($item in $logs.GetFolder.Items()) {
                Write-Host "Copying $($item.Name)..."
                $destFolder.CopyHere($item, 16)
                Start-Sleep -Milliseconds 800
            }
            Write-Host "Done copying logs!"
        }
    }
}
