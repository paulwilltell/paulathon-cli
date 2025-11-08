<#
.SYNOPSIS
    AstraShell - Advanced PowerShell CLI with AI-Enhanced Capabilities

.DESCRIPTION
    A modular PowerShell framework that provides natural language command parsing,
    predictive suggestions, system monitoring, local file indexing, and security analysis.

.NOTES
    Author: AstraShell Development Team
    Version: 1.0.0
    Requires: PowerShell 7.0+
#>

#region Module Variables
$script:AstraShellConfig = $null
$script:AstraShellPlugins = @{}
$script:AstraShellActive = $false
$script:ModuleRoot = $PSScriptRoot
$script:ConfigPath = Join-Path $ModuleRoot "config.jsonc"
$script:DataPath = Join-Path $ModuleRoot "Data"
$script:PluginPath = Join-Path $ModuleRoot "Plugins"
$script:CommandHistory = @()
$script:SuggestionCache = @{}
#endregion

#region Core Functions

<#
.SYNOPSIS
    Initializes AstraShell and loads configuration.
#>
function Initialize-AstraShell {
    [CmdletBinding()]
    param()

    Write-Host "🚀 Initializing AstraShell..." -ForegroundColor Cyan

    # Create data directory if it doesn't exist
    if (-not (Test-Path $script:DataPath)) {
        New-Item -Path $script:DataPath -ItemType Directory -Force | Out-Null
    }

    # Load configuration
    if (Test-Path $script:ConfigPath) {
        try {
            # Read and remove comments from JSONC
            $configContent = Get-Content $script:ConfigPath -Raw
            $configContent = $configContent -replace '(?m)^\s*//.*$', '' -replace '(?ms)/\*.*?\*/', ''
            $script:AstraShellConfig = $configContent | ConvertFrom-Json
            Write-Host "✓ Configuration loaded" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to load configuration: $_"
            $script:AstraShellConfig = Get-DefaultConfig
        }
    }
    else {
        Write-Warning "Configuration file not found. Creating default configuration..."
        $script:AstraShellConfig = Get-DefaultConfig
        Save-AstraConfig
    }

    # Load plugins
    Load-AstraPlugins

    $script:AstraShellActive = $true
    Write-Host "✓ AstraShell is ready!" -ForegroundColor Green
    Write-Host "  Type 'Invoke-Astra `"your command`"' or use the 'astra' alias" -ForegroundColor Gray
    Write-Host ""
}

<#
.SYNOPSIS
    Returns default configuration.
#>
function Get-DefaultConfig {
    return [PSCustomObject]@{
        Features = [PSCustomObject]@{
            NLParser = $true
            Sentry = $true
            RAG = $true
            Security = $true
            Suggestions = $true
        }
        Plugins = [PSCustomObject]@{
            AutoLoad = $true
        }
        RAG = [PSCustomObject]@{
            IndexPaths = @()
            MaxFileSize = 10485760  # 10MB
            FileTypes = @('.ps1', '.psm1', '.psd1', '.md', '.txt', '.json', '.xml', '.yml', '.yaml')
        }
        Sentry = [PSCustomObject]@{
            MonitorInterval = 60
            CPUThreshold = 80
            MemoryThreshold = 80
            DiskThreshold = 90
        }
        Security = [PSCustomObject]@{
            EnableVirusTotalCheck = $false
            VirusTotalApiKey = ""
            BlockMaliciousUrls = $true
            ConfirmExternalCommands = $true
        }
        Suggestions = [PSCustomObject]@{
            MaxSuggestions = 5
            UseHistory = $true
            UseContext = $true
        }
        Advanced = [PSCustomObject]@{
            LogLevel = "Info"
            MaxHistoryEntries = 1000
            CacheExpiration = 300
        }
    }
}

<#
.SYNOPSIS
    Saves configuration to disk.
#>
function Save-AstraConfig {
    try {
        $configJson = $script:AstraShellConfig | ConvertTo-Json -Depth 10
        $configJson | Set-Content -Path $script:ConfigPath -Encoding UTF8
        Write-Verbose "Configuration saved to $script:ConfigPath"
    }
    catch {
        Write-Error "Failed to save configuration: $_"
    }
}

<#
.SYNOPSIS
    Loads all available plugins.
#>
function Load-AstraPlugins {
    if (-not (Test-Path $script:PluginPath)) {
        Write-Warning "Plugin directory not found: $script:PluginPath"
        return
    }

    $pluginFiles = Get-ChildItem -Path $script:PluginPath -Filter "AstraShell.*.psm1"

    foreach ($pluginFile in $pluginFiles) {
        try {
            $pluginName = $pluginFile.BaseName -replace '^AstraShell\.', ''

            # Check if plugin should be loaded
            $featureEnabled = $script:AstraShellConfig.Features.PSObject.Properties.Name -contains $pluginName -and
                              $script:AstraShellConfig.Features.$pluginName

            if ($script:AstraShellConfig.Plugins.AutoLoad -or $featureEnabled) {
                Import-Module $pluginFile.FullName -Force -ErrorAction Stop
                $script:AstraShellPlugins[$pluginName] = @{
                    Path = $pluginFile.FullName
                    Loaded = $true
                    LoadTime = Get-Date
                }
                Write-Host "  ✓ Plugin loaded: $pluginName" -ForegroundColor Green
            }
            else {
                $script:AstraShellPlugins[$pluginName] = @{
                    Path = $pluginFile.FullName
                    Loaded = $false
                }
                Write-Verbose "Plugin available but not loaded: $pluginName"
            }
        }
        catch {
            Write-Warning "Failed to load plugin $($pluginFile.Name): $_"
        }
    }
}

<#
.SYNOPSIS
    Main entry point for AstraShell commands.

.DESCRIPTION
    Processes natural language or structured commands through the AstraShell pipeline.

.PARAMETER Command
    The command to execute (natural language or PowerShell).

.PARAMETER NoConfirm
    Skip confirmation prompts (use with caution).

.PARAMETER Verbose
    Show detailed execution information.

.EXAMPLE
    Invoke-Astra "find all log files larger than 50MB"

.EXAMPLE
    astra "analyze system resources"
#>
function Invoke-Astra {
    [CmdletBinding()]
    [Alias('astra')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Command,

        [Parameter()]
        [switch]$NoConfirm,

        [Parameter()]
        [switch]$Force
    )

    begin {
        if (-not $script:AstraShellActive) {
            Initialize-AstraShell
        }
    }

    process {
        try {
            Write-Host "`n🤖 AstraShell Processing: " -ForegroundColor Cyan -NoNewline
            Write-Host $Command -ForegroundColor White

            # Add to command history
            $script:CommandHistory += [PSCustomObject]@{
                Command = $Command
                Timestamp = Get-Date
                ExecutionId = [Guid]::NewGuid().ToString()
            }

            # Keep history size manageable
            if ($script:CommandHistory.Count -gt $script:AstraShellConfig.Advanced.MaxHistoryEntries) {
                $script:CommandHistory = $script:CommandHistory | Select-Object -Last $script:AstraShellConfig.Advanced.MaxHistoryEntries
            }

            # Security check
            if ($script:AstraShellConfig.Features.Security -and (Test-PluginLoaded 'Security')) {
                $securityResult = Invoke-AstraSecurityCheck -Command $Command
                if ($securityResult.Blocked) {
                    Write-Warning "⚠️ Security check failed: $($securityResult.Reason)"
                    if (-not $Force) {
                        return
                    }
                    Write-Warning "Proceeding anyway (Force specified)..."
                }
            }

            # Parse command using NLParser
            if ($script:AstraShellConfig.Features.NLParser -and (Test-PluginLoaded 'NLParser')) {
                $parsedCommand = ConvertFrom-NaturalLanguage -Command $Command

                if ($parsedCommand.Confidence -lt 0.5) {
                    Write-Warning "⚠️ Low confidence in command interpretation ($([math]::Round($parsedCommand.Confidence * 100))%)"
                    Write-Host "Interpreted as: $($parsedCommand.PowerShellCommand)" -ForegroundColor Yellow

                    if (-not $NoConfirm) {
                        $response = Read-Host "Execute this command? (Y/N)"
                        if ($response -ne 'Y' -and $response -ne 'y') {
                            Write-Host "Command cancelled." -ForegroundColor Yellow
                            return
                        }
                    }
                }

                # Display parsed steps
                Write-Host "`n📋 Execution Plan:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $parsedCommand.Steps.Count; $i++) {
                    Write-Host "  $($i + 1). $($parsedCommand.Steps[$i].Description)" -ForegroundColor Gray
                }

                if (-not $NoConfirm -and $parsedCommand.Steps.Count -gt 1) {
                    Write-Host ""
                    $response = Read-Host "Proceed with execution? (Y/N)"
                    if ($response -ne 'Y' -and $response -ne 'y') {
                        Write-Host "Execution cancelled." -ForegroundColor Yellow
                        return
                    }
                }

                # Execute steps
                Write-Host "`n🔄 Executing..." -ForegroundColor Cyan
                $results = @()
                foreach ($step in $parsedCommand.Steps) {
                    Write-Host "`n  ▶ $($step.Description)" -ForegroundColor Cyan
                    try {
                        $result = Invoke-Expression $step.Command
                        $results += $result
                        Write-Host "  ✓ Completed" -ForegroundColor Green
                        if ($result) {
                            Write-Host "  Result: $result" -ForegroundColor Gray
                        }
                    }
                    catch {
                        Write-Error "  ✗ Failed: $_"
                        if (-not $Force) {
                            Write-Host "`nExecution halted due to error." -ForegroundColor Yellow
                            return
                        }
                    }
                }

                Write-Host "`n✅ Execution complete!" -ForegroundColor Green
                return $results
            }
            else {
                # Direct execution
                Write-Host "`n🔄 Executing command directly..." -ForegroundColor Cyan
                $result = Invoke-Expression $Command
                Write-Host "✅ Complete!" -ForegroundColor Green
                return $result
            }
        }
        catch {
            Write-Error "AstraShell execution failed: $_"
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Starts AstraShell and background services.
#>
function Start-AstraShell {
    [CmdletBinding()]
    param(
        [switch]$StartSentry
    )

    Initialize-AstraShell

    if ($StartSentry -and $script:AstraShellConfig.Features.Sentry) {
        if (Test-PluginLoaded 'Sentry') {
            Start-AstraSentry
            Write-Host "✓ System Sentry started" -ForegroundColor Green
        }
    }

    Write-Host "`n💡 Quick Tips:" -ForegroundColor Cyan
    Write-Host "  • Use 'astra `"your command`"' for natural language commands" -ForegroundColor Gray
    Write-Host "  • Use 'Get-AstraSuggestion' for smart suggestions" -ForegroundColor Gray
    Write-Host "  • Use 'Get-AstraPlugin' to see available plugins" -ForegroundColor Gray
    Write-Host ""
}

<#
.SYNOPSIS
    Stops AstraShell and background services.
#>
function Stop-AstraShell {
    [CmdletBinding()]
    param()

    if (Test-PluginLoaded 'Sentry') {
        try {
            Stop-AstraSentry
            Write-Host "✓ System Sentry stopped" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to stop Sentry: $_"
        }
    }

    $script:AstraShellActive = $false
    Write-Host "AstraShell stopped." -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Gets current AstraShell configuration.
#>
function Get-AstraConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Section
    )

    Assert-AstraShellInitialized

    if ($Section) {
        if ($script:AstraShellConfig.PSObject.Properties.Name -contains $Section) {
            return $script:AstraShellConfig.$Section
        }
        else {
            Write-Warning "Configuration section '$Section' not found"
            return $null
        }
    }

    return $script:AstraShellConfig
}

<#
.SYNOPSIS
    Updates AstraShell configuration.
#>
function Set-AstraConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        $Value
    )

    Assert-AstraShellInitialized

    if ($script:AstraShellConfig.PSObject.Properties.Name -contains $Section) {
        # Check if the key exists in the section
        if ($script:AstraShellConfig.$Section.PSObject.Properties.Name -contains $Key) {
            $script:AstraShellConfig.$Section.$Key = $Value
            Save-AstraConfig
            Write-Host "✓ Configuration updated: $Section.$Key = $Value" -ForegroundColor Green
        }
        else {
            Write-Warning "Key '$Key' not found in section '$Section'. Adding new key..."
            $script:AstraShellConfig.$Section | Add-Member -MemberType NoteProperty -Name $Key -Value $Value -Force
            Save-AstraConfig
            Write-Host "✓ Configuration key added: $Section.$Key = $Value" -ForegroundColor Green
        }
    }
    else {
        Write-Error "Configuration section '$Section' not found"
    }
}

<#
.SYNOPSIS
    Gets intelligent command suggestions based on context.
#>
function Get-AstraSuggestion {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Count = 5
    )

    Assert-AstraShellInitialized

    Write-Host "🔮 Analyzing context for suggestions..." -ForegroundColor Cyan

    $suggestions = @()

    # Get current location info
    $currentPath = Get-Location
    $isGitRepo = Test-Path (Join-Path $currentPath ".git")

    # Context-based suggestions
    if ($isGitRepo) {
        $suggestions += [PSCustomObject]@{
            Command = "git status"
            Description = "Check Git repository status"
            Confidence = 0.8
            Category = "Git"
        }
        $suggestions += [PSCustomObject]@{
            Command = "git log --oneline -10"
            Description = "View recent commits"
            Confidence = 0.7
            Category = "Git"
        }
    }

    # Check for common project files
    if (Test-Path (Join-Path $currentPath "package.json")) {
        $suggestions += [PSCustomObject]@{
            Command = "npm install"
            Description = "Install Node.js dependencies"
            Confidence = 0.75
            Category = "Node.js"
        }
    }

    if (Get-ChildItem -Path $currentPath -Filter "*.sln" -ErrorAction SilentlyContinue) {
        $suggestions += [PSCustomObject]@{
            Command = "dotnet build"
            Description = "Build .NET solution"
            Confidence = 0.75
            Category = ".NET"
        }
    }

    # History-based suggestions
    if ($script:CommandHistory.Count -gt 0) {
        $recentCommands = $script:CommandHistory |
            Select-Object -Last 10 |
            Group-Object -Property Command |
            Sort-Object -Property Count -Descending |
            Select-Object -First 3

        foreach ($cmd in $recentCommands) {
            if ($suggestions.Command -notcontains $cmd.Name) {
                $suggestions += [PSCustomObject]@{
                    Command = $cmd.Name
                    Description = "Recently used command"
                    Confidence = 0.6
                    Category = "History"
                }
            }
        }
    }

    # Sort by confidence and limit
    $suggestions = $suggestions |
        Sort-Object -Property Confidence -Descending |
        Select-Object -First $Count

    if ($suggestions.Count -eq 0) {
        Write-Host "No suggestions available yet. Keep using AstraShell to build context!" -ForegroundColor Yellow
        return
    }

    Write-Host "`n💡 Suggested Commands:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $suggestions.Count; $i++) {
        $s = $suggestions[$i]
        $confidencePercent = [math]::Round($s.Confidence * 100)
        Write-Host "  $($i + 1). " -NoNewline -ForegroundColor Gray
        Write-Host $s.Command -ForegroundColor White -NoNewline
        Write-Host " ($confidencePercent%) " -ForegroundColor DarkGray -NoNewline
        Write-Host "- $($s.Description)" -ForegroundColor Gray
    }

    return $suggestions
}

