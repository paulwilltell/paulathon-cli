<#
.SYNOPSIS
    Test script for AstraShell module

.DESCRIPTION
    Validates that AstraShell loads correctly and basic functionality works.
    Run this script before deploying to ensure all components are working.

.NOTES
    Requires: PowerShell 7.0+
#>

[CmdletBinding()]
param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$testsPassed = 0
$testsFailed = 0

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║              AstraShell Module Test Suite                      ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

function Test-Step {
    param(
        [string]$TestName,
        [scriptblock]$TestCode
    )

    Write-Host "`n[TEST] $TestName" -ForegroundColor Yellow
    try {
        & $TestCode
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        $script:testsPassed++
        return $true
    }
    catch {
        Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
        Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
        $script:testsFailed++
        return $false
    }
}

# Test 1: PowerShell Version
Test-Step "PowerShell Version Check" {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7.0 or higher required. Current version: $($PSVersionTable.PSVersion)"
    }
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
}

# Test 2: Module Files Exist
Test-Step "Module Files Exist" {
    $modulePath = $PSScriptRoot
    $requiredFiles = @(
        'AstraShell.psd1',
        'AstraShell.psm1',
        'config.jsonc',
        'Plugins\AstraShell.NLParser.psm1',
        'Plugins\AstraShell.Sentry.psm1',
        'Plugins\AstraShell.RAG.psm1',
        'Plugins\AstraShell.Security.psm1'
    )

    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $modulePath $file
        if (-not (Test-Path $filePath)) {
            throw "Required file not found: $file"
        }
    }
    Write-Host "  All required files present" -ForegroundColor Gray
}

# Test 3: Configuration File Valid JSON
Test-Step "Configuration File Parsing" {
    $configPath = Join-Path $PSScriptRoot "config.jsonc"
    $configContent = Get-Content $configPath -Raw
    # Remove comments for JSON parsing
    $configContent = $configContent -replace '(?m)^\s*//.*$', '' -replace '(?ms)/\*.*?\*/', ''
    $config = $configContent | ConvertFrom-Json

    if (-not $config.Features) {
        throw "Config missing Features section"
    }
    if (-not $config.RAG) {
        throw "Config missing RAG section"
    }
    Write-Host "  Configuration file is valid" -ForegroundColor Gray
}

# Test 4: Module Import
Test-Step "Module Import" {
    Import-Module "$PSScriptRoot\AstraShell.psd1" -Force -ErrorAction Stop
    $module = Get-Module AstraShell
    if (-not $module) {
        throw "Module failed to import"
    }
    Write-Host "  Module loaded: $($module.Name) v$($module.Version)" -ForegroundColor Gray
}

# Test 5: Exported Functions
Test-Step "Exported Functions Available" {
    $expectedFunctions = @(
        'Invoke-Astra',
        'Start-AstraShell',
        'Stop-AstraShell',
        'Get-AstraConfig',
        'Set-AstraConfig',
        'Get-AstraSuggestion',
        'Enable-AstraPlugin',
        'Disable-AstraPlugin',
        'Get-AstraPlugin',
        'Invoke-AstraQuery'
    )

    $module = Get-Module AstraShell
    foreach ($func in $expectedFunctions) {
        if ($func -notin $module.ExportedFunctions.Keys) {
            throw "Expected function not exported: $func"
        }
    }
    Write-Host "  All $($expectedFunctions.Count) expected functions exported" -ForegroundColor Gray
}

# Test 6: Alias Available
Test-Step "Alias 'astra' Available" {
    $module = Get-Module AstraShell
    if ('astra' -notin $module.ExportedAliases.Keys) {
        throw "Alias 'astra' not exported"
    }
    Write-Host "  Alias 'astra' is available" -ForegroundColor Gray
}

# Test 7: Initialization
Test-Step "AstraShell Initialization" {
    Start-AstraShell
    Write-Host "  AstraShell initialized successfully" -ForegroundColor Gray
}

