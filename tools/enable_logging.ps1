$shell = New-Object -ComObject Shell.Application
$computer = $shell.Namespace(17)
$fenix = $computer.Items() | Where-Object { $_.Name -like '*fenix*' -or $_.Name -like '*Garmin*' } | Select-Object -First 1
if ($fenix) {
    Write-Host "Found device: $($fenix.Name)"
    $storage = $fenix.GetFolder.Items() | Where-Object { $_.Name -like '*Internal Storage*' -or $_.Name -like '*Primary*' } | Select-Object -First 1
    if ($storage) {
        $garmin = $storage.GetFolder.Items() | Where-Object { $_.Name -eq 'GARMIN' } | Select-Object -First 1
        if ($garmin) {
            $apps = $garmin.GetFolder.Items() | Where-Object { $_.Name -eq 'Apps' } | Select-Object -First 1
            $logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq 'LOGS' } | Select-Object -First 1
            if ($logs) {
                $logsFolder = $logs.GetFolder
                # Create empty ComOn.TXT and ComOnDatafield.TXT locally first
                $tempLog = "tools\ComOn.TXT"
                New-Item -ItemType File -Force -Path $tempLog | Out-Null
                $logsFolder.CopyHere((Resolve-Path $tempLog).Path, 16)

                $tempDfLog = "tools\ComOnDatafield.TXT"
                New-Item -ItemType File -Force -Path $tempDfLog | Out-Null
                $logsFolder.CopyHere((Resolve-Path $tempDfLog).Path, 16)
                Start-Sleep -Seconds 2
                Write-Host "ComOn.TXT and ComOnDatafield.TXT created on watch."
            }
        }
    }
}
