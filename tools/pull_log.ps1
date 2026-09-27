$dest = "U:\code\ComOn\data\fresh_log"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$shell = New-Object -ComObject Shell.Application
$devices = @($shell.NameSpace(17).Items())
$garmin = $devices | Where-Object { $_.Name -like "*fenix*" -or $_.Name -like "*Garmin*" } | Select-Object -First 1
$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$gFolder = $storage.GetFolder.Items() | Where-Object { $_.Name -eq "GARMIN" } | Select-Object -First 1
$apps = $gFolder.GetFolder.Items() | Where-Object { $_.Name -eq "Apps" } | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object { $_.Name -eq "LOGS" } | Select-Object -First 1
$logFile = $logs.GetFolder.Items() | Where-Object { $_.Name -like "*ComOn*.TXT" } | Select-Object -First 1
Write-Host "Logfile found: $($logFile.Name), Size=$($logFile.Size)"
$shell.NameSpace($dest).CopyHere($logFile, 16)
Start-Sleep -Seconds 2
Get-Content "$dest\$($logFile.Name)" | Select-Object -Last 40
