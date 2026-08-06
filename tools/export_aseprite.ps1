[CmdletBinding(DefaultParameterSetName = "Export")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Check")]
    [switch]$CheckOnly,

    [Parameter(Mandatory = $true, ParameterSetName = "Export")]
    [string]$Source,

    [Parameter(Mandatory = $true, ParameterSetName = "Export")]
    [string]$AssetPath,

    [Parameter(ParameterSetName = "Export")]
    [string]$Name,

    [Parameter(ParameterSetName = "Export")]
    [string]$Tag,

    [Parameter(ParameterSetName = "Export")]
    [ValidateRange(1, 64)]
    [int]$Columns = 8,

    [Parameter(ParameterSetName = "Check")]
    [Parameter(ParameterSetName = "Export")]
    [string]$AsepritePath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

function Find-Aseprite {
    param([string]$ExplicitPath)

    $candidates = New-Object System.Collections.Generic.List[object]

    if ($ExplicitPath) {
        $candidates.Add([pscustomobject]@{ Path = $ExplicitPath; Source = "command parameter" })
    }

    if ($env:ASEPRITE_PATH) {
        $candidates.Add([pscustomobject]@{ Path = $env:ASEPRITE_PATH; Source = "ASEPRITE_PATH" })
    }

    foreach ($commandName in @("aseprite", "Aseprite.exe")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command -and $command.Source) {
            $candidates.Add([pscustomobject]@{ Path = $command.Source; Source = "PATH" })
        }
    }

    $registryPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($entry in @(Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue | Where-Object {
        $_.PSObject.Properties["DisplayName"] -and $_.DisplayName -match "^Aseprite"
    })) {
        if ($entry.PSObject.Properties["InstallLocation"] -and $entry.InstallLocation) {
            $candidates.Add([pscustomobject]@{ Path = (Join-Path $entry.InstallLocation "Aseprite.exe"); Source = "Windows install registry" })
        }
        if ($entry.PSObject.Properties["DisplayIcon"] -and $entry.DisplayIcon) {
            $displayIconPath = ([string]$entry.DisplayIcon).Trim('"').Split(",")[0]
            $candidates.Add([pscustomobject]@{ Path = $displayIconPath; Source = "Windows install registry" })
        }
    }

    foreach ($candidatePath in @(
        (Join-Path $env:ProgramFiles "Aseprite\Aseprite.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Aseprite\Aseprite.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Aseprite\Aseprite.exe"),
        (Join-Path $env:USERPROFILE "scoop\apps\aseprite\current\Aseprite.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps\common\Aseprite\Aseprite.exe"),
        (Join-Path $env:ProgramFiles "Steam\steamapps\common\Aseprite\Aseprite.exe")
    )) {
        if ($candidatePath) {
            $candidates.Add([pscustomobject]@{ Path = $candidatePath; Source = "known install location" })
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate.Path -and (Test-Path -LiteralPath $candidate.Path -PathType Leaf)) {
            $resolvedPath = (Resolve-Path -LiteralPath $candidate.Path).Path
            return [pscustomobject]@{
                Path = $resolvedPath
                Source = $candidate.Source
                Version = ((Get-Item -LiteralPath $resolvedPath).VersionInfo.ProductVersion -replace ",", ".")
            }
        }
    }

    throw "Aseprite.exe was not found. Pass -AsepritePath or set ASEPRITE_PATH for the current shell."
}

function ConvertTo-ProcessArgument {
    param([string]$Value)

    if ($Value.Contains('"')) {
        throw "A command argument contains an unsupported quote character: $Value"
    }
    if ($Value -match "\s") {
        return '"' + $Value + '"'
    }
    return $Value
}

