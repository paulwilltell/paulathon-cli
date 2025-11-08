# AstraShell Examples

This document provides practical examples of using AstraShell in real-world scenarios.

---

## Table of Contents
- [Basic Natural Language Commands](#basic-natural-language-commands)
- [System Monitoring](#system-monitoring)
- [Local File Search (RAG)](#local-file-search-rag)
- [Security Analysis](#security-analysis)
- [Advanced Multi-Step Commands](#advanced-multi-step-commands)
- [Configuration Management](#configuration-management)
- [Plugin Management](#plugin-management)

---

## Basic Natural Language Commands

### Finding Files
```powershell
# Find large log files
astra "find all log files larger than 50MB"

# Find files by extension
astra "find all .ps1 files"

# Find files in a specific directory
astra "find all .json files in C:\Projects"
```

### Git Operations
```powershell
# Check Git status
astra "show git status"

# View Git log
astra "show git log"

# Create a new branch
astra "create branch feature/new-feature"

# View all branches
astra "show git branches"
```

### System Information
```powershell
# Analyze system resources
astra "analyze system performance"

# Check disk space
astra "show disk usage"

# View running processes
astra "show running processes"
```

### Code Operations
```powershell
# Open files in VS Code
astra "open project folder in VS Code"

# Run tests
astra "run tests"

# Build project
astra "build project"
```

---

## System Monitoring

### Starting the System Sentry
```powershell
# Start monitoring with default settings
Start-AstraSentry

# Start monitoring with custom interval (300 seconds)
Start-AstraSentry -IntervalSeconds 300
```

### Checking System Status
```powershell
# Get current system metrics
Get-AstraSentryStatus

# Example output:
# 📊 System Status Report
#   Generated: 2025-01-08 14:30:00
#
#   CPU Usage: 45.2%
#   Memory Usage: 62.8% (10.2 GB)
#
#   Disk Usage:
#     Drive C: 68.5% (Free: 120.3 GB)
#     Drive D: 42.1% (Free: 450.8 GB)
#
#   Top Processes by Memory:
#     chrome.exe                     1850.2 MB
#     Code.exe                       1240.5 MB
#     powershell.exe                  420.3 MB
```

### Performing Health Checks
```powershell
# Immediate health check
Invoke-AstraSentryCheck

# Example output with issues:
# ⚠️ Found 2 issue(s):
#
# 🔥 AstraShell Sentry Alert [Warning]
#   Type: CPU
#   High CPU usage detected: 85.3%
#
#   💡 Suggested Actions:
#     • Check running processes with: Get-Process | Sort-Object CPU -Descending
#     • Consider closing unnecessary applications
```

### Viewing Alert History
```powershell
# View last 10 alerts
Get-AstraSentryAlertHistory

# View last 50 alerts
Get-AstraSentryAlertHistory -Last 50
```

### Stopping the Sentry
```powershell
Stop-AstraSentry
```

---

## Local File Search (RAG)

### Setting Up File Indexing

#### Configure Paths
```powershell
# Add a single path
Set-AstraConfig -Section "RAG" -Key "IndexPaths" -Value @("C:\Projects")

# Add multiple paths
Set-AstraConfig -Section "RAG" -Key "IndexPaths" -Value @(
    "C:\Projects",
    "D:\Development",
    "C:\Users\YourName\Documents\Code"
)
```

#### Build the Index
```powershell
# Initial index build (uses configured paths)
Update-AstraIndex

# Example output:
# 🔍 Building local file index...
#
#   Scanning: C:\Projects
#     Indexed 10 files...
#     Indexed 20 files...
#     ...
#
# ✅ Indexing complete!
#   Total files scanned: 247
#   Files indexed: 247
#   Files skipped (unchanged): 0
#   Index size: 247 files
```

```powershell
# Index specific paths (overrides config)
Update-AstraIndex -Paths @("C:\MyProject")

# Force re-index (even unchanged files)
Update-AstraIndex -Force
```

### Searching Indexed Files

#### Basic Search
```powershell
# Search for code/content
Search-AstraIndex -Query "authentication"

# Example output:
# 🔎 Searching index for: 'authentication'
#
# 📄 Found 3 result(s):
#
#   1. AuthService.ps1 (Score: 150)
#      Path: C:\Projects\MyApp\Services\AuthService.ps1
#      Type: PowerShell
#      Functions: Initialize-Auth, Get-AuthToken, Validate-User
#
#   2. README.md (Score: 45)
#      Path: C:\Projects\MyApp\README.md
#      Type: .md
```

#### Search with More Results
```powershell
# Get top 10 results
Search-AstraIndex -Query "error handling" -MaxResults 10
```

#### Search with Content Preview
```powershell
# Show content snippets
Search-AstraIndex -Query "caching logic" -ShowContent

# Example output shows relevant code snippets:
#   1. CacheManager.ps1 (Score: 180)
#      Path: C:\Projects\MyApp\CacheManager.ps1
#      Type: PowerShell
#      Functions: Set-Cache, Get-Cache, Clear-Cache
#
#      Snippet:
#      ...implements the caching logic using a hashtable
#      for in-memory storage. The cache expires after...
```

#### Quick Query Alias
```powershell
# Shorter syntax
Invoke-AstraQuery "database connection"
```

### Index Management

#### View Index Statistics
```powershell
Get-AstraIndexStats

# Example output:
# 📊 Index Statistics:
#   Total Files: 247
#   Total Size: 12.45 MB
#   Last Updated: 2025-01-08 14:25:30
#
#   Files by Language:
#     PowerShell : 145
#     JavaScript : 52
#     Python : 28
#     Markdown : 15
#     Other : 7
```

#### Clear the Index
```powershell
# Clear all indexed data
Clear-AstraIndex
```

---

## Security Analysis

### Checking URLs/Domains

#### Basic Domain Check
```powershell
# Check if a domain is safe
Test-AstraDomainSafety "https://example.com"

# Example output (safe):
# 🔍 Checking domain safety: example.com
# ✅ Domain is SAFE
#    VirusTotal: No malicious detections
```

```powershell
# Example output (malicious):
# 🔍 Checking domain safety: suspicious-site.com
# 🚫 Domain is MALICIOUS
#    VirusTotal: 15 malicious, 3 suspicious detections
```

#### Configure VirusTotal Integration
```powershell
# Enable VirusTotal checking
Set-AstraConfig -Section "Security" -Key "EnableVirusTotalCheck" -Value $true

# Set your API key (get free key at virustotal.com)
Set-AstraConfig -Section "Security" -Key "VirusTotalApiKey" -Value "your-api-key-here"
```

### Analyzing Scripts

#### Check Script Security
```powershell
# Analyze a script for security risks
Test-AstraScriptSecurity "C:\Downloads\untrusted-script.ps1"

# Example output:
# 🔒 Analyzing script security: C:\Downloads\untrusted-script.ps1
#
# ⚠️ Security Analysis Results:
#
#   High Risk(s): 2
#     • Recursive force deletion - potential data loss
#     • Encoded PowerShell command - potentially obfuscated malicious code
#
#   Medium Risk(s): 1
#     • File download detected - verify source is trusted
#
# 🚫 This script contains critical security risks and would be blocked from execution.
```

### Security Statistics

#### View Security Cache
```powershell
Get-AstraSecurityStats

# Example output:
# 🔒 Security Statistics:
#   Cached malicious domains: 2
#   Cached safe domains: 15
#
#   Malicious Domains:
#     • badsite.com - VirusTotal: 12 malicious
#     • malware-host.net - VirusTotal: 8 malicious
```

#### Clear Security Cache
```powershell
# Clear cached domain safety data
Clear-AstraSecurityCache
```

---

## Advanced Multi-Step Commands

### Complex File Operations
```powershell
# Find, analyze, and act on log files
astra "find all .log files larger than 50MB in C:\Logs, analyze for errors from the last 24 hours"

# AstraShell breaks this into steps:
# 📋 Execution Plan:
#   1. Find log files larger than 50MB in 'C:\Logs'
#   2. Search for error patterns in logs
#
# Proceed with execution? (Y/N)
```

### Git Workflow Automation
```powershell
# Create branch and open in VS Code
astra "create git branch hotfix/critical-bug and open current folder in VS Code"
```

### System Analysis Workflow
```powershell
# Comprehensive system check
astra "analyze system resources and show top 5 memory-consuming processes"
```

---

## Configuration Management

### Viewing Configuration

```powershell
# View all configuration
Get-AstraConfig

# View specific section
Get-AstraConfig -Section "RAG"
Get-AstraConfig -Section "Sentry"
Get-AstraConfig -Section "Security"
```

### Updating Configuration

```powershell
# Update Sentry thresholds
Set-AstraConfig -Section "Sentry" -Key "CPUThreshold" -Value 90
Set-AstraConfig -Section "Sentry" -Key "MemoryThreshold" -Value 85
Set-AstraConfig -Section "Sentry" -Key "DiskThreshold" -Value 95

# Update RAG settings
Set-AstraConfig -Section "RAG" -Key "MaxFileSize" -Value 20971520  # 20MB

# Update monitoring interval
Set-AstraConfig -Section "Sentry" -Key "MonitorInterval" -Value 120  # 2 minutes
```

### Feature Toggles

```powershell
# Enable/disable features via config
Set-AstraConfig -Section "Features" -Key "Security" -Value $true
Set-AstraConfig -Section "Features" -Key "Sentry" -Value $false
```

---

## Plugin Management

### Viewing Plugins

```powershell
Get-AstraPlugin

# Example output:
# 📦 AstraShell Plugins:
#
#   ✓ Loaded NLParser
#     Loaded: 2025-01-08 14:00:15
#
#   ✓ Loaded Sentry
#     Loaded: 2025-01-08 14:00:15
#
#   ✓ Loaded RAG
#     Loaded: 2025-01-08 14:00:15
#
#   ○ Available Security
```

### Managing Plugins

```powershell
# Enable a plugin
Enable-AstraPlugin -PluginName "Security"

# Disable a plugin
Disable-AstraPlugin -PluginName "Sentry"

# Note: Disabling a plugin removes it from memory
# Enabling reloads it with current configuration
```

---

## Real-World Scenarios

### Scenario 1: Developer Workflow

```powershell
# Morning startup routine
Start-AstraShell

# Check what to work on
Get-AstraSuggestion

# Find where you left off
astra "show git status"

# Search for specific code
Invoke-AstraQuery "payment processing logic"

# Create a new feature branch
astra "create branch feature/payment-refactor"

# Monitor system while working
Start-AstraSentry
```

### Scenario 2: System Troubleshooting

```powershell
# User reports slowness - investigate
Get-AstraSentryStatus

# Check for issues
Invoke-AstraSentryCheck

# Find large files that might be causing problems
astra "find all files larger than 1GB"

# Check specific logs for errors
astra "find all .log files and analyze for errors"
```

### Scenario 3: Security Audit

```powershell
# Analyze all scripts in a directory
Get-ChildItem "C:\Scripts" -Filter "*.ps1" | ForEach-Object {
    Write-Host "`nAnalyzing: $($_.Name)" -ForegroundColor Cyan
    Test-AstraScriptSecurity $_.FullName
}

# Check URLs in a file
$urls = Select-String -Path ".\links.txt" -Pattern "https?://\S+" -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    Select-Object -Unique

foreach ($url in $urls) {
    Test-AstraDomainSafety $url
}
```

### Scenario 4: Code Documentation Search

```powershell
# Index your entire codebase
Set-AstraConfig -Section "RAG" -Key "IndexPaths" -Value @("C:\MyProject")
Update-AstraIndex

# Find implementation details
Search-AstraIndex "how authentication is implemented" -ShowContent

# Find all functions related to a topic
Search-AstraIndex "database connection" -MaxResults 20

# Find examples of error handling
Search-AstraIndex "try catch error handling" -ShowContent
```

---

## Tips and Tricks

### 1. Use Aliases for Speed
```powershell
# 'astra' is shorter than 'Invoke-Astra'
astra "your command"
```

### 2. Combine with Traditional PowerShell
```powershell
# Pipe AstraShell results into other commands
Search-AstraIndex "config" | Select-Object -First 3
```

### 3. Use NoConfirm for Trusted Commands
```powershell
# Skip confirmation prompts (use carefully!)
Invoke-Astra "show git status" -NoConfirm
```

### 4. Build Custom Workflows
```powershell
# Create your own functions combining AstraShell
function Start-DevSession {
    Start-AstraShell -StartSentry
    Set-Location "C:\Projects\MyApp"
    astra "show git status" -NoConfirm
    Get-AstraSuggestion
}
```

### 5. Scheduled Index Updates
```powershell
# Add to your profile for automatic updates
if ((Get-Date).Hour -eq 9 -and (Get-Date).Minute -lt 5) {
    Update-AstraIndex
}
```

---

## Next Steps

1. Read the full [README.md](README.md) for comprehensive documentation
2. Explore the configuration file at `config.jsonc`
3. Check command help: `Get-Help <CommandName> -Full`
4. Join the community and share your workflows!

**Happy coding with AstraShell! 🚀**
