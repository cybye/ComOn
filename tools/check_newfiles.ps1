$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$newFiles = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "NewFiles" } | Select-Object -First 1
Write-Host "NewFiles folder found: $($newFiles.Name)"
$items = @($newFiles.GetFolder.Items())
Write-Host "Count: $($items.Count)"
foreach ($item in $items) {
    Write-Host "NewFiles item: $($item.Name) - $($item.Size) bytes"
}
