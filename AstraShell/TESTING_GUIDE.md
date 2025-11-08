# AstraShell Testing Guide

## Quick Test (Windows PowerShell 7+)

### 1. Run the Test Suite
```powershell
cd AstraShell
.\Test-AstraShell.ps1
```

This will run 17 automated tests covering:
- Module loading
- Plugin discovery
- Configuration management
- Basic functionality
- All exported functions

### 2. Manual Smoke Tests

After the automated tests pass, perform these manual tests:

#### Test Natural Language Commands
```powershell
# Import the module
Import-Module .\AstraShell.psd1

# Start AstraShell
Start-AstraShell

# Test basic NL command
astra "show git status"

# Test file search
astra "find all .ps1 files"

# Test system analysis
astra "analyze system resources"
```

#### Test Intelligent Suggestions
```powershell
# Get context-based suggestions
Get-AstraSuggestion

# Navigate to a Git repo and try again
cd C:\YourGitRepo
Get-AstraSuggestion
```

#### Test System Sentry
```powershell
# Start the sentry
Start-AstraSentry

# Check system status
Get-AstraSentryStatus

# Perform health check
Invoke-AstraSentryCheck

# Stop sentry
Stop-AstraSentry
```

#### Test RAG (File Indexing)
```powershell
# Configure paths to index
Set-AstraConfig -Section "RAG" -Key "IndexPaths" -Value @("C:\Projects")

# Build index
Update-AstraIndex

# View index stats
Get-AstraIndexStats

# Search your code
Search-AstraIndex -Query "function" -MaxResults 5

# Test with content preview
Search-AstraIndex -Query "authentication" -ShowContent
```

#### Test Security Features
```powershell
# Test domain safety check (no API key needed for basic tests)
Test-AstraDomainSafety "https://github.com"

# Test script security analysis
# Create a test script with suspicious content
@'
Remove-Item C:\Test\* -Recurse -Force
'@ | Set-Content TestScript.ps1

Test-AstraScriptSecurity ".\TestScript.ps1"

# Clean up
Remove-Item TestScript.ps1
```

#### Test Configuration Management
```powershell
# View all configuration
Get-AstraConfig

# View specific section
Get-AstraConfig -Section "Sentry"

# Update a value
Set-AstraConfig -Section "Sentry" -Key "CPUThreshold" -Value 90

# Verify change
Get-AstraConfig -Section "Sentry"
```

#### Test Plugin Management
```powershell
# List all plugins
Get-AstraPlugin

# Disable a plugin
Disable-AstraPlugin -PluginName "Security"

# Verify it's disabled
Get-AstraPlugin

# Re-enable
Enable-AstraPlugin -PluginName "Security"

# Verify
Get-AstraPlugin
```

### 3. Edge Case Testing

#### Test with Invalid Input
```powershell
# Test with nonsensical command
astra "foobar bazquux invalid command test"

# Test with very long command
astra ("a" * 1000)

# Test with special characters
astra "command with `$special @characters #test"
```

#### Test Configuration Edge Cases
```powershell
# Try to get non-existent section
Get-AstraConfig -Section "NonExistent"

# Try to set in non-existent section
Set-AstraConfig -Section "NonExistent" -Key "Test" -Value "Value"

# Try to access config before initialization
Remove-Module AstraShell -Force
Import-Module .\AstraShell.psd1
Get-AstraConfig  # Should auto-initialize
```

#### Test RAG with Large Files
```powershell
# Try to index with small max file size
Set-AstraConfig -Section "RAG" -Key "MaxFileSize" -Value 1024  # 1KB
Update-AstraIndex

# Check that large files were skipped
Get-AstraIndexStats
```

### 4. Performance Testing

#### Test Command History
```powershell
# Execute many commands
1..100 | ForEach-Object {
    astra "show git status" -NoConfirm
}

# Check history is limited (should be max 1000 by default)
# Note: History is internal, but shouldn't cause memory issues
```

#### Test Large Index
```powershell
# Index a large codebase
Set-AstraConfig -Section "RAG" -Key "IndexPaths" -Value @("C:\Windows\System32")
Measure-Command { Update-AstraIndex }

# Search should still be fast
Measure-Command { Search-AstraIndex -Query "function" }
```

### 5. Security Testing

#### Test Malicious Pattern Detection
```powershell
# Test each security pattern

