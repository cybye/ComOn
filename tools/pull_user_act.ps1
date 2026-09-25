$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
    $act = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Activity' }
    if ($act) {
        $item = $act.GetFolder.Items() | Where-Object { $_.Name -eq '2026-09-22-08-08-39.fit' }
        if ($item) {
            $destDir = (Resolve-Path "tmp_activity").Path
            $destFolder = $shell.Namespace($destDir)
            $destFolder.CopyHere($item, 16)
            Start-Sleep -Seconds 2
            Write-Host "Copied 2026-09-22-08-08-39.fit"
        }
    }
}
