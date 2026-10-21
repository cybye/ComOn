$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1

$targetDir = (Resolve-Path "tmp_logs").Path
$destFolder = $shell.Namespace($targetDir)

# Only pull ComOn.TXT and CIQ_LOG.YML
$comonLog = $logs.GetFolder.Items() | Where-Object { $_.Name -eq "ComOn.TXT" } | Select-Object -First 1
if ($comonLog) {
    Write-Host "Copying ComOn.TXT ($($comonLog.Size) bytes)..."
    $destFolder.CopyHere($comonLog, 16)
    Start-Sleep -Seconds 2
}
$ciqLog = $logs.GetFolder.Items() | Where-Object { $_.Name -eq "CIQ_LOG.YML" } | Select-Object -First 1
if ($ciqLog) {
    Write-Host "Copying CIQ_LOG.YML ($($ciqLog.Size) bytes)..."
    $destFolder.CopyHere($ciqLog, 16)
    Start-Sleep -Seconds 2
}
Write-Host "Done!"
