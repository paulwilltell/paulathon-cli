<#
.SYNOPSIS
    AstraShell RAG (Retrieval-Augmented Generation) Plugin

.DESCRIPTION
    Indexes local files and provides semantic search capabilities
    for code, documentation, and other text-based content.
#>

#region Module Variables
$script:IndexPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Data\index.json"
$script:Index = $null
$script:LastIndexUpdate = $null
#endregion

#region Private Functions

function Initialize-Index {
    [CmdletBinding()]
    param()

    if (Test-Path $script:IndexPath) {
        try {
            $indexContent = Get-Content $script:IndexPath -Raw | ConvertFrom-Json
            $script:Index = @{
                Files = $indexContent.Files
                Metadata = $indexContent.Metadata
            }
            $script:LastIndexUpdate = [DateTime]$script:Index.Metadata.LastUpdate
            Write-Verbose "Index loaded: $($script:Index.Files.Count) files"
        }
        catch {
            Write-Warning "Failed to load index: $_"
            $script:Index = @{
                Files = @()
                Metadata = @{
                    Created = Get-Date
                    LastUpdate = Get-Date
                    TotalFiles = 0
                }
            }
        }
    }
    else {
        $script:Index = @{
            Files = @()
            Metadata = @{
                Created = Get-Date
                LastUpdate = Get-Date
                TotalFiles = 0
            }
        }
    }
}

function Save-Index {
    [CmdletBinding()]
    param()

    try {
        $script:Index.Metadata.LastUpdate = Get-Date
        $script:Index.Metadata.TotalFiles = $script:Index.Files.Count

        $indexJson = @{
            Files = $script:Index.Files
            Metadata = $script:Index.Metadata
        } | ConvertTo-Json -Depth 10 -Compress

        $indexDir = Split-Path $script:IndexPath -Parent
        if (-not (Test-Path $indexDir)) {
            New-Item -Path $indexDir -ItemType Directory -Force | Out-Null
        }

        $indexJson | Set-Content -Path $script:IndexPath -Encoding UTF8
        $script:LastIndexUpdate = Get-Date
        Write-Verbose "Index saved: $($script:Index.Files.Count) files"
    }
    catch {
        Write-Error "Failed to save index: $_"
    }
}

function Get-FileSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        $file = Get-Item $FilePath -ErrorAction Stop
        return "$($file.FullName)|$($file.LastWriteTime.Ticks)|$($file.Length)"
    }
    catch {
        return $null
    }
}

function Index-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    try {
        # Read file content
        $content = Get-Content $File.FullName -Raw -ErrorAction Stop

        # Extract metadata based on file type
        $metadata = @{
            Extension = $File.Extension
            Language = Get-FileLanguage -Extension $File.Extension
        }

        # For code files, extract functions/classes
        if ($metadata.Language) {
            $symbols = Extract-CodeSymbols -Content $content -Language $metadata.Language
            $metadata.Symbols = $symbols
        }

        # Create searchable text (lowercase for case-insensitive search)
        $searchableText = $content.ToLower()

        # Create index entry
        return [PSCustomObject]@{
            Path = $File.FullName
            Name = $File.Name
            Directory = $File.DirectoryName
            Extension = $File.Extension
            SizeBytes = $File.Length
            LastModified = $File.LastWriteTime
            Signature = Get-FileSignature -FilePath $File.FullName
            Content = $content
            SearchableText = $searchableText
            Metadata = $metadata
            IndexedDate = Get-Date
        }
    }
    catch {
        Write-Warning "Failed to index file $($File.FullName): $_"
        return $null
    }
}

function Get-FileLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension
    )

    switch ($Extension.ToLower()) {
        '.ps1' { return 'PowerShell' }
        '.psm1' { return 'PowerShell' }
        '.psd1' { return 'PowerShell' }
        '.py' { return 'Python' }
        '.js' { return 'JavaScript' }
        '.ts' { return 'TypeScript' }
        '.cs' { return 'CSharp' }
        '.java' { return 'Java' }
        '.cpp' { return 'CPlusPlus' }
        '.c' { return 'C' }
        '.go' { return 'Go' }
        '.rs' { return 'Rust' }
        '.rb' { return 'Ruby' }
        '.php' { return 'PHP' }
        default { return $null }
    }
}

function Extract-CodeSymbols {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Language
    )

    $symbols = @{
        Functions = @()
        Classes = @()
    }

    switch ($Language) {
        'PowerShell' {
            # Extract functions
            $functionMatches = [regex]::Matches($Content, 'function\s+([\w-]+)')
            foreach ($match in $functionMatches) {
                $symbols.Functions += $match.Groups[1].Value
            }

            # Extract classes
            $classMatches = [regex]::Matches($Content, 'class\s+(\w+)')
            foreach ($match in $classMatches) {
                $symbols.Classes += $match.Groups[1].Value
            }
        }
        'Python' {
            $functionMatches = [regex]::Matches($Content, 'def\s+(\w+)')
            foreach ($match in $functionMatches) {
                $symbols.Functions += $match.Groups[1].Value
            }

            $classMatches = [regex]::Matches($Content, 'class\s+(\w+)')
            foreach ($match in $classMatches) {
                $symbols.Classes += $match.Groups[1].Value
            }
        }
        'JavaScript' {
            $functionMatches = [regex]::Matches($Content, 'function\s+(\w+)|const\s+(\w+)\s*=\s*\(')
            foreach ($match in $functionMatches) {
                $name = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                if ($name) { $symbols.Functions += $name }
            }

            $classMatches = [regex]::Matches($Content, 'class\s+(\w+)')
            foreach ($match in $classMatches) {
                $symbols.Classes += $match.Groups[1].Value
            }
        }
    }

    return $symbols
}

