[CmdletBinding()]
param([string]$EngineRoot, [switch]$RegisterOnly, [switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
$projectPath = Join-Path $PSScriptRoot 'ShopSimulatorStoreManagem.uproject'
$association = (Get-Content -LiteralPath $projectPath -Raw | ConvertFrom-Json).EngineAssociation

function Test-CompatibleEngine([string]$Root) {
    if (-not $Root) { return $false }
    $versionPath = Join-Path $Root 'Engine\Build\Build.version'
    if (-not (Test-Path -LiteralPath $versionPath) -or -not (Test-Path -LiteralPath (Join-Path $Root 'Engine\Binaries\Win64\UnrealEditor.exe'))) { return $false }
    try {
        $version = Get-Content -LiteralPath $versionPath -Raw | ConvertFrom-Json
        return "$($version.MajorVersion).$($version.MinorVersion)" -eq $association
    } catch { return $false }
}

$candidates = @()
if ($EngineRoot) {
    if (-not (Test-CompatibleEngine $EngineRoot)) { throw "EngineRoot must point to an installed Unreal Engine $association." }
    $candidates += $EngineRoot
} else {
    $launcherFile = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if (Test-Path -LiteralPath $launcherFile) {
        $launcher = Get-Content -LiteralPath $launcherFile -Raw | ConvertFrom-Json
        $candidates += @($launcher.InstallationList | ForEach-Object { $_.InstallLocation })
    }
    foreach ($key in @("HKLM:\SOFTWARE\EpicGames\Unreal Engine\$association", "HKLM:\SOFTWARE\WOW6432Node\EpicGames\Unreal Engine\$association")) {
        $installation = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($installation) { $candidates += $installation.InstalledDirectory }
    }
    $builds = Get-ItemProperty -LiteralPath 'HKCU:\Software\Epic Games\Unreal Engine\Builds' -ErrorAction SilentlyContinue
    if ($builds) {
        $candidates += @($builds.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object { $_.Value })
    }
    $candidates += Join-Path $env:ProgramFiles "Epic Games\UE_$association"
}
$resolvedRoot = $candidates | Where-Object { Test-CompatibleEngine $_ } | Select-Object -First 1
if (-not $resolvedRoot) { throw "Unreal Engine $association not found. Install it or pass -EngineRoot 'D:\Epic Games\UE_$association'." }
$resolvedRoot = (Resolve-Path -LiteralPath $resolvedRoot).Path
Write-Host "Unreal Engine $association found: $resolvedRoot"
if ($CheckOnly) { return }

$buildsKey = 'HKCU:\Software\Epic Games\Unreal Engine\Builds'
New-Item -Path $buildsKey -Force | Out-Null
New-ItemProperty -LiteralPath $buildsKey -Name $association -Value $resolvedRoot -PropertyType String -Force | Out-Null
if ((Get-ItemPropertyValue -LiteralPath $buildsKey -Name $association) -ne $resolvedRoot) { throw 'Engine registration verification failed.' }
Write-Host 'Engine registered for the current user.'
if (-not $RegisterOnly) {
    Start-Process -FilePath (Join-Path $resolvedRoot 'Engine\Binaries\Win64\UnrealEditor.exe') -ArgumentList ('"{0}"' -f $projectPath)
}
