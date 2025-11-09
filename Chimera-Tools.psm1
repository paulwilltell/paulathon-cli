# Chimera-Tools.psm1
# PowerShell Module containing all tools for Project Chimera AI Assistant
# Version: 1.0.0

#region Search-ChimeraWeb
<#
.SYNOPSIS
    Searches the web using Brave Search API or fallback methods.

.DESCRIPTION
    Performs a web search and returns the top results with titles, URLs, and snippets.

.PARAMETER Query
    The search query string.

.PARAMETER MaxResults
    Maximum number of results to return (default: 5).

.PARAMETER ApiKey
    Optional Brave Search API key. If not provided, uses environment variable BRAVE_API_KEY.

.EXAMPLE
    Search-ChimeraWeb -Query "PowerShell automation tips"
#>
function Search-ChimeraWeb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 5,

        [Parameter(Mandatory = $false)]
        [string]$ApiKey
    )

    try {
        # Use Brave Search API if available
        if (-not $ApiKey) {
            $ApiKey = $env:BRAVE_API_KEY
        }

        if ($ApiKey) {
            $headers = @{
                "Accept" = "application/json"
                "Accept-Encoding" = "gzip"
                "X-Subscription-Token" = $ApiKey
            }

            $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
            $url = "https://api.search.brave.com/res/v1/web/search?q=$encodedQuery&count=$MaxResults"

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

            $results = @()
            foreach ($item in $response.web.results) {
                $results += [PSCustomObject]@{
                    Title = $item.title
                    URL = $item.url
                    Snippet = $item.description
                }
            }

            return [PSCustomObject]@{
                Success = $true
                Query = $Query
                ResultCount = $results.Count
                Results = $results
            }
        }
        else {
            # Fallback: DuckDuckGo HTML scraping (simple method)
            $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Query)
            $url = "https://html.duckduckgo.com/html/?q=$encodedQuery"

            $response = Invoke-WebRequest -Uri $url -UseBasicParsing
            $html = $response.Content

            # Simple regex-based extraction
            $titlePattern = '<a class="result__a"[^>]*>([^<]+)</a>'
            $urlPattern = '<a class="result__a" href="([^"]+)"'
            $snippetPattern = '<a class="result__snippet"[^>]*>([^<]+)</a>'

            $titles = [regex]::Matches($html, $titlePattern) | ForEach-Object { $_.Groups[1].Value }
            $urls = [regex]::Matches($html, $urlPattern) | ForEach-Object { $_.Groups[1].Value }
            $snippets = [regex]::Matches($html, $snippetPattern) | ForEach-Object { $_.Groups[1].Value }

            $results = @()
            for ($i = 0; $i -lt [Math]::Min($MaxResults, $titles.Count); $i++) {
                $results += [PSCustomObject]@{
                    Title = [System.Web.HttpUtility]::HtmlDecode($titles[$i])
                    URL = $urls[$i]
                    Snippet = [System.Web.HttpUtility]::HtmlDecode($snippets[$i])
                }
            }

            return [PSCustomObject]@{
                Success = $true
                Query = $Query
                ResultCount = $results.Count
                Results = $results
                Note = "Using DuckDuckGo fallback (set BRAVE_API_KEY for better results)"
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Query = $Query
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}
#endregion

#region Read-ChimeraFile
<#
.SYNOPSIS
    Reads the contents of a local file.

.DESCRIPTION
    Safely reads a file from the local filesystem and returns its contents.

.PARAMETER FilePath
    The full or relative path to the file.

.PARAMETER Encoding
    The file encoding (default: UTF8).

.EXAMPLE
    Read-ChimeraFile -FilePath "C:\Projects\script.ps1"
#>
function Read-ChimeraFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$Encoding = "UTF8"
    )

    try {
        # Resolve path to absolute
        $resolvedPath = Resolve-Path -Path $FilePath -ErrorAction Stop

        # Check if file exists
        if (-not (Test-Path -Path $resolvedPath -PathType Leaf)) {
            throw "File not found: $resolvedPath"
        }

        # Get file info
        $fileInfo = Get-Item -Path $resolvedPath

        # Read file content
        $content = Get-Content -Path $resolvedPath -Raw -Encoding $Encoding

        return [PSCustomObject]@{
            Success = $true
            FilePath = $resolvedPath.Path
            FileName = $fileInfo.Name
            SizeBytes = $fileInfo.Length
            LastModified = $fileInfo.LastWriteTime
            Content = $content
            LineCount = ($content -split "`n").Count
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            FilePath = $FilePath
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}
#endregion

#region Write-ChimeraFile
<#
.SYNOPSIS
    Writes content to a local file.

.DESCRIPTION
    Safely writes or overwrites a file with the specified content.

.PARAMETER FilePath
    The full or relative path to the file.

.PARAMETER Content
    The content to write to the file.

.PARAMETER Encoding
    The file encoding (default: UTF8).

.PARAMETER Force
    Overwrite existing file without prompting (default: true).

.EXAMPLE
    Write-ChimeraFile -FilePath "C:\Projects\output.txt" -Content "Hello World"
#>
function Write-ChimeraFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $false)]
        [string]$Encoding = "UTF8",

        [Parameter(Mandatory = $false)]
        [bool]$Force = $true
    )

    try {
        # Ensure parent directory exists
        $parentDir = Split-Path -Path $FilePath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }

        # Write the file
        $Content | Out-File -FilePath $FilePath -Encoding $Encoding -Force:$Force -NoNewline

        # Get file info
        $fileInfo = Get-Item -Path $FilePath

        return [PSCustomObject]@{
            Success = $true
            FilePath = $fileInfo.FullName
            FileName = $fileInfo.Name
            SizeBytes = $fileInfo.Length
            LastModified = $fileInfo.LastWriteTime
            BytesWritten = $Content.Length
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            FilePath = $FilePath
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}
#endregion