# Test 1: Invoke-Expression
$cmd = 'astra "Invoke-Expression $downloadedCode"'
Invoke-Astra "Invoke-Expression `$downloadedCode"

# Test 2: Force deletion
astra "Remove-Item C:\Test -Recurse -Force"

# Test 3: Encoded command
astra "powershell -EncodedCommand ABC123"

# These should all show security warnings
```

#### Test VirusTotal Integration (requires API key)
```powershell
# Set API key
Set-AstraConfig -Section "Security" -Key "VirusTotalApiKey" -Value "YOUR_API_KEY"
Set-AstraConfig -Section "Security" -Key "EnableVirusTotalCheck" -Value $true

# Test with known good domain
Test-AstraDomainSafety "https://github.com"

# Test with known malicious domain (if you have one for testing)
Test-AstraDomainSafety "http://malware-test-domain.example"

# Check security stats
Get-AstraSecurityStats
```

### 6. Error Handling Testing

#### Test Missing Dependencies
```powershell
# Test commands that require external tools
astra "show git status"  # If Git not installed
astra "npm install"      # If npm not installed
astra "code ."           # If VS Code not installed

# These should fail gracefully with clear error messages
```

#### Test Corrupted Configuration
```powershell
# Backup current config
Copy-Item .\config.jsonc .\config.jsonc.bak

# Create invalid config
'{ invalid json' | Set-Content .\config.jsonc

# Reload module
Remove-Module AstraShell -Force
Import-Module .\AstraShell.psd1

# Should handle gracefully
Start-AstraShell

# Restore config
Copy-Item .\config.jsonc.bak .\config.jsonc -Force
Remove-Item .\config.jsonc.bak
```

### 7. Cross-Plugin Integration

#### Test Combined Features
```powershell
# Use NL command with security check
astra "download from https://suspicious-domain.com"

# Should trigger both NLParser and Security plugins
```

### 8. Cleanup and Reset
```powershell
# Stop AstraShell
Stop-AstraShell

# Clear index
Clear-AstraIndex -Confirm:$false

# Clear security cache
Clear-AstraSecurityCache

# Remove module
Remove-Module AstraShell

# Restart fresh
Import-Module .\AstraShell.psd1
Start-AstraShell
```

## Expected Test Results

### All Tests Should Pass
- ✓ Module loads without errors
- ✓ All 10 functions exported
- ✓ Alias 'astra' works
- ✓ All 4 plugins load
- ✓ Configuration read/write works
- ✓ Natural language parsing works
- ✓ Security checks work
- ✓ System monitoring works
- ✓ File indexing works

### Known Limitations
- Windows-only commands (Get-Counter, Win32_OperatingSystem) will fail on non-Windows
- VirusTotal checks require API key
- Some natural language patterns may have low confidence
- Very large indexes may be slow to search

## Troubleshooting

### Module Won't Load
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion  # Should be 7.0+

# Check file paths
Get-ChildItem .\AstraShell.psd1

# Import with error details
Import-Module .\AstraShell.psd1 -Verbose
```

### Plugin Errors
```powershell
# Check which plugins loaded
Get-AstraPlugin

# Try loading manually
Import-Module .\Plugins\AstraShell.NLParser.psm1 -Verbose
```

### Configuration Issues
```powershell
# Check config file exists
Test-Path .\config.jsonc

# Validate JSON
$content = Get-Content .\config.jsonc -Raw
$content = $content -replace '(?m)^\s*//.*$', ''
$content | ConvertFrom-Json
```

## Automated CI/CD Testing

For continuous integration, run:
```powershell
.\Test-AstraShell.ps1
if ($LASTEXITCODE -ne 0) {
    throw "Tests failed"
}
```

## Reporting Issues

When reporting issues, include:
1. PowerShell version: `$PSVersionTable`
2. Test output from `.\Test-AstraShell.ps1`
3. Error messages (full stack trace)
4. Steps to reproduce
5. Expected vs actual behavior

## Performance Benchmarks

Expected performance on modern hardware:
- Module load: < 2 seconds
- NL parsing: < 100ms
- Security check: < 50ms (cached), < 2s (VirusTotal)
- Index 1000 files: < 30 seconds
- Search indexed files: < 500ms
- System metrics: < 1 second

---

**Last Updated**: 2025-01-08
**AstraShell Version**: 1.0.0