# Test 8: Get Configuration
Test-Step "Get Configuration" {
    $config = Get-AstraConfig
    if (-not $config) {
        throw "Failed to get configuration"
    }
    if (-not $config.Features) {
        throw "Configuration missing Features section"
    }
    Write-Host "  Configuration retrieved successfully" -ForegroundColor Gray
}

# Test 9: Get Specific Config Section
Test-Step "Get Specific Config Section" {
    $ragConfig = Get-AstraConfig -Section "RAG"
    if (-not $ragConfig) {
        throw "Failed to get RAG configuration section"
    }
    if ($null -eq $ragConfig.MaxFileSize) {
        throw "RAG config missing MaxFileSize"
    }
    Write-Host "  RAG config: MaxFileSize = $($ragConfig.MaxFileSize) bytes" -ForegroundColor Gray
}

# Test 10: Plugin Discovery
Test-Step "Plugin Discovery" {
    Get-AstraPlugin
    Write-Host "  Plugins discovered successfully" -ForegroundColor Gray
}

# Test 11: Get Suggestions
Test-Step "Get Suggestions" {
    $suggestions = Get-AstraSuggestion -Count 3
    # Suggestions may be empty if no context, that's OK
    Write-Host "  Suggestions function executed (returned $($suggestions.Count) suggestions)" -ForegroundColor Gray
}

# Test 12: Natural Language Parsing (NLParser Plugin)
Test-Step "Natural Language Parsing" {
    # This tests if the NLParser plugin is loaded and working
    $result = Invoke-Astra "show git status" -NoConfirm -ErrorAction Stop 2>&1
    # We don't care if git is actually installed, just that the command parses
    Write-Host "  NL parsing executed successfully" -ForegroundColor Gray
}

# Test 13: Security Plugin Functions
Test-Step "Security Plugin Functions Available" {
    if (Get-Command Invoke-AstraSecurityCheck -ErrorAction SilentlyContinue) {
        Write-Host "  Security plugin functions available" -ForegroundColor Gray
    }
    else {
        throw "Security plugin functions not available"
    }
}

# Test 14: Sentry Plugin Functions
Test-Step "Sentry Plugin Functions Available" {
    if (Get-Command Get-AstraSentryStatus -ErrorAction SilentlyContinue) {
        Write-Host "  Sentry plugin functions available" -ForegroundColor Gray
    }
    else {
        throw "Sentry plugin functions not available"
    }
}

# Test 15: RAG Plugin Functions
Test-Step "RAG Plugin Functions Available" {
    if (Get-Command Update-AstraIndex -ErrorAction SilentlyContinue) {
        Write-Host "  RAG plugin functions available" -ForegroundColor Gray
    }
    else {
        throw "RAG plugin functions not available"
    }
}

# Test 16: Set Configuration
Test-Step "Set Configuration Value" {
    Set-AstraConfig -Section "Advanced" -Key "LogLevel" -Value "Verbose"
    $config = Get-AstraConfig -Section "Advanced"
    if ($config.LogLevel -ne "Verbose") {
        throw "Configuration not updated correctly"
    }
    # Reset to default
    Set-AstraConfig -Section "Advanced" -Key "LogLevel" -Value "Info"
    Write-Host "  Configuration update successful" -ForegroundColor Gray
}

# Test 17: Cleanup
Test-Step "Module Cleanup" {
    Stop-AstraShell
    Write-Host "  AstraShell stopped successfully" -ForegroundColor Gray
}

# Summary
Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                       Test Summary                              ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "  Total Tests: $($testsPassed + $testsFailed)" -ForegroundColor White
Write-Host "  ✓ Passed: $testsPassed" -ForegroundColor Green
Write-Host "  ✗ Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "🎉 All tests passed! AstraShell is ready to use." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "⚠️ Some tests failed. Please review the errors above." -ForegroundColor Yellow
    exit 1
}
