$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1

$folder = $logs.GetFolder
foreach ($item in $folder.Items()) {
    $dateMod = $folder.GetDetailsOf($item, 3)
    Write-Host "$($item.Name) : Size=$($item.Size) DateModified=$dateMod"
}
