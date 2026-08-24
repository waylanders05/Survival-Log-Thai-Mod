[CmdletBinding()]
param(
    [string]$GameDir = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SurvivalLog-Common.ps1')

function Test-ContainsOnce([string]$Text, [string]$Needle) {
    return ([regex]::Matches($Text, [regex]::Escape($Needle))).Count
}

function Remove-InjectedLine([string]$Text, [string]$Line) {
    $out = $Text.Replace($Line + "`r`n", '').Replace($Line + "`n", '')
    return $out.Replace($Line, '')
}

function Add-LocalWarning([string]$Message) {
    [void]$script:warnings.Add($Message)
    Write-Warning $Message
}

function Get-StatePage([string]$RelativePath) {
    if (-not $script:statePages.ContainsKey($RelativePath.ToLowerInvariant())) { return $null }
    return $script:statePages[$RelativePath.ToLowerInvariant()]
}

function Get-StateConfigFor([string]$TargetPath) {
    if (-not $script:state -or -not $script:state.configBundle) { return $null }
    $relative = $TargetPath.Substring($script:webRoot.Length+1)
    if ([string]$script:state.configBundle.path -eq ([System.IO.Path]::GetFileName($TargetPath))) { return $script:state.configBundle }
    if ([string]$script:state.configBundle.path -eq $relative) { return $script:state.configBundle }
    return $null
}

try {
    $GameDir = Select-SurvivalLogDir $GameDir
    Write-Host "พบเกมที่: $GameDir"
    $script:warnings = New-Object 'System.Collections.Generic.List[string]'

    $webRoot = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\WebUI'
    $uiRoot = Join-Path $webRoot 'UI'
    $mainUiDir = Join-Path $uiRoot 'MainUI'
    $htmlPath = Join-Path $mainUiDir 'MainUI.html'
    $statePath = Join-Path $webRoot '.survival-log-thai-install.json'
    $configDir = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\PackageManifest\MainPackage'
    $configBundleNameFile = Join-Path $PSScriptRoot 'config-bundle-name.txt'
    $configBundlePatch = Join-Path $PSScriptRoot 'config-thai-encrypted.bundle'
    $sourceJs = Join-Path $PSScriptRoot 'survival-log-thai-prototype.js'
    $sharedSourceJs = Join-Path $PSScriptRoot 'survival-log-thai-webui.js'
    $mainJsTarget = Join-Path $mainUiDir 'survival-log-thai-prototype.js'
    $sharedTargetJs = Join-Path $webRoot 'survival-log-thai-webui.js'
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $expectedConfigBundleName = $null
    if (Test-Path -LiteralPath $configBundleNameFile -PathType Leaf) {
        $expectedConfigBundleName = [System.IO.File]::ReadAllText($configBundleNameFile).Trim()
        if ($expectedConfigBundleName -notmatch '^[0-9a-f]{32}\.bundle$') { $expectedConfigBundleName = $null }
    }

    $script:state = $null
    $script:statePages = @{}
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $script:state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
            foreach ($pageState in @($script:state.pages)) {
                if ($pageState.path) { $script:statePages[[string]$pageState.path.ToLowerInvariant()] = $pageState }
            }
        } catch { Add-LocalWarning 'ไฟล์สถานะมอดอ่านไม่ได้ จะใช้การตรวจจาก marker และ backup แทน' }
    }

    $scriptTag = '    <script src="survival-log-thai-prototype.js"></script>'
    $hookLine = '                data = window.SLThaiPrototype.applyLocalization(data);'
    $sharedTargetSourceHash = $null
    $mainTargetSourceHash = $null
    if (Test-Path -LiteralPath $sharedSourceJs -PathType Leaf) { $sharedTargetSourceHash = Get-FileHashHex $sharedSourceJs }
    if (Test-Path -LiteralPath $sourceJs -PathType Leaf) { $mainTargetSourceHash = Get-FileHashHex $sourceJs }

    $processedPages = @{}
    $processPage = {
        param([string]$PagePath)
        $resolved = [System.IO.Path]::GetFullPath($PagePath)
        if (-not $resolved.StartsWith([System.IO.Path]::GetFullPath($webRoot), [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-LocalWarning "ข้ามไฟล์นอก WebUI root: $resolved"; return
        }
        $key = $resolved.ToLowerInvariant()
        if ($processedPages.ContainsKey($key)) { return }
        $processedPages[$key] = $true
        $isMain = $resolved.Equals([System.IO.Path]::GetFullPath($htmlPath), [System.StringComparison]::OrdinalIgnoreCase)
        $relativeJs = (Get-RelativePathCompat (Split-Path -Parent $resolved) $sharedTargetJs).Replace('\','/')
        $sharedTag = "    <script src=`"$relativeJs`"></script>"
        $backupPath = "$resolved.thai-prototype.backup"
        $targetExists = Test-Path -LiteralPath $resolved -PathType Leaf
        $backupExists = Test-Path -LiteralPath $backupPath -PathType Leaf
        $pageText = if ($targetExists) { [System.IO.File]::ReadAllText($resolved) } else { '' }
        $hasShared = (Test-ContainsOnce $pageText $sharedTag) -gt 0
        $hasMain = $isMain -and ($pageText.Contains($scriptTag) -or $pageText.Contains($hookLine))
        $hasMod = $hasShared -or $hasMain
        $statePage = Get-StatePage (Get-RelativePathCompat $webRoot $resolved)
        $knownPatched = $false
        if ($statePage -and $statePage.patchedHash -and $targetExists) { $knownPatched = (Get-FileHashHex $resolved) -eq [string]$statePage.patchedHash }

        if ($backupExists) {
            $backupText = [System.IO.File]::ReadAllText($backupPath)
            $backupBytes = [System.IO.File]::ReadAllBytes($backupPath)
            $backupHasMarker = (Test-ContainsOnce $backupText $sharedTag) -gt 0 -or ($backupText -match 'survival-log-thai-webui\.js') -or ($isMain -and ($backupText.Contains($scriptTag) -or $backupText.Contains($hookLine)))
            if ($backupHasMarker) {
                Add-LocalWarning "backup ไม่ใช่ไฟล์ต้นฉบับ จึงไม่ใช้คืนค่า: $backupPath"
            } elseif (-not $targetExists) {
                # A page removed by a Steam update must not be resurrected from
                # an older mod backup. Keep the backup for manual recovery.
                Add-LocalWarning "พบ backup ของหน้า WebUI ที่ไม่มีในเกมปัจจุบัน จึงไม่คืนค่า: $backupPath"
            } elseif ($hasMod -and ($knownPatched -or -not $statePage)) {
                Write-AtomicBytes $resolved $backupBytes
                Remove-Item -LiteralPath $backupPath -Force
            } elseif (-not $hasMod) {
                # Current file is already a newer/pristine Steam file. Never restore an old baseline over it.
                Remove-Item -LiteralPath $backupPath -Force
            } else {
                Add-LocalWarning "ไม่แน่ใจว่าไฟล์ปัจจุบันเป็นมอดรุ่นใด จึงไม่ overwrite: $resolved"
            }
        } elseif ($hasMod -and $targetExists) {
            # Best-effort cleanup when an older/partial installation has no backup.
            $clean = $pageText
            if ($hasShared) { $clean = Remove-InjectedLine $clean $sharedTag }
            if ($isMain) {
                $clean = Remove-InjectedLine $clean $hookLine
                $clean = Remove-InjectedLine $clean $scriptTag
            }
            if ($clean -ne $pageText) { Write-AtomicText $resolved $clean $utf8NoBom }
            Add-LocalWarning "ไม่มี backup สำหรับ $resolved จึงลบเฉพาะ marker ของมอดเท่าที่พบ"
        }
    }

    if (Test-Path -LiteralPath $uiRoot -PathType Container) {
        foreach ($page in @(Get-ChildItem -LiteralPath $uiRoot -Filter '*.html' -File -Recurse)) { & $processPage $page.FullName }
        foreach ($backup in @(Get-ChildItem -LiteralPath $uiRoot -Filter '*.html.thai-prototype.backup' -File -Recurse)) {
            $target = $backup.FullName.Substring(0, $backup.FullName.Length - '.thai-prototype.backup'.Length)
            & $processPage $target
        }
    } else { Add-LocalWarning "ไม่พบ WebUI/UI: $uiRoot" }

    $removeOwned = {
        param([string]$Path, [string]$ExpectedHash, [string]$Label)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
        $hash = Get-FileHashHex $Path
        if ($ExpectedHash -and $hash -eq $ExpectedHash) {
            Remove-Item -LiteralPath $Path -Force
        } else {
            Add-LocalWarning "ไฟล์ $Label ถูกแก้ไขหรือไม่ตรงกับมอด จึงเก็บไว้ไม่ลบ: $Path"
        }
    }
    $sharedExpected = $sharedTargetSourceHash
    if ($script:state -and $script:state.sharedRuntime -and $script:state.sharedRuntime.patchedHash) { $sharedExpected = [string]$script:state.sharedRuntime.patchedHash }
    $mainExpected = $mainTargetSourceHash
    if ($script:state -and $script:state.mainRuntime -and $script:state.mainRuntime.patchedHash) { $mainExpected = [string]$script:state.mainRuntime.patchedHash }
    & $removeOwned $sharedTargetJs $sharedExpected 'shared runtime'
    & $removeOwned $mainJsTarget $mainExpected 'MainUI runtime'

    $patchHash = $null
    if (Test-Path -LiteralPath $configBundlePatch -PathType Leaf) { $patchHash = Get-FileHashHex $configBundlePatch }
    if (Test-Path -LiteralPath $configDir -PathType Container) {
        foreach ($backup in @(Get-ChildItem -LiteralPath $configDir -Filter '*.bundle.thai-prototype.backup' -File)) {
            $target = $backup.FullName.Substring(0, $backup.FullName.Length - '.thai-prototype.backup'.Length)
            $backupHash = Get-FileHashHex $backup.FullName
            if ($patchHash -and $backupHash -eq $patchHash) {
                Add-LocalWarning "config backup เป็นไฟล์มอด จึงไม่ใช้คืนค่า: $($backup.FullName)"; continue
            }
            $stateConfig = Get-StateConfigFor $target
            $targetExists = Test-Path -LiteralPath $target -PathType Leaf
            $targetHash = if ($targetExists) { Get-FileHashHex $target } else { $null }
            $knownPatched = $false
            if ($patchHash -and $targetHash -eq $patchHash) { $knownPatched = $true }
            if ($stateConfig -and $stateConfig.patchedHash -and $targetHash -eq [string]$stateConfig.patchedHash) { $knownPatched = $true }
            $isCurrentPackageBundle = $expectedConfigBundleName -and ([System.IO.Path]::GetFileName($target) -eq $expectedConfigBundleName)
            if (-not $targetExists -and -not $isCurrentPackageBundle -and -not $stateConfig) {
                # An orphan backup from an older game/package version must not be
                # reintroduced after Steam has replaced or removed that bundle.
                Add-LocalWarning "พบ config backup ของไฟล์เก่าที่ไม่มีในเกมปัจจุบัน จึงไม่คืนค่า: $($backup.FullName)"
                continue
            }
            if (-not $targetExists -or $knownPatched) {
                Write-AtomicBytes $target ([System.IO.File]::ReadAllBytes($backup.FullName))
                Remove-Item -LiteralPath $backup.FullName -Force
            } elseif ($stateConfig -and $stateConfig.baselineHash -and $targetHash -eq [string]$stateConfig.baselineHash) {
                Remove-Item -LiteralPath $backup.FullName -Force
            } else {
                Add-LocalWarning "config bundle/backup ไม่ตรงสถานะที่รู้จัก จึงไม่ overwrite: $target"
            }
        }
    }

    if ($script:warnings.Count -eq 0 -and (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        Remove-Item -LiteralPath $statePath -Force
    }
    Write-Host 'Thai prototype removal completed.'
    if ($script:warnings.Count -gt 0) { Write-Host "มีคำเตือน $($script:warnings.Count) รายการ; ไฟล์ที่ไม่แน่ใจถูกเก็บไว้เพื่อความปลอดภัย" }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
