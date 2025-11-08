<#
.SYNOPSIS
    AstraShell Natural Language Parser Plugin

.DESCRIPTION
    Converts natural language commands into executable PowerShell commands.
    Uses pattern matching and context awareness to interpret user intent.
#>

#region Private Functions

function Get-IntentPattern {
    return @(
        # File operations
        @{
            Pattern = 'find|search|locate.*files?.*larger than (\d+)(MB|GB|KB)'
            Intent = 'FindLargeFiles'
            Confidence = 0.9
        },
        @{
            Pattern = 'find|search|locate.*\.(\w+)\s+files?'
            Intent = 'FindFilesByExtension'
            Confidence = 0.9
        },
        @{
            Pattern = 'list|show.*files?.*in (.*)'
            Intent = 'ListFiles'
            Confidence = 0.85
        },
        @{
            Pattern = 'delete|remove.*files?.*older than (\d+)\s+(days?|hours?|months?)'
            Intent = 'DeleteOldFiles'
            Confidence = 0.95
        },

        # Git operations
        @{
            Pattern = 'create.*branch.*named? [''"]?(\S+)[''"]?'
            Intent = 'CreateGitBranch'
            Confidence = 0.95
        },
        @{
            Pattern = 'commit.*with message [''"](.+)[''"]'
            Intent = 'GitCommit'
            Confidence = 0.95
        },
        @{
            Pattern = 'show|display|view.*git (status|log|diff|branches?)'
            Intent = 'GitInfo'
            Confidence = 0.9
        },

        # System operations
        @{
            Pattern = 'analyze|check|show.*system (resources?|performance|health)'
            Intent = 'SystemAnalysis'
            Confidence = 0.85
        },
        @{
            Pattern = 'kill|stop|terminate.*process.*named? [''"]?(\S+)[''"]?'
            Intent = 'KillProcess'
            Confidence = 0.9
        },
        @{
            Pattern = 'show|list|display.*running processes?'
            Intent = 'ListProcesses'
            Confidence = 0.85
        },

        # Code operations
        @{
            Pattern = 'open.*in (VS Code|Code|VSCode|Visual Studio Code)'
            Intent = 'OpenInVSCode'
            Confidence = 0.9
        },
        @{
            Pattern = 'run|execute|start.*tests?'
            Intent = 'RunTests'
            Confidence = 0.85
        },
        @{
            Pattern = 'build.*project|solution'
            Intent = 'BuildProject'
            Confidence = 0.9
        },

        # Log analysis
        @{
            Pattern = 'analyze|parse|check.*logs?.*errors?'
            Intent = 'AnalyzeLogErrors'
            Confidence = 0.85
        },
        @{
            Pattern = 'summarize|summary.*logs?'
            Intent = 'SummarizeLogs'
            Confidence = 0.8
        }
    )
}

function ConvertTo-FindLargeFilesCommand {
    param(
        [string]$Command,
        [regex]$Pattern
    )

    if ($Command -match $Pattern) {
        $size = [int]$matches[1]
        $unit = $matches[2]

        $sizeInBytes = switch ($unit) {
            'KB' { $size * 1KB }
            'MB' { $size * 1MB }
            'GB' { $size * 1GB }
            default { $size * 1MB }
        }

        # Extract path if mentioned
        $path = if ($Command -match 'in [''"]?([^''"]+)[''"]?') {
            $matches[1]
        } else {
            "."
        }

        # Extract file extension if mentioned
        $extension = if ($Command -match '\.(\w+)\s+files?') {
            "*.$($matches[1])"
        } else {
            "*.*"
        }

        return @(
            [PSCustomObject]@{
                Description = "Find files larger than $size$unit in '$path'"
                Command = "Get-ChildItem -Path '$path' -Recurse -File -Filter '$extension' -ErrorAction SilentlyContinue | Where-Object { `$_.Length -gt $sizeInBytes } | Select-Object Name, @{N='SizeMB';E={[math]::Round(`$_.Length/1MB, 2)}}, FullName | Sort-Object SizeMB -Descending"
            }
        )
    }
}

