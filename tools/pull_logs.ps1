$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' }
if (-not $fenix) { exit 1 }

$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' }
if ($logs) {
    $destDir = (Resolve-Path "tmp_activity").Path
    $destFolder = $shell.Namespace($destDir)
    foreach ($lf in $logs.GetFolder.Items()) {
        Write-Host "Pulling log: $($lf.Name) ($($lf.Size) bytes)"
        $destFolder.CopyHere($lf, 16)
    }
}
