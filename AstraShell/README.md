# AstraShell

**Advanced PowerShell CLI with AI-Enhanced Capabilities**

AstraShell is a production-grade PowerShell 7 module that brings natural language processing, intelligent suggestions, system monitoring, and local file indexing to your terminal.

## Features

### 🧠 Cognitive Command Interpreter (Natural Language Parser)
Convert complex natural language commands into executable PowerShell:
```powershell
astra "find all log files larger than 50MB"
astra "create a git branch named hotfix/critical-bug"
astra "analyze system resources"
```

### 🔮 Intelligent Suggestions
Get context-aware command suggestions based on:
- Current directory (Git repos, Node.js projects, .NET solutions)
- Command history
- Active files and project structure

### 🛡️ System Sentry
Proactive system monitoring with alerts for:
- High CPU usage
- Memory leaks
- Low disk space
- Resource anomalies

### 📚 Local RAG (Retrieval-Augmented Generation)
Index and search your local codebase:
```powershell
Update-AstraIndex -Paths @("C:\Projects", "D:\Docs")
Search-AstraIndex -Query "authentication module"
```

### 🔒 Security Analysis
Built-in security checks for:
- Suspicious command patterns
- Malicious URLs (with optional VirusTotal integration)
- Script security analysis
- Real-time threat detection

### 🔧 Modular Architecture
All features are implemented as plugins that can be independently enabled/disabled.

---

## Installation