function Invoke-Aseprite {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    $processArguments = @($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ })
    $process = Start-Process `
        -FilePath $Executable `
        -ArgumentList $processArguments `
        -Wait `
        -PassThru `
        -WindowStyle Hidden

    if ($process.ExitCode -ne 0) {
        throw "Aseprite export failed with exit code $($process.ExitCode)."
    }
}

function Resolve-ProjectChildPath {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Label
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "$Label must be a project-relative path."
    }

    $normalizedRelativePath = $RelativePath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $resolvedChild = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $normalizedRelativePath))
    $requiredPrefix = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar

    if (-not $resolvedChild.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must stay inside $resolvedRoot."
    }

    return $resolvedChild
}

$aseprite = Find-Aseprite -ExplicitPath $AsepritePath

if ($CheckOnly) {
    Write-Output "Aseprite is ready."
    Write-Output "Version: $($aseprite.Version)"
    Write-Output "Discovery: $($aseprite.Source)"
    Write-Output "Executable: $($aseprite.Path)"
    Write-Output "Godot image root: $(Join-Path $projectRoot 'art\images')"
    exit 0
}

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$sourceExtension = [System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
if ($sourceExtension -notin @(".ase", ".aseprite")) {
    throw "Source must be an .ase or .aseprite file."
}

if (-not $Name) {
    $Name = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
}
if ($Name -cnotmatch "^[a-z0-9][a-z0-9_]*$") {
    throw "Name must use lowercase ASCII snake_case."
}

$assetPathNormalized = $AssetPath.Replace("\", "/").Trim("/")
if (-not $assetPathNormalized -or $assetPathNormalized -cnotmatch "^[a-z0-9][a-z0-9_/]*$") {
    throw "AssetPath must use lowercase ASCII snake_case segments."
}

$imageRoot = Join-Path $projectRoot "art\images"
$manifestRoot = Join-Path $projectRoot "art\manifests"
$imageTarget = Resolve-ProjectChildPath -Root $imageRoot -RelativePath $assetPathNormalized -Label "AssetPath"
$manifestTarget = Resolve-ProjectChildPath -Root $manifestRoot -RelativePath $assetPathNormalized -Label "AssetPath"
$frameTarget = Join-Path $imageTarget "frames"

$overviewFileName = "${Name}_overview.png"
$previewFileName = "${Name}_preview.gif"
$sheetDataFileName = "${Name}_aseprite_sheet.json"
$exportManifestFileName = "${Name}_aseprite_export.json"

$existingOutputs = @()
if (Test-Path -LiteralPath $frameTarget) {
    $existingOutputs += @(Get-ChildItem -LiteralPath $frameTarget -Filter "${Name}_frame_*.png" -File -ErrorAction SilentlyContinue)
}
foreach ($path in @(
    (Join-Path $imageTarget $overviewFileName),
    (Join-Path $imageTarget $previewFileName),
    (Join-Path $manifestTarget $sheetDataFileName),
    (Join-Path $manifestTarget $exportManifestFileName)
)) {
    if (Test-Path -LiteralPath $path) {
        $existingOutputs += Get-Item -LiteralPath $path
    }
}
if ($existingOutputs.Count -gt 0) {
    throw "Export target already contains '$Name' outputs. Use a new versioned AssetPath or Name so confirmed art is not overwritten."
}

$tempBase = Join-Path $projectRoot ".codex_tmp"
New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
$tempRoot = Join-Path $tempBase ("aseprite_export_" + [System.Guid]::NewGuid().ToString("N"))
$tempFrames = Join-Path $tempRoot "frames"
New-Item -ItemType Directory -Path $tempFrames -Force | Out-Null

try {
    $rawFramePattern = Join-Path $tempFrames "frame_{frame1}.png"
    $tempOverview = Join-Path $tempRoot $overviewFileName
    $tempPreview = Join-Path $tempRoot $previewFileName
    $tempSheetData = Join-Path $tempRoot $sheetDataFileName
    $decodedFramesDirectory = Join-Path $tempRoot "decoded_gif_frames"
    $decodedFramePattern = Join-Path $decodedFramesDirectory "decoded_{frame1}.png"
    $decodedOverview = Join-Path $tempRoot "decoded_gif_overview.png"
    $decodedSheetData = Join-Path $tempRoot "decoded_gif_sheet.json"
    New-Item -ItemType Directory -Path $decodedFramesDirectory -Force | Out-Null

    $selectionArguments = @("--batch", "--noinapp", $sourcePath)
    if ($Tag) {
        $selectionArguments += @("--tag", $Tag)
    }

    Invoke-Aseprite -Executable $aseprite.Path -Arguments ($selectionArguments + @("--save-as", $rawFramePattern))
    Invoke-Aseprite -Executable $aseprite.Path -Arguments ($selectionArguments + @(
        "--sheet", $tempOverview,
        "--data", $tempSheetData,
        "--format", "json-array",
        "--sheet-type", "rows",
        "--sheet-columns", [string]$Columns
    ))
    Invoke-Aseprite -Executable $aseprite.Path -Arguments ($selectionArguments + @("--save-as", $tempPreview))
    Invoke-Aseprite -Executable $aseprite.Path -Arguments @(
        "--batch", "--noinapp", $tempPreview,
        "--save-as", $decodedFramePattern
    )
    Invoke-Aseprite -Executable $aseprite.Path -Arguments @(
        "--batch", "--noinapp", $tempPreview,
        "--sheet", $decodedOverview,
        "--data", $decodedSheetData,
        "--format", "json-array",
        "--sheet-type", "rows",
        "--sheet-columns", [string]$Columns
    )

    $rawFrames = @(Get-ChildItem -LiteralPath $tempFrames -Filter "frame_*.png" -File | Sort-Object {
        if ($_.BaseName -match "_(\d+)$") { [int]$Matches[1] } else { [int]::MaxValue }
    })
    if ($rawFrames.Count -eq 0) {
        throw "Aseprite produced no frame PNG files. Check the selected tag."
    }
    foreach ($requiredFile in @($tempOverview, $tempPreview, $tempSheetData, $decodedOverview, $decodedSheetData)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf) -or (Get-Item -LiteralPath $requiredFile).Length -eq 0) {
            throw "Aseprite did not produce a valid output: $requiredFile"
        }
    }

    $sheetData = Get-Content -LiteralPath $tempSheetData -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($sheetData.frames).Count -ne $rawFrames.Count) {
        throw "Frame PNG count does not match Aseprite sheet metadata."
    }

    $decodedFrames = @(Get-ChildItem -LiteralPath $decodedFramesDirectory -Filter "decoded_*.png" -File | Sort-Object {
        if ($_.BaseName -match "_(\d+)$") { [int]$Matches[1] } else { [int]::MaxValue }
    })
    $decodedData = Get-Content -LiteralPath $decodedSheetData -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($decodedFrames.Count -ne $rawFrames.Count -or @($decodedData.frames).Count -ne $rawFrames.Count) {
        throw "GIF verification failed: decoded frame count differs from the source frame sequence."
    }
    for ($index = 0; $index -lt $rawFrames.Count; $index++) {
        $sourceHash = (Get-FileHash -LiteralPath $rawFrames[$index].FullName -Algorithm SHA256).Hash
        $decodedHash = (Get-FileHash -LiteralPath $decodedFrames[$index].FullName -Algorithm SHA256).Hash
        if ($sourceHash -ne $decodedHash) {
            throw "GIF verification failed: decoded frame $($index + 1) differs from its source PNG."
        }
        if ([int]$sheetData.frames[$index].duration -ne [int]$decodedData.frames[$index].duration) {
            throw "GIF verification failed: frame $($index + 1) duration differs from Aseprite metadata."
        }
    }

    New-Item -ItemType Directory -Path $frameTarget -Force | Out-Null
    New-Item -ItemType Directory -Path $manifestTarget -Force | Out-Null

    $padding = [Math]::Max(3, ([string]$rawFrames.Count).Length)
    $manifestFrames = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $rawFrames.Count; $index++) {
        $frameNumber = ($index + 1).ToString("D$padding")
        $frameFileName = "${Name}_frame_${frameNumber}.png"
        $frameDestination = Join-Path $frameTarget $frameFileName
        Move-Item -LiteralPath $rawFrames[$index].FullName -Destination $frameDestination

        $manifestFrames.Add([ordered]@{
            index = $index + 1
            duration_ms = [int]$sheetData.frames[$index].duration
            path = "res://art/images/$assetPathNormalized/frames/$frameFileName"
            sha256 = (Get-FileHash -LiteralPath $frameDestination -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }

    $overviewDestination = Join-Path $imageTarget $overviewFileName
    $previewDestination = Join-Path $imageTarget $previewFileName
    $sheetDataDestination = Join-Path $manifestTarget $sheetDataFileName
    Move-Item -LiteralPath $tempOverview -Destination $overviewDestination
    Move-Item -LiteralPath $tempPreview -Destination $previewDestination
    Move-Item -LiteralPath $tempSheetData -Destination $sheetDataDestination

    $exportManifest = [ordered]@{
        schema_version = 1
        source = [ordered]@{
            file_name = [System.IO.Path]::GetFileName($sourcePath)
            sha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
            tag = if ($Tag) { $Tag } else { $null }
        }
        exporter = [ordered]@{
            name = "Aseprite"
            version = $aseprite.Version
        }
        asset_path = $assetPathNormalized
        frame_count = $manifestFrames.Count
        frames = $manifestFrames
        overview = "res://art/images/$assetPathNormalized/$overviewFileName"
        preview_gif = "res://art/images/$assetPathNormalized/$previewFileName"
        sheet_data = "res://art/manifests/$assetPathNormalized/$sheetDataFileName"
        verification = [ordered]@{
            gif_frame_count_match = $true
            gif_frame_pixels_match = $true
            gif_frame_durations_match = $true
        }
    }
    $exportManifestPath = Join-Path $manifestTarget $exportManifestFileName
    $exportManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $exportManifestPath -Encoding UTF8

    Write-Output "Aseprite export completed."
    Write-Output "Frames: $($manifestFrames.Count)"
    Write-Output "Images: $imageTarget"
    Write-Output "Manifest: $exportManifestPath"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedTempBase = [System.IO.Path]::GetFullPath($tempBase).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
        $requiredTempPrefix = $resolvedTempBase + [System.IO.Path]::DirectorySeparatorChar
        if ($resolvedTempRoot.StartsWith($requiredTempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force
        }
    }
}