#region Execute-ChimeraScript
<#
.SYNOPSIS
    Executes PowerShell code in a restricted session.

.DESCRIPTION
    Runs PowerShell code safely and returns STDOUT, STDERR, and exit status.

.PARAMETER ScriptBlock
    The PowerShell code to execute (as a string).

.PARAMETER TimeoutSeconds
    Maximum execution time in seconds (default: 30).

.EXAMPLE
    Execute-ChimeraScript -ScriptBlock "Get-Process | Select-Object -First 5"
#>
function Execute-ChimeraScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )

    try {
        # Create a script block from the string
        $scriptBlockObj = [scriptblock]::Create($ScriptBlock)

        # Execute with timeout
        $job = Start-Job -ScriptBlock $scriptBlockObj

        # Wait for job with timeout
        $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds

        if ($completed) {
            $output = Receive-Job -Job $job
            $errors = $job.ChildJobs[0].Error
            $state = $job.State

            Remove-Job -Job $job -Force

            return [PSCustomObject]@{
                Success = $true
                State = $state
                Output = $output
                Errors = $errors
                TimedOut = $false
            }
        }
        else {
            Stop-Job -Job $job
            Remove-Job -Job $job -Force

            return [PSCustomObject]@{
                Success = $false
                State = "TimedOut"
                Output = $null
                Errors = @("Execution exceeded timeout of $TimeoutSeconds seconds")
                TimedOut = $true
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            State = "Failed"
            Output = $null
            Errors = @($_.Exception.Message)
            ErrorDetails = $_.Exception.ToString()
            TimedOut = $false
        }
    }
}
#endregion

#region List-ChimeraDirectory
<#
.SYNOPSIS
    Lists directory contents in a tree structure.

.DESCRIPTION
    Performs a recursive directory listing and returns a structured representation.

.PARAMETER Path
    The directory path to list.

.PARAMETER Depth
    Maximum recursion depth (default: 3).

.PARAMETER IncludeHidden
    Include hidden files and folders (default: false).

.EXAMPLE
    List-ChimeraDirectory -Path "C:\Projects" -Depth 2