### Prerequisites
- **PowerShell 7.0 or higher** (Download from: https://github.com/PowerShell/PowerShell/releases)
- Windows operating system

### Step 1: Download AstraShell
Clone or download this repository to your local machine:
```powershell
git clone https://github.com/yourusername/astrashell.git
# Or download and extract the ZIP file
```

### Step 2: Install the Module

#### Option A: User Installation (Recommended)
Install for your user account only:
```powershell
# Create user modules directory if it doesn't exist
$userModulePath = "$HOME\Documents\PowerShell\Modules"
if (-not (Test-Path $userModulePath)) {
    New-Item -Path $userModulePath -ItemType Directory -Force
}

# Copy AstraShell to the modules directory
Copy-Item -Path ".\AstraShell" -Destination "$userModulePath\AstraShell" -Recurse -Force

# Verify installation
Get-Module -ListAvailable AstraShell
```

#### Option B: System-Wide Installation (Requires Admin)
Install for all users (requires Administrator privileges):
```powershell
# Run PowerShell as Administrator
$systemModulePath = "$env:ProgramFiles\PowerShell\Modules"
Copy-Item -Path ".\AstraShell" -Destination "$systemModulePath\AstraShell" -Recurse -Force

# Verify installation
Get-Module -ListAvailable AstraShell
```

### Step 3: Import the Module
```powershell
Import-Module AstraShell
```

To auto-load on every PowerShell session, add this to your profile:
```powershell
# Edit your PowerShell profile
notepad $PROFILE

# Add this line to the file:
Import-Module AstraShell

# If $PROFILE doesn't exist, create it first:
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force
}
```

### Step 4: Initialize AstraShell
```powershell
Start-AstraShell
```

---

## Quick Start

### Basic Usage

#### Natural Language Commands
```powershell
# Use the 'astra' alias for natural language commands
astra "find all .log files"
astra "show git status"
astra "analyze system performance"
astra "create branch feature/new-feature"
```

#### Get Suggestions
```powershell
Get-AstraSuggestion
```

#### Query Local Files
```powershell
# First, build the index (configure paths in config.jsonc)
Update-AstraIndex

# Search your codebase
Invoke-AstraQuery "authentication logic"
Search-AstraIndex "error handling" -MaxResults 10
```

#### System Monitoring
```powershell
# Start the system sentry
Start-AstraSentry

# Check system status
Get-AstraSentryStatus

# Perform immediate health check
Invoke-AstraSentryCheck
```

#### Security Checks
```powershell
# Check if a domain is safe
Test-AstraDomainSafety "https://example.com"

# Analyze a script for security risks
Test-AstraScriptSecurity "C:\Scripts\myscript.ps1"
```

---

## Configuration

AstraShell is configured via the `config.jsonc` file in the module directory.

### Key Configuration Sections

#### 1. Enable/Disable Features
```jsonc
"Features": {
  "NLParser": true,    // Natural language parsing
  "Sentry": true,      // System monitoring
  "RAG": true,         // Local file indexing
  "Security": true,    // Security checks
  "Suggestions": true  // Intelligent suggestions
}
```

#### 2. Configure RAG Indexing Paths
```jsonc
"RAG": {
  "IndexPaths": [
    "C:\\Projects",
    "C:\\Users\\YourName\\Documents\\Code"
  ]
}
```

#### 3. Set Up VirusTotal Integration (Optional)
```jsonc
"Security": {
  "EnableVirusTotalCheck": true,
  "VirusTotalApiKey": "your-api-key-here"
}
```
Get a free API key at: https://www.virustotal.com/gui/join-us

#### 4. Adjust System Thresholds
```jsonc
"Sentry": {
  "MonitorInterval": 60,
  "CPUThreshold": 80,
  "MemoryThreshold": 80,
  "DiskThreshold": 90
}
```

### Modify Configuration at Runtime
```powershell
# View current config
Get-AstraConfig

# Update a setting
Set-AstraConfig -Section "Sentry" -Key "CPUThreshold" -Value 90
```

---

## Plugin Management

### View Available Plugins
```powershell
Get-AstraPlugin
```

### Enable a Plugin
```powershell
Enable-AstraPlugin -PluginName "RAG"
```

### Disable a Plugin
```powershell
Disable-AstraPlugin -PluginName "Sentry"
```

---

## Advanced Usage

### Example: Complex Multi-Step Command
```powershell
astra "find all .log files larger than 50MB in project-phoenix, summarize errors from the last 24 hours, and if any log contains more than 100 FATAL_ERROR entries, create a new Git branch named hotfix/log-overflow"
```

AstraShell will:
1. Parse the natural language command
2. Break it into executable steps
3. Show you the execution plan
4. Ask for confirmation
5. Execute each step sequentially

### Example: Building a Local Knowledge Base
```powershell
# Configure paths to index
Set-AstraConfig -Section "RAG" -Key "IndexPaths" -Value @("C:\Projects", "D:\Documentation")

# Build the index
Update-AstraIndex

# View index statistics
Get-AstraIndexStats

# Search your codebase
Search-AstraIndex "how did I implement caching" -ShowContent
```

### Example: Security Workflow
```powershell
# Enable VirusTotal integration
Set-AstraConfig -Section "Security" -Key "EnableVirusTotalCheck" -Value $true
Set-AstraConfig -Section "Security" -Key "VirusTotalApiKey" -Value "your-key"

# Check a URL before visiting
Test-AstraDomainSafety "https://suspicious-site.com"

# Analyze a downloaded script
Test-AstraScriptSecurity ".\downloaded-script.ps1"

# View security stats
Get-AstraSecurityStats
```

---

## Command Reference

### Core Commands
| Command | Description |
|---------|-------------|
| `Invoke-Astra` / `astra` | Main entry point for natural language commands |
| `Start-AstraShell` | Initialize AstraShell with all plugins |
| `Stop-AstraShell` | Stop AstraShell and background services |
| `Get-AstraConfig` | View current configuration |
| `Set-AstraConfig` | Update configuration settings |

### Suggestion Commands
| Command | Description |
|---------|-------------|
| `Get-AstraSuggestion` | Get intelligent command suggestions |

### Plugin Management
| Command | Description |
|---------|-------------|
| `Get-AstraPlugin` | List all available plugins |
| `Enable-AstraPlugin` | Enable a specific plugin |
| `Disable-AstraPlugin` | Disable a specific plugin |

### RAG (File Indexing) Commands
| Command | Description |
|---------|-------------|
| `Update-AstraIndex` | Build or update the file index |
| `Search-AstraIndex` | Search indexed files |
| `Invoke-AstraQuery` | Quick search alias |
| `Get-AstraIndexStats` | View index statistics |
| `Clear-AstraIndex` | Clear the file index |

### System Sentry Commands
| Command | Description |
|---------|-------------|
| `Start-AstraSentry` | Start system monitoring |
| `Stop-AstraSentry` | Stop system monitoring |
| `Get-AstraSentryStatus` | View current system status |
| `Invoke-AstraSentryCheck` | Perform immediate health check |
| `Get-AstraSentryAlertHistory` | View alert history |

### Security Commands
| Command | Description |
|---------|-------------|
| `Test-AstraDomainSafety` | Check if a URL/domain is safe |
| `Test-AstraScriptSecurity` | Analyze a script for security risks |
| `Get-AstraSecurityStats` | View security statistics |
| `Clear-AstraSecurityCache` | Clear domain safety cache |

---

## Architecture

### File Structure
```
AstraShell/
├── AstraShell.psd1              # Module manifest
├── AstraShell.psm1              # Main module file
├── config.jsonc                 # Configuration file
├── README.md                    # This file
├── Data/                        # Data directory (index storage)
│   └── index.json              # RAG index file (generated)
└── Plugins/                     # Plugin modules
    ├── AstraShell.NLParser.psm1   # Natural language parser
    ├── AstraShell.Sentry.psm1     # System monitoring
    ├── AstraShell.RAG.psm1        # File indexing
    └── AstraShell.Security.psm1   # Security analysis
```

### Design Principles
- **Modular**: All features are plugins that can be independently enabled/disabled
- **Safe**: User confirmation required for multi-step commands
- **Extensible**: Easy to add new plugins and features
- **Secure**: Built-in security checks and threat analysis
- **User-Friendly**: Natural language interface with intelligent suggestions

---

## Troubleshooting

### Module Not Found
**Problem**: `Get-Module -ListAvailable AstraShell` returns nothing

**Solutions**:
1. Verify the module is in a valid module path:
   ```powershell
   $env:PSModulePath -split ';'
   ```
2. Ensure the folder structure is correct (AstraShell/AstraShell.psd1)
3. Try importing with explicit path:
   ```powershell
   Import-Module "C:\Path\To\AstraShell\AstraShell.psd1"
   ```

### PowerShell Version Issues
**Problem**: Module doesn't load or features don't work

**Solution**: Verify you're using PowerShell 7+:
```powershell
$PSVersionTable.PSVersion
```
If you have PowerShell 5.x, download PowerShell 7 from: https://github.com/PowerShell/PowerShell/releases

### Plugin Not Loading
**Problem**: Plugin features not working

**Solutions**:
1. Check if plugin is enabled:
   ```powershell
   Get-AstraPlugin
   ```
2. Enable the plugin:
   ```powershell
   Enable-AstraPlugin -PluginName "PluginName"
   ```
3. Check configuration:
   ```powershell
   Get-AstraConfig -Section Features
   ```

### RAG Index Issues
**Problem**: Search returns no results

**Solutions**:
1. Verify paths are configured:
   ```powershell
   Get-AstraConfig -Section RAG
   ```
2. Build/rebuild the index:
   ```powershell
   Update-AstraIndex -Force
   ```
3. Check index stats:
   ```powershell
   Get-AstraIndexStats
   ```

---

## Performance Tips

1. **RAG Indexing**: Start with smaller paths and expand as needed
2. **File Size Limits**: Adjust `MaxFileSize` in config if you have very large files
3. **Cache Settings**: Increase `CacheExpiration` for better performance (less frequent checks)
4. **Sentry Interval**: Increase `MonitorInterval` to reduce system overhead

---

## Security Considerations

1. **Command Execution**: AstraShell requires user confirmation for multi-step commands
2. **External Resources**: Security plugin checks URLs before execution
3. **Script Analysis**: Use `Test-AstraScriptSecurity` before running untrusted scripts
4. **VirusTotal**: Optional integration requires API key (free tier available)
5. **Sensitive Data**: Config file may contain API keys - protect accordingly

---

## Contributing

Contributions are welcome! To add a new plugin:

1. Create a new `.psm1` file in the `Plugins/` directory
2. Follow the naming convention: `AstraShell.PluginName.psm1`
3. Export your functions using `Export-ModuleMember`
4. Add configuration section to `config.jsonc`
5. Document your plugin in this README

---

## License

MIT License - See LICENSE file for details

---

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

---

## Roadmap

Future enhancements planned:
- [ ] Integration with OpenAI/Claude for enhanced NLP
- [ ] Machine learning-based command prediction
- [ ] Cross-platform support (Linux, macOS)
- [ ] Web dashboard for system monitoring
- [ ] Plugin marketplace
- [ ] Collaborative features (share command history, indices)

---

**Happy Shell-ing with AstraShell! 🚀**
