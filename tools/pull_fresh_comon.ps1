$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1

$targetDir = (Resolve-Path "tmp_logs").Path
$destFolder = $shell.Namespace($targetDir)

# Delete local ComOn.TXT first so CopyHere doesn't prompt or skip
$localTarget = Join-Path $targetDir "ComOn.TXT"
if (Test-Path $localTarget) { Remove-Item -Force $localTarget }

$comonLog = $logs.GetFolder.Items() | Where-Object { $_.Name -eq "ComOn.TXT" } | Select-Object -First 1
if ($comonLog) {
    Write-Host "Invoking CopyHere for ComOn.TXT (flag 16)..."
    # flag 16: Respond with "Yes to All" for any dialog, 4: Do not display progress dialog
    # 16 + 4 + 512 + 1024 = 1556
    $destFolder.CopyHere($comonLog, 16)
    
    $waited = 0
    while ($waited -lt 15) {
        Start-Sleep -Seconds 1
        $waited++
        if (Test-Path $localTarget) {
            $item = Get-Item $localTarget
            if ($item.Length -gt 0) {
                Write-Host "Success! File copied: $($item.Length) bytes (waited ${waited}s)"
                break
            }
        }
    }
}
