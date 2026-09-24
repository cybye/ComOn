$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17) # ssfDRIVES / My Computer
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' }
if ($fenix) {
    Write-Host "Found device: $($fenix.Name)"
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' }
    if ($storage) {
        $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' }
        if ($garmin) {
            $apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' }
            if ($apps) {
                Write-Host "Found GARMIN\Apps folder"
                $appsFolder = $apps.GetFolder
                
                $dfSource = (Resolve-Path "bin\ComOnDatafield.prg").Path
                Write-Host "Deploying $dfSource to Apps..."
                $appsFolder.CopyHere($dfSource, 16)
                Write-Host "Waiting for DataField MTP transfer..."
                Start-Sleep -Seconds 8

                $appSource = (Resolve-Path "bin\ComOn.prg").Path
                Write-Host "Deploying $appSource to Apps..."
                $appsFolder.CopyHere($appSource, 16)
                Write-Host "Waiting for App MTP transfer..."
                Start-Sleep -Seconds 8
                
                Write-Host "Deployment completed successfully!"
            } else {
                Write-Error "Apps folder not found in GARMIN"
            }
        } else {
            Write-Error "GARMIN folder not found"
        }
    } else {
        Write-Error "Internal storage not found on device"
    }
} else {
    Write-Error "Fenix device not found via MTP"
}
