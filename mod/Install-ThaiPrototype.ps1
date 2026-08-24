[CmdletBinding()]
param(
    [string]$GameDir = ''
)

$ErrorActionPreference = 'Stop'

function Test-SurvivalLogDir([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    return (Test-Path -LiteralPath (Join-Path $path 'SurvivalLog.exe') -PathType Leaf) -and
           (Test-Path -LiteralPath (Join-Path $path 'SurvivalLog_Data\StreamingAssets\PackageManifest\MainPackage') -PathType Container)
}

function Find-SurvivalLogDir {
    $candidates = [System.Collections.Generic.List[string]]::new()
    $add = {
        param([string]$p)
        if (-not [string]::IsNullOrWhiteSpace($p)) {
            $full = [System.IO.Path]::GetFullPath($p)
            if (-not $candidates.Contains($full)) { $candidates.Add($full) }
        }
    }

    # Steam registry locations and the default Steam path.
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try { & $add (Get-ItemPropertyValue -LiteralPath $key -Name SteamPath -ErrorAction Stop) } catch {}
        try { & $add (Get-ItemPropertyValue -LiteralPath $key -Name InstallPath -ErrorAction Stop) } catch {}
    }
    & $add 'C:\Program Files (x86)\Steam'
    & $add 'C:\Program Files\Steam'
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        foreach ($name in @('SteamLibrary','Steam','Games\SteamLibrary')) { & $add (Join-Path $drive.Root $name) }
    }

    # Read Steam's libraryfolders.vdf to include custom library drives.
    $steamRoots = @($candidates.ToArray())
    foreach ($root in $steamRoots) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -PathType Leaf) {
            foreach ($match in [regex]::Matches([System.IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
                & $add ($match.Groups[1].Value -replace '\\\\','\')
            }
        }
    }
    foreach ($root in $candidates) {
        $candidate = Join-Path $root 'steamapps\common\Survival Log'
        if (Test-SurvivalLogDir $candidate) { return [System.IO.Path]::GetFullPath($candidate) }
    }
    return $null
}

if ([string]::IsNullOrWhiteSpace($GameDir)) { $GameDir = Find-SurvivalLogDir }
if (-not (Test-SurvivalLogDir $GameDir)) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'เลือกโฟลเดอร์เกม Survival Log'
    $dialog.UseDescriptionForTitle = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and (Test-SurvivalLogDir $dialog.SelectedPath)) {
        $GameDir = $dialog.SelectedPath
    } else {
        throw 'ไม่พบโฟลเดอร์เกม Survival Log กรุณาเลือกโฟลเดอร์เกมที่ถูกต้อง'
    }
}
Write-Host "พบเกมที่: $GameDir"
$webDir = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\WebUI\UI\MainUI'
$htmlPath = Join-Path $webDir 'MainUI.html'
$jsPath = Join-Path $webDir 'survival-log-thai-prototype.js'
$backupPath = Join-Path $webDir 'MainUI.html.thai-prototype.backup'
$sourceJs = Join-Path $PSScriptRoot 'survival-log-thai-prototype.js'
$webRoot = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\WebUI'
$sharedSourceJs = Join-Path $PSScriptRoot 'survival-log-thai-webui.js'
$sharedTargetJs = Join-Path $webRoot 'survival-log-thai-webui.js'
$configBundleNameFile = Join-Path $PSScriptRoot 'config-bundle-name.txt'
if (-not (Test-Path -LiteralPath $configBundleNameFile -PathType Leaf)) { throw "Config bundle name file not found: $configBundleNameFile" }
$configBundleName = [System.IO.File]::ReadAllText($configBundleNameFile).Trim()
if ($configBundleName -notmatch '^[0-9a-f]{32}\.bundle$') { throw "Invalid config bundle name: $configBundleName" }
$configBundle = Join-Path $GameDir "SurvivalLog_Data\StreamingAssets\PackageManifest\MainPackage\$configBundleName"
$configBundleBackup = "$configBundle.thai-prototype.backup"
$configBundlePatch = Join-Path $PSScriptRoot 'config-thai-encrypted.bundle'

