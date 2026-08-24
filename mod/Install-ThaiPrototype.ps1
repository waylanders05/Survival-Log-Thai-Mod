[CmdletBinding()]
param(
    [string]$GameDir = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SurvivalLog-Common.ps1')

function Test-ContainsOnce([string]$Text, [string]$Needle) {
    return ([regex]::Matches($Text, [regex]::Escape($Needle))).Count
}

function Test-PageHasModMarker([string]$Text, [string]$SharedTag, [bool]$IsMain) {
    if (Test-ContainsOnce $Text $SharedTag) { return $true }
    if ($Text -match 'survival-log-thai-webui\.js') { return $true }
    if ($IsMain -and ($Text.Contains($scriptTag) -or $Text.Contains($hookLine))) { return $true }
    return $false
}

function Get-TextBytes([string]$Text) {
    return $script:utf8NoBom.GetBytes($Text)
}

function Save-Snapshot([string]$Path) {
    if ($script:snapshots.ContainsKey($Path)) { return }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $script:snapshots[$Path] = [pscustomobject]@{ Exists = $true; Bytes = [System.IO.File]::ReadAllBytes($Path) }
    } else {
        $script:snapshots[$Path] = [pscustomobject]@{ Exists = $false; Bytes = $null }
    }
}

function Restore-Snapshots {
    foreach ($path in @($script:snapshots.Keys)) {
        $snapshot = $script:snapshots[$path]
        if ($snapshot.Exists) {
            [System.IO.File]::WriteAllBytes($path, $snapshot.Bytes)
        } elseif (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    $GameDir = Select-SurvivalLogDir $GameDir
    Write-Host "พบเกมที่: $GameDir"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $snapshots = @{}
    $script:utf8NoBom = $utf8NoBom
    $script:snapshots = $snapshots

    $webRoot = Join-Path $GameDir 'SurvivalLog_Data\StreamingAssets\WebUI'
    $uiRoot = Join-Path $webRoot 'UI'
    $mainUiDir = Join-Path $uiRoot 'MainUI'
    $htmlPath = Join-Path $mainUiDir 'MainUI.html'
    $sourceJs = Join-Path $PSScriptRoot 'survival-log-thai-prototype.js'
    $sharedSourceJs = Join-Path $PSScriptRoot 'survival-log-thai-webui.js'
    $sharedTargetJs = Join-Path $webRoot 'survival-log-thai-webui.js'
    $configBundleNameFile = Join-Path $PSScriptRoot 'config-bundle-name.txt'
    $configBundlePatch = Join-Path $PSScriptRoot 'config-thai-encrypted.bundle'
    $statePath = Join-Path $webRoot '.survival-log-thai-install.json'

    foreach ($required in @($htmlPath,$sourceJs,$sharedSourceJs,$configBundleNameFile,$configBundlePatch)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "ไม่พบไฟล์ที่จำเป็น: $required" }
    }
    if (-not (Test-Path -LiteralPath $uiRoot -PathType Container)) { throw "ไม่พบโฟลเดอร์ WebUI/UI: $uiRoot" }

    $configBundleName = [System.IO.File]::ReadAllText($configBundleNameFile).Trim()
    if ($configBundleName -notmatch '^[0-9a-f]{32}\.bundle$') { throw "ชื่อ config bundle ไม่ถูกต้อง: $configBundleName" }
    $configBundle = Join-Path $GameDir "SurvivalLog_Data\StreamingAssets\PackageManifest\MainPackage\$configBundleName"
    $configBundleBackup = "$configBundle.thai-prototype.backup"
    if (-not (Test-Path -LiteralPath $configBundle -PathType Leaf)) { throw "ไม่พบ config bundle ของเกม: $configBundle" }

    $state = $null
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } catch { Write-Warning 'ไฟล์สถานะมอดเสียหาย จะตรวจสอบจากเนื้อหาและ backup แทน' }
    }

    $scriptTag = '    <script src="survival-log-thai-prototype.js"></script>'
    $handlerNeedle = "            'WebUI_MainUI_LocalizationMsg': (data) => {"
    $hookLine = '                data = window.SLThaiPrototype.applyLocalization(data);'
    $handlerPatch = $handlerNeedle + "`r`n$hookLine"

    $mainText = [System.IO.File]::ReadAllText($htmlPath)
    $mainScriptCount = Test-ContainsOnce $mainText $scriptTag
    $mainHookCount = Test-ContainsOnce $mainText $hookLine
    if ($mainScriptCount -gt 1 -or $mainHookCount -gt 1) { throw 'MainUI มี script หรือ localization hook ซ้ำหลายชุด ต้องตรวจสอบไฟล์ก่อนติดตั้ง' }
    if (($mainScriptCount -eq 1) -xor ($mainHookCount -eq 1)) { throw 'MainUI อยู่ในสถานะติดตั้งค้างบางส่วน จึงหยุดก่อนแก้ไฟล์เพิ่มเติม' }
    $mainNeedsPrototype = ($mainScriptCount -eq 0)
    if ($mainNeedsPrototype -and (Test-ContainsOnce $mainText $handlerNeedle) -ne 1) { throw 'ไม่พบ localization handler ของ MainUI หรือโครงสร้างเกมเปลี่ยนไป' }

    $routePages = @(Get-ChildItem -LiteralPath $uiRoot -Filter '*.html' -File -Recurse)
    if ($routePages.Count -eq 0) { throw 'ไม่พบหน้า WebUI สำหรับติดตั้ง' }
    $pagePlans = @()

    # Preflight every page and build the complete write plan before changing any file.
    foreach ($page in $routePages) {
        $pagePath = [System.IO.Path]::GetFullPath($page.FullName)
        $pageText = [System.IO.File]::ReadAllText($pagePath)
        $isMain = $pagePath.Equals([System.IO.Path]::GetFullPath($htmlPath), [System.StringComparison]::OrdinalIgnoreCase)
        $relativeJs = (Get-RelativePathCompat $page.DirectoryName $sharedTargetJs).Replace('\','/')
        $sharedTag = "    <script src=`"$relativeJs`"></script>"
        $sharedCount = Test-ContainsOnce $pageText $sharedTag
        if ($sharedCount -gt 1) { throw "พบ shared runtime ซ้ำในหน้า: $pagePath" }
        $needsShared = ($sharedCount -eq 0)
        $patchedText = $pageText

        if ($needsShared) {
            $coreMatch = [regex]::Match($patchedText, '<script src="[^"]*webui-core\.js"></script>')
            if ($coreMatch.Success) {
                $patchedText = $patchedText.Replace($coreMatch.Value, "$($coreMatch.Value)`r`n    $sharedTag")
            } elseif ($patchedText -match '</head>') {
                $patchedText = $patchedText.Replace('</head>', "    $sharedTag`r`n</head>")
            } else {
                throw "ไม่พบจุดแทรก script ที่ปลอดภัยในหน้า: $pagePath"
            }
        }

        if ($isMain -and $mainNeedsPrototype) {
            $coreMatch = [regex]::Match($patchedText, '<script src="\.\./\.\./webui-core\.js"></script>')
            if (-not $coreMatch.Success) { throw 'ไม่พบ webui-core script tag ของ MainUI; เวอร์ชันเกมอาจไม่รองรับ' }
            $patchedText = $patchedText.Replace($coreMatch.Value, "$($coreMatch.Value)`r`n$scriptTag")
            if (-not $patchedText.Contains($handlerNeedle)) { throw 'ไม่พบ localization handler ของ MainUI; เวอร์ชันเกมอาจไม่รองรับ' }
            $patchedText = $patchedText.Replace($handlerNeedle, $handlerPatch)
        }

        $needsPatch = $patchedText -ne $pageText
        $backupPath = "$pagePath.thai-prototype.backup"
        $currentBytes = [System.IO.File]::ReadAllBytes($pagePath)
        $currentHash = Get-FileHashHex $pagePath
        $isModded = (Test-PageHasModMarker $pageText $sharedTag $isMain)
        if ($isModded -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            $existingBackupText = [System.IO.File]::ReadAllText($backupPath)
            if (Test-PageHasModMarker $existingBackupText $sharedTag $isMain) {
                throw "backup ของหน้ามี marker มอดอยู่แล้ว จึงไม่เสี่ยงเขียนทับ: $backupPath"
            }
        }
        if ($isModded -and $needsPatch -and $isMain -and $mainNeedsPrototype) {
            throw 'MainUI มีร่องรอยการติดตั้งบางส่วน จึงไม่สามารถแก้ต่อแบบปลอดภัยได้'
        }
        if ($isModded -and -not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            throw "พบไฟล์มอดในหน้าแต่ไม่มี backup ต้นฉบับ: $pagePath"
        }

        $backupAction = 'none'
        if ($needsPatch) {
            if ($isModded) {
                # A partial install may be completed, but never use its patched content as a new backup.
                $backupAction = 'none'
            } elseif (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
                $backupAction = 'create'
            } else {
                $backupText = [System.IO.File]::ReadAllText($backupPath)
                $backupHash = Get-FileHashHex $backupPath
                $backupHasMarker = Test-PageHasModMarker $backupText $sharedTag $isMain
                # A pristine current page different from the old backup is a Steam update baseline.
                if ($backupHasMarker -or $backupHash -ne $currentHash) { $backupAction = 'refresh' }
            }
        }
        $baselineHashForState = $currentHash
        if ($isModded -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) { $baselineHashForState = Get-FileHashHex $backupPath }
        $pagePlans += [pscustomobject]@{
            Path=$pagePath; Relative=(Get-RelativePathCompat $webRoot $pagePath); OriginalBytes=$currentBytes
            OriginalText=$pageText; PatchedText=$patchedText; NeedsPatch=$needsPatch; BackupPath=$backupPath
            BackupAction=$backupAction; BaselineHash=$baselineHashForState; PatchedHash=$currentHash
        }
    }

    $configHash = Get-FileHashHex $configBundle
    $configPatchHash = Get-FileHashHex $configBundlePatch
    $configBackupExists = Test-Path -LiteralPath $configBundleBackup -PathType Leaf
    $configBackupAction = 'none'
    $stateConfig = $null
    if ($state -and $state.configBundle) { $stateConfig = $state.configBundle }
    $knownInstalledConfig = ($configHash -eq $configPatchHash)
    if ($stateConfig -and $stateConfig.patchedHash -and $configHash -eq [string]$stateConfig.patchedHash) { $knownInstalledConfig = $true }
    if ($knownInstalledConfig) {
        if (-not $configBackupExists) { throw 'พบ config bundle ที่เป็นมอด แต่ไม่มี backup ต้นฉบับ จึงหยุดเพื่อป้องกันการสูญเสียไฟล์เกม' }
        if ((Get-FileHashHex $configBundleBackup) -eq $configPatchHash) { throw 'config bundle backup เป็นไฟล์มอด ไม่ใช่ต้นฉบับ จึงหยุดอย่างปลอดภัย' }
    } else {
        if (-not $configBackupExists) { $configBackupAction = 'create' }
        else {
            $backupHash = Get-FileHashHex $configBundleBackup
            if ($backupHash -ne $configHash -or $backupHash -eq $configPatchHash) { $configBackupAction = 'refresh' }
        }
    }

    Save-Snapshot $statePath
    $mainJsTarget = Join-Path $mainUiDir 'survival-log-thai-prototype.js'
    Save-Snapshot $mainJsTarget
    Save-Snapshot $sharedTargetJs
    Save-Snapshot $configBundle
    Save-Snapshot $configBundleBackup
    foreach ($plan in $pagePlans) {
        if ($plan.NeedsPatch) { Save-Snapshot $plan.Path; Save-Snapshot $plan.BackupPath }
    }

    try {
        foreach ($plan in $pagePlans) {
            if (-not $plan.NeedsPatch) { continue }
            if ($plan.BackupAction -ne 'none') { Write-AtomicBytes $plan.BackupPath $plan.OriginalBytes }
            Write-AtomicText $plan.Path $plan.PatchedText $utf8NoBom
        }
        Write-AtomicBytes $mainJsTarget ([System.IO.File]::ReadAllBytes($sourceJs))
        Write-AtomicBytes $sharedTargetJs ([System.IO.File]::ReadAllBytes($sharedSourceJs))
        if ($configBackupAction -ne 'none') { Write-AtomicBytes $configBundleBackup ([System.IO.File]::ReadAllBytes($configBundle)) }
        Write-AtomicBytes $configBundle ([System.IO.File]::ReadAllBytes($configBundlePatch))

        $statePages = @()
        foreach ($plan in $pagePlans) {
            $patchedHash = if ($plan.NeedsPatch) { Get-FileHashHex $plan.Path } else { $plan.PatchedHash }
            $statePages += [pscustomobject]@{ path=$plan.Relative; backup=$plan.BackupPath.Substring($webRoot.Length+1); baselineHash=$plan.BaselineHash; patchedHash=$patchedHash }
        }
        $baselineConfigHash = $configHash
        if ($knownInstalledConfig -and $stateConfig -and $stateConfig.baselineHash) { $baselineConfigHash = [string]$stateConfig.baselineHash }
        $stateObject = [pscustomobject]@{
            schema=1; installedAt=(Get-Date).ToUniversalTime().ToString('o')
            configBundle=[pscustomobject]@{ path=$configBundleName; backup=$configBundleBackup.Substring($webRoot.Length+1); baselineHash=$baselineConfigHash; patchedHash=$configPatchHash }
            mainRuntime=[pscustomobject]@{ path=$mainJsTarget.Substring($webRoot.Length+1); patchedHash=(Get-FileHashHex $mainJsTarget) }
            sharedRuntime=[pscustomobject]@{ path='survival-log-thai-webui.js'; patchedHash=(Get-FileHashHex $sharedTargetJs) }
            pages=$statePages
        }
        Write-AtomicText $statePath ($stateObject | ConvertTo-Json -Depth 6) $utf8NoBom
    } catch {
        try { Restore-Snapshots } catch { Write-Warning "rollback บางไฟล์ไม่สำเร็จ: $($_.Exception.Message)" }
        throw
    }

    Write-Host 'Thai prototype installed.'
    Write-Host "Shared System/UI Thai runtime installed across $($routePages.Count) HTML pages."
    Write-Host 'Native Unity English localization slot replaced with Thai (backup retained).'
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
