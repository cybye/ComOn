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
                $targetDir = "tmp_dat"
                if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                $destFolder = $shell.Namespace($targetDir)
                $destFolder.CopyHere($item, 16)
                Start-Sleep -Seconds 2
                Write-Host "Copied to tmp_dat!"
            }
        }
    }
}