if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) { throw "MainUI.html not found: $htmlPath" }
if (-not (Test-Path -LiteralPath $sourceJs -PathType Leaf)) { throw "Prototype JavaScript not found: $sourceJs" }
if (-not (Test-Path -LiteralPath $sharedSourceJs -PathType Leaf)) { throw "Early-route JavaScript not found: $sharedSourceJs" }
if (-not (Test-Path -LiteralPath $configBundle -PathType Leaf)) { throw "Config bundle not found: $configBundle" }
if (-not (Test-Path -LiteralPath $configBundlePatch -PathType Leaf)) { throw "Thai config bundle not found: $configBundlePatch" }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$html = [System.IO.File]::ReadAllText($htmlPath)
$scriptTag = '    <script src="survival-log-thai-prototype.js"></script>'
$handlerNeedle = "            'WebUI_MainUI_LocalizationMsg': (data) => {"
$handlerPatch = $handlerNeedle + "`r`n                data = window.SLThaiPrototype.applyLocalization(data);"

# If Steam replaced this page during an update, refresh the restore baseline before patching it again.
if ($html -notmatch 'SLThaiPrototype\.applyLocalization' -and $html -notmatch [regex]::Escape($scriptTag)) {
    Copy-Item -LiteralPath $htmlPath -Destination $backupPath -Force
}

if ($html -notmatch [regex]::Escape($scriptTag)) {
    if ($html -notmatch '<script src="../../webui-core\.js"></script>') { throw 'Expected webui-core script tag was not found; game version may be incompatible.' }
    $html = $html.Replace('    <script src="../../webui-core.js"></script>', "    <script src=`"../../webui-core.js`"></script>`r`n$scriptTag")
}

if ($html -notmatch 'SLThaiPrototype\.applyLocalization') {
    if (-not $html.Contains($handlerNeedle)) { throw 'Localization handler was not found; game version may be incompatible.' }
    $html = $html.Replace($handlerNeedle, $handlerPatch)
}

if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $htmlPath -Destination $backupPath
}

[System.IO.File]::WriteAllText($htmlPath, $html, $utf8NoBom)
Copy-Item -LiteralPath $sourceJs -Destination $jsPath -Force

$webRootResolved = [System.IO.Path]::GetFullPath($webRoot)
$routePages = Get-ChildItem -LiteralPath (Join-Path $webRoot 'UI') -Filter '*.html' -File -Recurse
foreach ($page in $routePages) {
    $pagePath = $page.FullName
    $pageResolved = [System.IO.Path]::GetFullPath($pagePath)
    if (-not $pageResolved.StartsWith($webRootResolved, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Page escaped WebUI root: $pageResolved" }
    $relativePage = [System.IO.Path]::GetRelativePath($webRootResolved, $pageResolved)
    $pageBackup = "$pagePath.thai-prototype.backup"
    $pageHtml = [System.IO.File]::ReadAllText($pagePath)
    $relativeJs = [System.IO.Path]::GetRelativePath($page.DirectoryName, $sharedTargetJs).Replace('\','/')
    $sharedTag = "<script src=`"$relativeJs`"></script>"
    if ($pageHtml -notmatch [regex]::Escape($sharedTag)) {
        $coreMatch = [regex]::Match($pageHtml, '<script src="[^"]*webui-core\.js"></script>')
        # A missing shared tag means this is a pristine/newly-updated page, so its current version is the correct restore baseline.
        if (-not $pagePath.Equals($htmlPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Copy-Item -LiteralPath $pagePath -Destination $pageBackup -Force
        }
        if ($coreMatch.Success) {
            $pageHtml = $pageHtml.Replace($coreMatch.Value, "$($coreMatch.Value)`r`n    $sharedTag")
        } elseif ($pageHtml -match '</head>') {
            $pageHtml = $pageHtml.Replace('</head>', "    $sharedTag`r`n</head>")
        } else {
            throw "No safe script insertion point found: $relativePage"
        }
        [System.IO.File]::WriteAllText($pagePath, $pageHtml, $utf8NoBom)
    }
}
Copy-Item -LiteralPath $sharedSourceJs -Destination $sharedTargetJs -Force
if (-not (Test-Path -LiteralPath $configBundleBackup -PathType Leaf)) { Copy-Item -LiteralPath $configBundle -Destination $configBundleBackup }
Copy-Item -LiteralPath $configBundlePatch -Destination $configBundle -Force

Write-Host 'Thai prototype installed.'
Write-Host "Shared System/UI Thai runtime installed across $($routePages.Count) HTML pages."
Write-Host 'Native Unity English localization slot replaced with Thai (backup retained).'