function ConvertTo-FindFilesByExtensionCommand {
    param(
        [string]$Command,
        [regex]$Pattern
    )

    if ($Command -match '\.(\w+)\s+files?') {
        $extension = $matches[1]

        $path = if ($Command -match 'in [''"]?([^''"]+)[''"]?') {
            $matches[1]
        } else {
            "."
        }

        return @(
            [PSCustomObject]@{
                Description = "Find .$extension files in '$path'"
                Command = "Get-ChildItem -Path '$path' -Recurse -Filter '*.$extension' -ErrorAction SilentlyContinue | Select-Object Name, DirectoryName, @{N='SizeMB';E={[math]::Round(`$_.Length/1MB, 2)}}"
            }
        )
    }
}

function ConvertTo-CreateGitBranchCommand {
    param(
        [string]$Command,
        [regex]$Pattern
    )

    if ($Command -match 'branch.*named? [''"]?([^\s''"]+)[''"]?') {
        $branchName = $matches[1]

        return @(
            [PSCustomObject]@{
                Description = "Create Git branch '$branchName'"
                Command = "git checkout -b '$branchName'"
            }
        )
    }
}

function ConvertTo-GitInfoCommand {
    param(
        [string]$Command
    )

    $steps = @()

    if ($Command -match 'status') {
        $steps += [PSCustomObject]@{
            Description = "Show Git status"
            Command = "git status"
        }
    }

    if ($Command -match 'log') {
        $steps += [PSCustomObject]@{
            Description = "Show Git log"
            Command = "git log --oneline -20"
        }
    }

    if ($Command -match 'diff') {
        $steps += [PSCustomObject]@{
            Description = "Show Git diff"
            Command = "git diff"
        }
    }

    if ($Command -match 'branches?') {
        $steps += [PSCustomObject]@{
            Description = "List Git branches"
            Command = "git branch -a"
        }
    }

    return $steps
}

function ConvertTo-SystemAnalysisCommand {
    param(
        [string]$Command
    )

    $steps = @(
        [PSCustomObject]@{
            Description = "Analyze CPU usage"
            Command = "Get-Counter '\Processor(_Total)\% Processor Time' | Select-Object -ExpandProperty CounterSamples | Select-Object Path, @{N='CPUUsage%';E={[math]::Round(`$_.CookedValue, 2)}}"
        },
        [PSCustomObject]@{
            Description = "Analyze memory usage"
            Command = "`$os = Get-CimInstance Win32_OperatingSystem; [PSCustomObject]@{TotalMemoryGB=[math]::Round(`$os.TotalVisibleMemorySize/1MB, 2); FreeMemoryGB=[math]::Round(`$os.FreePhysicalMemory/1MB, 2); UsedMemoryGB=[math]::Round((`$os.TotalVisibleMemorySize - `$os.FreePhysicalMemory)/1MB, 2); MemoryUsagePercent=[math]::Round(((`$os.TotalVisibleMemorySize - `$os.FreePhysicalMemory) / `$os.TotalVisibleMemorySize) * 100, 2)}"
        },
        [PSCustomObject]@{
            Description = "Check disk space"
            Command = "Get-PSDrive -PSProvider FileSystem | Where-Object { `$_.Used -ne `$null } | Select-Object Name, @{N='UsedGB';E={[math]::Round(`$_.Used/1GB, 2)}}, @{N='FreeGB';E={[math]::Round(`$_.Free/1GB, 2)}}, @{N='TotalGB';E={[math]::Round((`$_.Used + `$_.Free)/1GB, 2)}}, @{N='UsagePercent';E={[math]::Round((`$_.Used / (`$_.Used + `$_.Free)) * 100, 2)}}"
        }
    )

    return $steps
}

function ConvertTo-OpenInVSCodeCommand {
    param(
        [string]$Command
    )

    # Extract file/path references
    $path = if ($Command -match '[''"]([^''"]+)[''"]') {
        $matches[1]
    } else {
        "."
    }

    return @(
        [PSCustomObject]@{
            Description = "Open '$path' in VS Code"
            Command = "code '$path'"
        }
    )
}

