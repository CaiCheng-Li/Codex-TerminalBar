[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Codex-TerminalBar')
)

$ErrorActionPreference = 'Stop'
$normalizedRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')

function Test-ManagedBin([string]$PathEntry) {
    if ([string]::IsNullOrWhiteSpace($PathEntry)) {
        return $false
    }
    try {
        $normalizedEntry = [IO.Path]::GetFullPath($PathEntry).TrimEnd('\')
        return $normalizedEntry.StartsWith(
            "$normalizedRoot\bin-",
            [StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {
        return $false
    }
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ -and -not (Test-ManagedBin $_) })
[Environment]::SetEnvironmentVariable('Path', ($pathEntries -join ';'), 'User')

Write-Host 'Removed Codex TerminalBar executables from the user PATH.'
Write-Host 'Open a new terminal to use the standard Codex CLI.'
Write-Host "Build files remain in $InstallRoot and can be removed after all Codex sessions exit."
