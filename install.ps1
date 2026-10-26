# NeNe Wire installer for PowerShell (Windows): installs nene-wire inside WSL and adds a `nene-wire` command for PowerShell and cmd.
#
#   irm https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main/install.ps1 | iex
#
# nene-wire is a Linux program, so it lives in WSL. This script runs install.sh inside your WSL distribution (which verifies the
# download against SHA256SUMS and installs ~/.local/bin/nene-wire there), then writes %LOCALAPPDATA%\nene-wire\bin\nene-wire.cmd,
# which starts it through wsl.exe, and adds that folder to your user PATH.
#
# Options (environment variables): NENE_WIRE_DISTRO picks a WSL distribution (default: your default one),
# NENE_WIRE_VERSION picks a release (default: the latest).
# To uninstall: delete %LOCALAPPDATA%\nene-wire, remove it from your user PATH, and run: wsl rm ~/.local/bin/nene-wire
#
# Kept to ASCII on purpose: Windows PowerShell 5.1 reads scripts without a BOM in the local code page.

function Install-NeNeWire {
    $ErrorActionPreference = 'Stop'
    $repo = 'https://raw.githubusercontent.com/hideyukiMORI/nene-wire/main'

    # Under `irm | iex`, `exit` would close the window; every failure returns from this function instead.
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'nene-wire install: WSL is not installed. Run "wsl --install", restart, and run this again.' -ForegroundColor Red
        return
    }
    $distroArgs = @()
    $distroOption = ''
    if ($env:NENE_WIRE_DISTRO) {
        $distroArgs = @('-d', $env:NENE_WIRE_DISTRO)
        $distroOption = " -d $env:NENE_WIRE_DISTRO"
    }
    # wsl.exe -l prints UTF-16; strip the NUL bytes before looking at it
    $distros = @((& wsl.exe -l -q) -replace "`0", '' | Where-Object { $_.Trim() })
    if ($distros.Count -eq 0) {
        Write-Host 'nene-wire install: no WSL distribution yet. Run "wsl --install -d Ubuntu", then run this again.' -ForegroundColor Red
        return
    }

    $version = ''
    if ($env:NENE_WIRE_VERSION) {
        $version = "NENE_WIRE_VERSION=$env:NENE_WIRE_VERSION "
    }
    & wsl.exe @distroArgs -e sh -c "curl -fsSL $repo/install.sh | ${version}bash"
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'nene-wire install: the installer inside WSL failed (see above). Nothing was added on the Windows side.' -ForegroundColor Red
        return
    }

    $bin = Join-Path $env:LOCALAPPDATA 'nene-wire\bin'
    New-Item -ItemType Directory -Force -Path $bin | Out-Null
    $launcher = Join-Path $bin 'nene-wire.cmd'
    # --cd ~ starts in the WSL home, so the path needs no shell to expand it
    Set-Content -Path $launcher -Encoding ASCII -Value @(
        '@echo off',
        "wsl.exe$distroOption --cd ~ -e .local/bin/nene-wire %*"
    )

    # NENE_WIRE_PATH_SCOPE exists only so the installer can be tested without touching the user PATH ('Process').
    $scope = 'User'
    if ($env:NENE_WIRE_PATH_SCOPE) {
        $scope = $env:NENE_WIRE_PATH_SCOPE
    }
    $path = [Environment]::GetEnvironmentVariable('Path', $scope)
    if ($null -eq $path) {
        $path = ''
    }
    if (-not (($path -split ';') -contains $bin)) {
        [Environment]::SetEnvironmentVariable('Path', (($path.TrimEnd(';') + ';' + $bin).TrimStart(';')), $scope)
        Write-Host "nene-wire install: added $bin to your $scope PATH"
    }
    if (-not (($env:Path -split ';') -contains $bin)) {
        $env:Path = $env:Path.TrimEnd(';') + ';' + $bin
    }

    Write-Host "nene-wire install: installed $launcher"
    Write-Host 'nene-wire install: run nene-wire here or in a new window (q quits; nene-wire --demo works without the network).'
    Write-Host "nene-wire install: for translation: wsl$distroOption -e sh -c `"curl -fsSL $repo/install-translator.sh | bash`""
}

Install-NeNeWire
