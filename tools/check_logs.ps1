$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' }
if (-not $fenix) { exit 1 }

$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }

# Look for logs in GARMIN\
$destDir = (Resolve-Path "tmp_activity").Path
$destFolder = $shell.Namespace($destDir)

foreach ($item in $garmin.GetFolder.Items()) {
    if ($item.Name -like '*LOG*' -or $item.Name -like '*ERR*') {
        Write-Host "Found in GARMIN: $($item.Name)"
        $destFolder.CopyHere($item, 16)
    }
}

$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
if ($apps) {
    $logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' }
    if ($logs) {
        Write-Host "Found GARMIN\Apps\LOGS:"
        foreach ($lf in $logs.GetFolder.Items()) {
            Write-Host "  $($lf.Name)"
            $destFolder.CopyHere($lf, 16)
        }
    }
}