<#
.SYNOPSIS
    Enables a specific plugin.
#>
function Enable-AstraPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginName
    )

    if (-not $script:AstraShellPlugins.ContainsKey($PluginName)) {
        Write-Error "Plugin '$PluginName' not found"
        return
    }

    try {
        $plugin = $script:AstraShellPlugins[$PluginName]
        Import-Module $plugin.Path -Force
        $plugin.Loaded = $true
        $plugin.LoadTime = Get-Date

        # Enable in config
        if ($script:AstraShellConfig.Features.PSObject.Properties.Name -contains $PluginName) {
            $script:AstraShellConfig.Features.$PluginName = $true
            Save-AstraConfig
        }

        Write-Host "✓ Plugin enabled: $PluginName" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to enable plugin: $_"
    }
}

<#
.SYNOPSIS
    Disables a specific plugin.
#>
function Disable-AstraPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginName
    )

    if (-not $script:AstraShellPlugins.ContainsKey($PluginName)) {
        Write-Error "Plugin '$PluginName' not found"
        return
    }

    try {
        Remove-Module "AstraShell.$PluginName" -ErrorAction SilentlyContinue
        $script:AstraShellPlugins[$PluginName].Loaded = $false

        # Disable in config
        if ($script:AstraShellConfig.Features.PSObject.Properties.Name -contains $PluginName) {
            $script:AstraShellConfig.Features.$PluginName = $false
            Save-AstraConfig
        }

        Write-Host "✓ Plugin disabled: $PluginName" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to disable plugin: $_"
    }
}