function Search-IndexContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter()]
        [int]$MaxResults = 10
    )

    if (-not $script:Index -or $script:Index.Files.Count -eq 0) {
        return @()
    }

    $queryLower = $Query.ToLower()
    $queryTerms = $queryLower -split '\s+' | Where-Object { $_.Length -gt 2 }

    $results = @()

    foreach ($file in $script:Index.Files) {
        $score = 0

        # Check if file exists
        if (-not (Test-Path $file.Path)) {
            continue
        }

        # Exact phrase match (highest score)
        if ($file.SearchableText -match [regex]::Escape($queryLower)) {
            $score += 100
        }

        # Individual term matches
        foreach ($term in $queryTerms) {
            $matches = ([regex]::Matches($file.SearchableText, [regex]::Escape($term))).Count
            $score += $matches * 10
        }

        # Symbol matches (functions/classes) get bonus
        if ($file.Metadata.Symbols) {
            foreach ($func in $file.Metadata.Symbols.Functions) {
                if ($func.ToLower() -match $queryLower) {
                    $score += 50
                }
            }
            foreach ($class in $file.Metadata.Symbols.Classes) {
                if ($class.ToLower() -match $queryLower) {
                    $score += 50
                }
            }
        }

        # Filename match gets bonus
        if ($file.Name.ToLower() -match $queryLower) {
            $score += 30
        }

        if ($score -gt 0) {
            $results += [PSCustomObject]@{
                File = $file
                Score = $score
            }
        }
    }

    return $results |
        Sort-Object -Property Score -Descending |
        Select-Object -First $MaxResults
}

#endregion

#region Public Functions

<#
.SYNOPSIS
    Builds or updates the local file index.
#>
function Update-AstraIndex {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Paths,

        [Parameter()]
        [switch]$Force
    )

    Write-Host "🔍 Building local file index..." -ForegroundColor Cyan

    # Initialize index
    Initialize-Index

    # Get paths from config if not specified
    if (-not $Paths) {
        $config = Get-AstraConfig -Section 'RAG'
        if ($config -and $config.IndexPaths -and $config.IndexPaths.Count -gt 0) {
            $Paths = $config.IndexPaths
        }
        else {
            Write-Warning "No paths specified and no paths configured in RAG.IndexPaths"
            Write-Host "Add paths with: Set-AstraConfig -Section RAG -Key IndexPaths -Value @('C:\Projects', 'D:\Docs')"
            return
        }
    }

    $config = Get-AstraConfig -Section 'RAG'
    $fileTypes = if ($config -and $config.FileTypes) { $config.FileTypes } else {
        @('.ps1', '.psm1', '.psd1', '.md', '.txt', '.json', '.xml', '.yml', '.yaml')
    }
    $maxFileSize = if ($config -and $config.MaxFileSize) { $config.MaxFileSize } else { 10MB }

    $totalFiles = 0
    $indexedFiles = 0
    $skippedFiles = 0

    foreach ($path in $Paths) {
        if (-not (Test-Path $path)) {
            Write-Warning "Path not found: $path"
            continue
        }

        Write-Host "`n  Scanning: $path" -ForegroundColor Gray

        # Get all files matching configured types
        $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $fileTypes -contains $_.Extension -and
                $_.Length -le $maxFileSize
            }

        foreach ($file in $files) {
            $totalFiles++

            # Check if file needs reindexing
            $signature = Get-FileSignature -FilePath $file.FullName
            $existingEntry = $script:Index.Files | Where-Object { $_.Path -eq $file.FullName } | Select-Object -First 1

            if (-not $Force -and $existingEntry -and $existingEntry.Signature -eq $signature) {
                $skippedFiles++
                Write-Verbose "Skipped (unchanged): $($file.FullName)"
                continue
            }

            # Index the file
            $indexEntry = Index-File -File $file

            if ($indexEntry) {
                # Remove old entry if exists
                $script:Index.Files = @($script:Index.Files | Where-Object { $_.Path -ne $file.FullName })

                # Add new entry
                $script:Index.Files += $indexEntry
                $indexedFiles++

                if ($indexedFiles % 10 -eq 0) {
                    Write-Host "    Indexed $indexedFiles files..." -ForegroundColor DarkGray
                }
            }
        }
    }

    # Save index
    Save-Index

    Write-Host "`n✅ Indexing complete!" -ForegroundColor Green
    Write-Host "  Total files scanned: $totalFiles" -ForegroundColor Gray
    Write-Host "  Files indexed: $indexedFiles" -ForegroundColor Gray
    Write-Host "  Files skipped (unchanged): $skippedFiles" -ForegroundColor Gray
    Write-Host "  Index size: $($script:Index.Files.Count) files" -ForegroundColor Gray
}

