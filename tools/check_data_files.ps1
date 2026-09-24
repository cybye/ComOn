$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' }
if (-not $fenix) { exit 1 }

$storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
$garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
$apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
if ($apps) {
    $data = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'Data' }
    if ($data) {
        Write-Host "Found Apps\Data files:"
        $destDir = (Resolve-Path "tmp_activity").Path
        $destFolder = $shell.Namespace($destDir)
        foreach ($f in $data.GetFolder.Items()) {
            Write-Host "  $($f.Name)"
            if ($f.Name -like '*b89e4002*' -or $f.Name -like '*a89e4001*' -or $f.Name -like '*ComOn*') {
                Write-Host "  -> Copying $($f.Name)..."
                $destFolder.CopyHere($f, 16)
            }
        }
    }
}
