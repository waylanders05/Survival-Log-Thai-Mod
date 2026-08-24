[CmdletBinding()]
param(
    [string]$GameDir = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GameDir)) {
    $roots = [System.Collections.Generic.List[string]]::new()
    $add = { param([string]$p) if ($p -and (Test-Path -LiteralPath $p -PathType Container)) { $full=[IO.Path]::GetFullPath($p); if (-not $roots.Contains($full)) {$roots.Add($full)} } }
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try { & $add (Get-ItemPropertyValue -LiteralPath $key -Name SteamPath -ErrorAction Stop) } catch {}
        try { & $add (Get-ItemPropertyValue -LiteralPath $key -Name InstallPath -ErrorAction Stop) } catch {}
    }
    & $add 'C:\Program Files (x86)\Steam'; & $add 'C:\Program Files\Steam'
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) { & $add (Join-Path $drive.Root 'SteamLibrary') }
    foreach ($root in @($roots.ToArray())) {
        $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -PathType Leaf) { foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')) { & $add ($m.Groups[1].Value -replace '\\\\','\') } }
    }
    foreach ($root in $roots) { $candidate=Join-Path $root 'steamapps\common\Survival Log'; if (Test-Path -LiteralPath (Join-Path $candidate 'SurvivalLog.exe') -PathType Leaf) { $GameDir=$candidate; break } }
}
if ([string]::IsNullOrWhiteSpace($GameDir)) { throw 'ไม่พบโฟลเดอร์เกม Survival Log' }
$webDir = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\WebUI\UI\MainUI'
$htmlPath = Join-Path $webDir 'MainUI.html'
$jsPath = Join-Path $webDir 'survival-log-thai-prototype.js'
$backupPath = Join-Path $webDir 'MainUI.html.thai-prototype.backup'
$webRoot = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\WebUI'
$sharedTargetJs = Join-Path $webRoot 'survival-log-thai-webui.js'
$configBundleNameFile = Join-Path $PSScriptRoot 'config-bundle-name.txt'
$configBundleName = [System.IO.File]::ReadAllText($configBundleNameFile).Trim()
if ($configBundleName -notmatch '^[0-9a-f]{32}\.bundle$') { throw "Invalid config bundle name: $configBundleName" }
$configBundle = Join-Path $GameDir "SurvivalLog_Data\StreamingAssets\PackageManifest\MainPackage\$configBundleName"
$configBundleBackup = "$configBundle.thai-prototype.backup"

if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) { throw "Backup not found: $backupPath" }
Copy-Item -LiteralPath $backupPath -Destination $htmlPath -Force
Remove-Item -LiteralPath $jsPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $backupPath -Force

$webRootResolved = [System.IO.Path]::GetFullPath($webRoot)
$backups = Get-ChildItem -LiteralPath (Join-Path $webRoot 'UI') -Filter '*.html.thai-prototype.backup' -File -Recurse
foreach ($pageBackup in $backups) {
    $backupResolved = [System.IO.Path]::GetFullPath($pageBackup.FullName)
    if (-not $backupResolved.StartsWith($webRootResolved, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Backup escaped WebUI root: $backupResolved" }
    $pagePath = $pageBackup.FullName.Substring(0, $pageBackup.FullName.Length - '.thai-prototype.backup'.Length)
    Copy-Item -LiteralPath $pageBackup.FullName -Destination $pagePath -Force
    Remove-Item -LiteralPath $pageBackup.FullName -Force
}
Remove-Item -LiteralPath $sharedTargetJs -Force -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $configBundleBackup -PathType Leaf) {
    Copy-Item -LiteralPath $configBundleBackup -Destination $configBundle -Force
    Remove-Item -LiteralPath $configBundleBackup -Force
}
Write-Host 'Thai prototype removed and the original MainUI.html restored.'
