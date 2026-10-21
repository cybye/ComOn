$shell = New-Object -ComObject Shell.Application
$devices = $shell.NameSpace(17).Items()
$garmin = $null
foreach ($dev in $devices) {
    if ($dev.Name -match "fenix" -or $dev.Name -match "Garmin") {
        $garmin = $dev
        break
    }
}
if (-not $garmin) {
    Write-Host "Garmin device not found"
    exit 1
}

function Get-SubFolder($parent, [string]$name) {
    $folder = $parent.GetFolder
    if (-not $folder) { return $null }
    foreach ($item in $folder.Items()) {
        if ($item.Name -eq $name -and $item.IsFolder) {
            return $item
        }
    }
    return $null
}

$storage = $garmin.GetFolder.Items() | Select-Object -First 1
$garminFolder = Get-SubFolder $storage "GARMIN"
$targetDir = (Resolve-Path "tmp_logs").Path
$destFolder = $shell.Namespace($targetDir)

if ($garminFolder) {
    $appsFolder = Get-SubFolder $garminFolder "Apps"
    if ($appsFolder) {
        $logsFolder = Get-SubFolder $appsFolder "LOGS"
        if ($logsFolder) {
            foreach ($item in $logsFolder.GetFolder.Items()) {
                if ($item.Name -match "ComOn" -or $item.Name -match "CIQ") {
                    Write-Host "Copying $($item.Name)..."
                    $destFolder.CopyHere($item, 16)
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}
Write-Host "Done pulling logs."