function ConvertTo-AnalyzeLogErrorsCommand {
    param(
        [string]$Command
    )

    $steps = @()

    # Find log files
    $path = if ($Command -match 'in [''"]?([^''"]+)[''"]?') {
        $matches[1]
    } else {
        "."
    }

    $timeFilter = ""
    if ($Command -match 'last (\d+)\s+(hours?|days?)') {
        $amount = [int]$matches[1]
        $unit = $matches[2]
        $hours = if ($unit -match 'day') { $amount * 24 } else { $amount }
        $timeFilter = " | Where-Object { `$_.LastWriteTime -gt (Get-Date).AddHours(-$hours) }"
    }

    $steps += [PSCustomObject]@{
        Description = "Find log files in '$path'"
        Command = "Get-ChildItem -Path '$path' -Recurse -Filter '*.log' -ErrorAction SilentlyContinue$timeFilter | Select-Object Name, FullName, @{N='SizeMB';E={[math]::Round(`$_.Length/1MB, 2)}}"
    }

    if ($Command -match 'FATAL_ERROR|fatal|error') {
        $steps += [PSCustomObject]@{
            Description = "Search for error patterns in logs"
            Command = "Get-ChildItem -Path '$path' -Recurse -Filter '*.log' -ErrorAction SilentlyContinue$timeFilter | ForEach-Object { Select-String -Path `$_.FullName -Pattern 'ERROR|FATAL|Exception' -ErrorAction SilentlyContinue } | Group-Object Pattern | Select-Object Name, Count | Sort-Object Count -Descending"
        }
    }

    return $steps
}

#endregion

#region Public Functions

<#
.SYNOPSIS
    Converts natural language to PowerShell commands.
#>
function ConvertFrom-NaturalLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $patterns = Get-IntentPattern
    $matchedIntent = $null
    $matchedPattern = $null
    $confidence = 0

    # Try to match command against patterns
    foreach ($pattern in $patterns) {
        if ($Command -match $pattern.Pattern) {
            $matchedIntent = $pattern.Intent
            $matchedPattern = $pattern.Pattern
            $confidence = $pattern.Confidence
            break
        }
    }

    if (-not $matchedIntent) {
        # No pattern matched - treat as direct PowerShell command
        return [PSCustomObject]@{
            Intent = 'DirectExecution'
            Confidence = 0.5
            PowerShellCommand = $Command
            Steps = @(
                [PSCustomObject]@{
                    Description = "Execute: $Command"
                    Command = $Command
                }
            )
        }
    }

    # Convert based on matched intent
    $steps = switch ($matchedIntent) {
        'FindLargeFiles' {
            ConvertTo-FindLargeFilesCommand -Command $Command -Pattern $matchedPattern
        }
        'FindFilesByExtension' {
            ConvertTo-FindFilesByExtensionCommand -Command $Command -Pattern $matchedPattern
        }
        'CreateGitBranch' {
            ConvertTo-CreateGitBranchCommand -Command $Command -Pattern $matchedPattern
        }
        'GitInfo' {
            ConvertTo-GitInfoCommand -Command $Command
        }
        'SystemAnalysis' {
            ConvertTo-SystemAnalysisCommand -Command $Command
        }
        'OpenInVSCode' {
            ConvertTo-OpenInVSCodeCommand -Command $Command
        }
        'AnalyzeLogErrors' {
            ConvertTo-AnalyzeLogErrorsCommand -Command $Command
        }
        default {
            @([PSCustomObject]@{
                Description = "Execute: $Command"
                Command = $Command
            })
        }
    }

    # Build PowerShell command from steps
    $psCommand = ($steps | ForEach-Object { $_.Command }) -join "; "

    return [PSCustomObject]@{
        Intent = $matchedIntent
        Confidence = $confidence
        PowerShellCommand = $psCommand
        Steps = $steps
    }
}

#endregion

Export-ModuleMember -Function 'ConvertFrom-NaturalLanguage'