<#
.SYNOPSIS
    Searches the local file index.
#>
function Search-AstraIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter()]
        [int]$MaxResults = 5,

        [Parameter()]
        [switch]$ShowContent
    )

    Initialize-Index

    if (-not $script:Index -or $script:Index.Files.Count -eq 0) {
        Write-Warning "Index is empty. Build it with: Update-AstraIndex"
        return
    }

    Write-Host "🔎 Searching index for: '$Query'" -ForegroundColor Cyan

    $results = Search-IndexContent -Query $Query -MaxResults $MaxResults

    if ($results.Count -eq 0) {
        Write-Host "No results found" -ForegroundColor Yellow
        return
    }

    Write-Host "`n📄 Found $($results.Count) result(s):" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $results.Count; $i++) {
        $result = $results[$i]
        $file = $result.File

        Write-Host "  $($i + 1). " -NoNewline -ForegroundColor Gray
        Write-Host $file.Name -ForegroundColor White -NoNewline
        Write-Host " (Score: $($result.Score))" -ForegroundColor DarkGray

        Write-Host "     Path: $($file.Path)" -ForegroundColor Gray
        Write-Host "     Type: $($file.Metadata.Language ?? $file.Extension)" -ForegroundColor Gray

        if ($file.Metadata.Symbols) {
            if ($file.Metadata.Symbols.Functions.Count -gt 0) {
                Write-Host "     Functions: $($file.Metadata.Symbols.Functions -join ', ')" -ForegroundColor DarkCyan
            }
            if ($file.Metadata.Symbols.Classes.Count -gt 0) {
                Write-Host "     Classes: $($file.Metadata.Symbols.Classes -join ', ')" -ForegroundColor DarkMagenta
            }
        }

        if ($ShowContent) {
            # Show relevant snippet
            $snippet = Get-ContentSnippet -Content $file.Content -Query $Query
            if ($snippet) {
                Write-Host "`n     Snippet:" -ForegroundColor Cyan
                Write-Host "     $snippet" -ForegroundColor White
            }
        }

        Write-Host ""
    }

    return $results
}

<#
.SYNOPSIS
    Gets statistics about the current index.
#>
function Get-AstraIndexStats {
    [CmdletBinding()]
    param()

    Initialize-Index

    if (-not $script:Index) {
        Write-Host "Index not initialized" -ForegroundColor Yellow
        return
    }

    $stats = [PSCustomObject]@{
        TotalFiles = $script:Index.Files.Count
        LastUpdate = $script:Index.Metadata.LastUpdate
        Languages = @{}
        TotalSizeBytes = 0
    }

    # Calculate stats
    foreach ($file in $script:Index.Files) {
        $stats.TotalSizeBytes += $file.SizeBytes

        $lang = $file.Metadata.Language ?? 'Other'
        if (-not $stats.Languages.ContainsKey($lang)) {
            $stats.Languages[$lang] = 0
        }
        $stats.Languages[$lang]++
    }

    Write-Host "`n📊 Index Statistics:" -ForegroundColor Cyan
    Write-Host "  Total Files: $($stats.TotalFiles)" -ForegroundColor White
    Write-Host "  Total Size: $([math]::Round($stats.TotalSizeBytes / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "  Last Updated: $($stats.LastUpdate)" -ForegroundColor Gray
    Write-Host "`n  Files by Language:" -ForegroundColor White
    foreach ($lang in $stats.Languages.Keys | Sort-Object) {
        Write-Host "    $lang : $($stats.Languages[$lang])" -ForegroundColor Gray
    }
    Write-Host ""

    return $stats
}

<#
.SYNOPSIS
    Clears the file index.
#>
function Clear-AstraIndex {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("file index", "Clear")) {
        $script:Index = @{
            Files = @()
            Metadata = @{
                Created = Get-Date
                LastUpdate = Get-Date
                TotalFiles = 0
            }
        }

        Save-Index
        Write-Host "✓ Index cleared" -ForegroundColor Green
    }
}

function Get-ContentSnippet {
    param(
        [string]$Content,
        [string]$Query,
        [int]$ContextChars = 100
    )

    $index = $Content.ToLower().IndexOf($Query.ToLower())
    if ($index -lt 0) { return $null }

    $start = [Math]::Max(0, $index - $ContextChars)
    $length = [Math]::Min($Content.Length - $start, $ContextChars * 2 + $Query.Length)

    $snippet = $Content.Substring($start, $length).Trim()
    if ($start -gt 0) { $snippet = "..." + $snippet }
    if ($start + $length -lt $Content.Length) { $snippet = $snippet + "..." }

    return $snippet
}

#endregion

Export-ModuleMember -Function @(
    'Update-AstraIndex',
    'Search-AstraIndex',
    'Get-AstraIndexStats',
    'Clear-AstraIndex'
)