<#
.SYNOPSIS
    Lists all available plugins and their status.
#>
function Get-AstraPlugin {
    [CmdletBinding()]
    param()

    if ($script:AstraShellPlugins.Count -eq 0) {
        Write-Host "No plugins found." -ForegroundColor Yellow
        return
    }

    Write-Host "`n📦 AstraShell Plugins:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($pluginName in $script:AstraShellPlugins.Keys) {
        $plugin = $script:AstraShellPlugins[$pluginName]
        $status = if ($plugin.Loaded) { "✓ Loaded" } else { "○ Available" }
        $statusColor = if ($plugin.Loaded) { "Green" } else { "Gray" }

        Write-Host "  $status " -ForegroundColor $statusColor -NoNewline
        Write-Host $pluginName -ForegroundColor White

        if ($plugin.Loaded -and $plugin.LoadTime) {
            Write-Host "    Loaded: $($plugin.LoadTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Queries the local RAG index.
#>
function Invoke-AstraQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter()]
        [int]$MaxResults = 5
    )

    if (-not (Test-PluginLoaded 'RAG')) {
        Write-Warning "RAG plugin is not loaded. Enable it with: Enable-AstraPlugin RAG"
        return
    }

    Search-AstraIndex -Query $Query -MaxResults $MaxResults
}

<#
.SYNOPSIS
    Tests if a plugin is loaded.
#>
function Test-PluginLoaded {
    param([string]$PluginName)

    return $script:AstraShellPlugins.ContainsKey($PluginName) -and
           $script:AstraShellPlugins[$PluginName].Loaded
}

<#
.SYNOPSIS
    Ensures AstraShell is properly initialized.
#>
function Assert-AstraShellInitialized {
    if (-not $script:AstraShellActive -or -not $script:AstraShellConfig) {
        Write-Verbose "AstraShell not initialized, initializing now..."
        Initialize-AstraShell
    }
}

#endregion

#region Module Initialization

# Auto-initialize when module is imported
$script:AstraShellActive = $false

# Export functions
Export-ModuleMember -Function @(
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
) -Alias @('astra')

#endregion
