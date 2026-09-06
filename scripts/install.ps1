[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Codex-TerminalBar')
)

$ErrorActionPreference = 'Stop'
$upstreamRepository = 'https://github.com/openai/codex.git'
$upstreamTag = 'rust-v0.153.4'
$upstreamCommit = '3d2ee51ca2d5db578f328aa75e20aa22c0197c9a'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$patchPath = Join-Path $repositoryRoot 'patches/codex-terminal-bar-v0.153.4.patch'
$sourceRoot = Join-Path $InstallRoot 'source-v0.153.4'
$buildRoot = Join-Path $sourceRoot 'codex-rs'

function Assert-LastCommand([string]$Message) {
    if ($LASTEXITCODE -ne 0) {
        throw $Message
    }
}

function Test-ManagedBin([string]$PathEntry) {
    if ([string]::IsNullOrWhiteSpace($PathEntry)) {
        return $false
    }
    try {
        $normalizedEntry = [IO.Path]::GetFullPath($PathEntry).TrimEnd('\')
        $normalizedRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
        return $normalizedEntry.StartsWith(
            "$normalizedRoot\bin-",
            [StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {
        return $false
    }
}

function Set-CodexStatusLine {
    $configDirectory = Join-Path $env:USERPROFILE '.codex'
    $configPath = Join-Path $configDirectory 'config.toml'
    $statusLine = 'status_line = ["context-used", "five-hour-limit", "weekly-limit"]'
    $newline = [Environment]::NewLine

    New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    $content = if (Test-Path -LiteralPath $configPath) {
        Get-Content -LiteralPath $configPath -Raw
    }
    else {
        ''
    }

    if ($content) {
        $backupPath = "$configPath.codex-terminal-bar.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        Copy-Item -LiteralPath $configPath -Destination $backupPath
        Write-Host "Backed up Codex configuration to $backupPath"
    }

    $tuiSection = [regex]::Match($content, '(?ms)^\[tui\]\r?\n.*?(?=^\[|\z)')
    if ($tuiSection.Success) {
        $updatedSection = if ($tuiSection.Value -match '(?m)^status_line\s*=.*$') {
            [regex]::Replace(
                $tuiSection.Value,
                '(?m)^status_line\s*=.*$',
                $statusLine,
                1
            )
        }
        else {
            $tuiSection.Value.TrimEnd() + $newline + $statusLine + $newline + $newline
        }
        $content = $content.Remove($tuiSection.Index, $tuiSection.Length).Insert(
            $tuiSection.Index,
            $updatedSection
        )
    }
    else {
        $newSection = "[tui]$newline$statusLine$newline$newline"
        $nestedTuiSection = [regex]::Match($content, '(?m)^\[tui\.')
        if ([string]::IsNullOrWhiteSpace($content)) {
            $content = $newSection
        }
        elseif ($nestedTuiSection.Success) {
            $content = $content.Insert($nestedTuiSection.Index, $newSection)
        }
        else {
            $content = $content.TrimEnd() + $newline + $newline + $newSection
        }
    }

    $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($configPath, $content, $utf8WithoutBom)
    Write-Host "Configured the status line in $configPath"
}

foreach ($command in 'git', 'cargo', 'rustc') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found on PATH."
    }
}
if (-not (Test-Path -LiteralPath $patchPath)) {
    throw "Patch not found: $patchPath"
}

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot '.git'))) {
    & git clone --depth 1 --branch $upstreamTag $upstreamRepository $sourceRoot
    Assert-LastCommand 'Could not clone the Codex source repository.'
}

$currentCommit = (& git -C $sourceRoot rev-parse HEAD).Trim()
Assert-LastCommand 'Could not inspect the Codex source checkout.'
if ($currentCommit -ne $upstreamCommit) {
    throw "Expected Codex commit $upstreamCommit, found $currentCommit in $sourceRoot."
}

& git -C $sourceRoot apply --check $patchPath 2>$null
if ($LASTEXITCODE -eq 0) {
    & git -C $sourceRoot apply $patchPath
    Assert-LastCommand 'Could not apply the terminal bar patch.'
}
else {
    & git -C $sourceRoot apply --reverse --check $patchPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The source checkout is neither clean nor already patched. Inspect it before retrying.'
    }
    Write-Host 'The terminal bar patch is already applied.'
}

Push-Location $buildRoot
try {
    & cargo build -p codex-cli --bin codex
    Assert-LastCommand 'The Codex CLI build failed.'
    & cargo build -p codex-code-mode-host --bin codex-code-mode-host
    Assert-LastCommand 'The code-mode host build failed.'
}
finally {
    Pop-Location
}

$binRoot = Join-Path $InstallRoot "bin-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $binRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $buildRoot 'target/debug/codex.exe') -Destination $binRoot
Copy-Item -LiteralPath (Join-Path $buildRoot 'target/debug/codex-code-mode-host.exe') -Destination $binRoot

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ -and -not (Test-ManagedBin $_) })
[Environment]::SetEnvironmentVariable('Path', ((@($binRoot) + $pathEntries) -join ';'), 'User')
Set-CodexStatusLine

Write-Host ''
Write-Host "Installed Codex TerminalBar to $binRoot"
Write-Host 'Open a new terminal, then run: codex --version'
Write-Host 'Existing Codex sessions keep their current executable until they exit.'
