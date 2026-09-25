$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
    $gxml = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'GarminDevice.xml' }
    if ($gxml) {
        $destDir = (Resolve-Path "tmp_activity").Path
        $destFolder = $shell.Namespace($destDir)
        $destFolder.CopyHere($gxml, 16)
        Start-Sleep -Seconds 2
        Write-Host "Copied GarminDevice.xml"
    } else {
        Write-Host "GarminDevice.xml not found"
    }
}
