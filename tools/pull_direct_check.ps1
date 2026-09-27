$dest = "U:\code\ComOn\data\direct_check"
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1
foreach ($f in $logs.GetFolder.Items()) {
    Write-Host "Log file: $($f.Name) - $($f.ModifyDate) - $($f.Size)"
    $shell.NameSpace($dest).CopyHere($f, 16)
}
Start-Sleep -Seconds 2
Get-ChildItem -Path $dest
