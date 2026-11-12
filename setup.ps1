[CmdletBinding()]
param([string]$EngineRoot)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Open-Project.ps1') -EngineRoot $EngineRoot -RegisterOnly
Push-Location $PSScriptRoot
try {
    git config core.hooksPath .githooks
    if ($LASTEXITCODE -ne 0) { throw 'Failed to enable Git hooks.' }
    git lfs install
    if ($LASTEXITCODE -ne 0) { throw 'Failed to configure Git LFS.' }
    Write-Host 'Hooks and Git LFS enabled.'
} finally {
    Pop-Location
}
