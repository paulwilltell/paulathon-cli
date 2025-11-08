<#
.SYNOPSIS
    AstraShell Installation Script

.DESCRIPTION
    Installs AstraShell to the user's PowerShell modules directory
    and optionally adds it to the PowerShell profile for auto-loading.

.PARAMETER SystemWide
    Install for all users (requires Administrator privileges)

.PARAMETER AddToProfile
    Add AstraShell to PowerShell profile for auto-loading

.EXAMPLE
    .\Install.ps1

.EXAMPLE
    .\Install.ps1 -AddToProfile

.EXAMPLE
    .\Install.ps1 -SystemWide -AddToProfile
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SystemWide,

    [Parameter()]
    [switch]$AddToProfile
)

$ErrorActionPreference = 'Stop'

Write-Host @"

    █████╗ ███████╗████████╗██████╗  █████╗ ███████╗██╗  ██╗███████╗██╗     ██╗
   ██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██╔════╝██║     ██║
   ███████║███████╗   ██║   ██████╔╝███████║███████╗███████║█████╗  ██║     ██║
   ██╔══██║╚════██║   ██║   ██╔══██╗██╔══██║╚════██║██╔══██║██╔══╝  ██║     ██║
   ██║  ██║███████║   ██║   ██║  ██║██║  ██║███████║██║  ██║███████╗███████╗███████╗
   ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝

   Advanced PowerShell CLI with AI-Enhanced Capabilities

"@ -ForegroundColor Cyan

Write-Host "Starting installation...`n" -ForegroundColor White

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "AstraShell requires PowerShell 7.0 or higher."
    Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "`nDownload PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Cyan
    exit 1
}

# Determine installation path
if ($SystemWide) {
    # Check for admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Error "System-wide installation requires Administrator privileges. Please run as Administrator or omit -SystemWide flag."
        exit 1
    }

    $modulePath = "$env:ProgramFiles\PowerShell\Modules"
    Write-Host "📦 Installing system-wide for all users..." -ForegroundColor Cyan
} else {
    $modulePath = "$HOME\Documents\PowerShell\Modules"
    Write-Host "📦 Installing for current user..." -ForegroundColor Cyan
}

$targetPath = Join-Path $modulePath "AstraShell"

# Create module directory if it doesn't exist
if (-not (Test-Path $modulePath)) {
    Write-Host "  Creating module directory: $modulePath" -ForegroundColor Gray
    New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
}

# Get source path
$sourcePath = $PSScriptRoot
if (-not (Test-Path (Join-Path $sourcePath "AstraShell.psd1"))) {
    Write-Error "Installation script must be run from the AstraShell directory"
    exit 1
}

# Copy module files
Write-Host "  Copying module files to: $targetPath" -ForegroundColor Gray

if (Test-Path $targetPath) {
    Write-Warning "  AstraShell is already installed. Updating..."
    Remove-Item -Path $targetPath -Recurse -Force
}

Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force

Write-Host "  ✓ Module files copied" -ForegroundColor Green

# Verify installation
Write-Host "`n🔍 Verifying installation..." -ForegroundColor Cyan

Import-Module AstraShell -Force -ErrorAction Stop

$module = Get-Module AstraShell
if ($module) {
    Write-Host "  ✓ AstraShell $($module.Version) installed successfully!" -ForegroundColor Green
} else {
    Write-Error "  ✗ Installation verification failed"
    exit 1
}

# Add to profile if requested
if ($AddToProfile) {
    Write-Host "`n📝 Adding to PowerShell profile..." -ForegroundColor Cyan

    if (-not (Test-Path $PROFILE)) {
        Write-Host "  Creating profile file: $PROFILE" -ForegroundColor Gray
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }

    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

    if ($profileContent -notmatch 'Import-Module AstraShell') {
        @"

# AstraShell - Advanced PowerShell CLI
Import-Module AstraShell
Start-AstraShell
"@ | Add-Content -Path $PROFILE

        Write-Host "  ✓ Added to profile" -ForegroundColor Green
        Write-Host "    AstraShell will auto-load in new PowerShell sessions" -ForegroundColor Gray
    } else {
        Write-Host "  ✓ Already in profile" -ForegroundColor Yellow
    }
}

# Display next steps
Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                    Installation Complete! 🎉                   ║
╚════════════════════════════════════════════════════════════════╝

Next Steps:

1. Start AstraShell (if not already running):
   Start-AstraShell

2. Try a natural language command:
   astra "find all .ps1 files"

3. Get intelligent suggestions:
   Get-AstraSuggestion

4. Configure RAG indexing paths in:
   $targetPath\config.jsonc

5. Build your local index:
   Update-AstraIndex

6. View all available commands:
   Get-Command -Module AstraShell

📚 Full documentation: $targetPath\README.md

💡 Quick help: Get-Help Invoke-Astra -Full

"@ -ForegroundColor White

Write-Host "Happy Shell-ing with AstraShell! 🚀" -ForegroundColor Cyan
Write-Host ""
