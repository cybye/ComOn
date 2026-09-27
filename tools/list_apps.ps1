$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
foreach ($item in $apps.GetFolder.Items()) {
    Write-Host "App item: $($item.Name) - Size: $($item.Size) - Date: $($item.ModifyDate)"
}
