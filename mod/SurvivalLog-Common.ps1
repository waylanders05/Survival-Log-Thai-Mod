# Shared helpers for the Survival Log Thai Mod installer and uninstaller.
# Keep this file Windows PowerShell 5.1 compatible.

function Get-RelativePathCompat([string]$BasePath, [string]$TargetPath) {
    $baseUri = New-Object System.Uri(($BasePath.TrimEnd('\') + '\'))
    $targetUri = New-Object System.Uri($TargetPath)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/','\')
}

function Test-SurvivalLogDir([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $mainPackage = Join-Path $Path 'SurvivalLog_Data\StreamingAssets\PackageManifest\MainPackage'
    $mainUi = Join-Path $Path 'SurvivalLog_Data\StreamingAssets\WebUI\UI\MainUI\MainUI.html'
    return (Test-Path -LiteralPath $mainPackage -PathType Container) -and
           (Test-Path -LiteralPath $mainUi -PathType Leaf)
}

function Find-SurvivalLogDir {
    $roots = New-Object 'System.Collections.Generic.List[string]'
    $addRoot = {
        param([string]$Candidate)
        if ([string]::IsNullOrWhiteSpace($Candidate)) { return }
        try { $full = [System.IO.Path]::GetFullPath($Candidate) } catch { return }
        if ((Test-Path -LiteralPath $full -PathType Container) -and -not $roots.Contains($full)) {
            [void]$roots.Add($full)
        }
    }

    foreach ($key in @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )) {
        try { & $addRoot (Get-ItemPropertyValue -LiteralPath $key -Name SteamPath -ErrorAction Stop) } catch {}
        try { & $addRoot (Get-ItemPropertyValue -LiteralPath $key -Name InstallPath -ErrorAction Stop) } catch {}
    }

    & $addRoot 'C:\Program Files (x86)\Steam'
    & $addRoot 'C:\Program Files\Steam'
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        foreach ($name in @('SteamLibrary','Steam','Games\SteamLibrary','Games\Steam')) {
            & $addRoot (Join-Path $drive.Root $name)
        }
    }

    # Steam libraryfolders.vdf stores custom library roots under the main Steam root.
    foreach ($root in @($roots.ToArray())) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf -PathType Leaf)) { continue }
        try {
            $vdfText = [System.IO.File]::ReadAllText($vdf)
            foreach ($match in [regex]::Matches($vdfText, '"path"\s+"([^"]+)"')) {
                & $addRoot ($match.Groups[1].Value -replace '\\\\','\')
            }
        } catch {}
    }

    foreach ($root in $roots) {
        $candidate = Join-Path $root 'steamapps\common\Survival Log'
        if (Test-SurvivalLogDir $candidate) { return [System.IO.Path]::GetFullPath($candidate) }
    }
    return $null
}

function Select-SurvivalLogDir([string]$RequestedPath) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        try {
            $full = [System.IO.Path]::GetFullPath($RequestedPath)
            if (Test-SurvivalLogDir $full) { return $full }
        } catch {}
    } else {
        $found = Find-SurvivalLogDir
        if ($found) { return $found }
    }

    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop } catch {
        throw 'ไม่สามารถเปิดหน้าต่างเลือกโฟลเดอร์ได้ กรุณาระบุ -GameDir ด้วยตนเอง'
    }
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'เลือกโฟลเดอร์เกม Survival Log'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            $selected = [System.IO.Path]::GetFullPath($dialog.SelectedPath)
            if (Test-SurvivalLogDir $selected) { return $selected }
        } catch {}
    }
    throw 'ไม่พบโฟลเดอร์เกม Survival Log หรือเลือกโฟลเดอร์ไม่ถูกต้อง'
}

function Get-FileHashHex([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-AtomicBytes([string]$Path, [byte[]]$Bytes) {
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $temp = "$Path.thai-prototype.tmp.$([Guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllBytes($temp, $Bytes)
        Move-Item -LiteralPath $temp -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
}

function Write-AtomicText([string]$Path, [string]$Text, [System.Text.Encoding]$Encoding) {
    Write-AtomicBytes $Path $Encoding.GetBytes($Text)
}