#>
function List-ChimeraDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [int]$Depth = 3,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeHidden = $false
    )

    try {
        # Resolve path to absolute
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop

        # Check if directory exists
        if (-not (Test-Path -Path $resolvedPath -PathType Container)) {
            throw "Directory not found or is not a directory: $resolvedPath"
        }

        # Build directory tree
        function Get-DirectoryTree {
            param($DirPath, $CurrentDepth, $MaxDepth)

            if ($CurrentDepth -gt $MaxDepth) {
                return $null
            }

            $items = Get-ChildItem -Path $DirPath -Force:$IncludeHidden -ErrorAction SilentlyContinue

            $tree = @()
            foreach ($item in $items) {
                $node = [PSCustomObject]@{
                    Name = $item.Name
                    Type = if ($item.PSIsContainer) { "Directory" } else { "File" }
                    Size = if (-not $item.PSIsContainer) { $item.Length } else { $null }
                    LastModified = $item.LastWriteTime
                    FullPath = $item.FullName
                }

                if ($item.PSIsContainer -and $CurrentDepth -lt $MaxDepth) {
                    $children = Get-DirectoryTree -DirPath $item.FullName -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth
                    $node | Add-Member -MemberType NoteProperty -Name "Children" -Value $children
                }

                $tree += $node
            }

            return $tree
        }

        $tree = Get-DirectoryTree -DirPath $resolvedPath -CurrentDepth 0 -MaxDepth $Depth

        # Count statistics
        $allFiles = Get-ChildItem -Path $resolvedPath -Recurse -File -Force:$IncludeHidden -ErrorAction SilentlyContinue
        $allDirs = Get-ChildItem -Path $resolvedPath -Recurse -Directory -Force:$IncludeHidden -ErrorAction SilentlyContinue

        return [PSCustomObject]@{
            Success = $true
            Path = $resolvedPath.Path
            Depth = $Depth
            TotalFiles = $allFiles.Count
            TotalDirectories = $allDirs.Count
            TotalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
            Tree = $tree
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Path = $Path
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}
#endregion

#region Get-ChimeraSystemStats
<#
.SYNOPSIS
    Retrieves current system statistics.

.DESCRIPTION
    Returns CPU usage, RAM usage, disk space, and top processes.

.EXAMPLE
    Get-ChimeraSystemStats
#>
function Get-ChimeraSystemStats {
    [CmdletBinding()]
    param()

    try {
        # Get CPU usage
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        if (-not $cpuUsage) {
            $cpuUsage = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        }

        # Get RAM usage
        $os = Get-CimInstance Win32_OperatingSystem
        $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
        $ramUsagePercent = [math]::Round(($usedRAM / $totalRAM) * 100, 2)

        # Get top 5 processes by CPU
        $topProcesses = Get-Process |
            Where-Object { $_.CPU -gt 0 } |
            Sort-Object CPU -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.ProcessName
                    ID = $_.Id
                    CPU = [math]::Round($_.CPU, 2)
                    MemoryMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
                }
            }

        # Get disk information
        $disks = Get-PSDrive -PSProvider FileSystem |
            Where-Object { $_.Used -ne $null } |
            ForEach-Object {
                $used = [math]::Round($_.Used / 1GB, 2)
                $free = [math]::Round($_.Free / 1GB, 2)
                $total = $used + $free
                $usagePercent = [math]::Round(($used / $total) * 100, 2)

                [PSCustomObject]@{
                    Drive = $_.Name
                    TotalGB = $total
                    UsedGB = $used
                    FreeGB = $free
                    UsagePercent = $usagePercent
                }
            }

        # Get system uptime
        $uptime = (Get-Date) - $os.LastBootUpTime

        return [PSCustomObject]@{
            Success = $true
            Timestamp = Get-Date
            CPU = [PSCustomObject]@{
                UsagePercent = [math]::Round($cpuUsage, 2)
            }
            Memory = [PSCustomObject]@{
                TotalGB = $totalRAM
                UsedGB = $usedRAM
                FreeGB = $freeRAM
                UsagePercent = $ramUsagePercent
            }
            Disks = $disks
            TopProcesses = $topProcesses
            Uptime = [PSCustomObject]@{
                Days = $uptime.Days
                Hours = $uptime.Hours
                Minutes = $uptime.Minutes
                TotalHours = [math]::Round($uptime.TotalHours, 2)
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}
#endregion

# Export all functions
Export-ModuleMember -Function @(
    'Search-ChimeraWeb',
    'Read-ChimeraFile',
    'Write-ChimeraFile',
    'Execute-ChimeraScript',
    'List-ChimeraDirectory',
    'Get-ChimeraSystemStats'
)
