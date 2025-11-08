<#
.SYNOPSIS
    AstraShell Security Plugin

.DESCRIPTION
    Provides security analysis for commands, URLs, and scripts.
    Can integrate with external threat intelligence APIs.
#>

#region Module Variables
$script:MaliciousDomainCache = @{}
$script:SafeDomainCache = @{}
$script:CacheExpiration = 3600 # 1 hour
#endregion

#region Private Functions

function Get-DomainFromUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        $uri = [System.Uri]$Url
        return $uri.Host
    }
    catch {
        # Try to extract domain with regex
        if ($Url -match '(?:https?://)?(?:www\.)?([^/]+)') {
            return $matches[1]
        }
        return $null
    }
}

function Test-CachedDomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain
    )

    $now = Get-Date

    # Check malicious cache
    if ($script:MaliciousDomainCache.ContainsKey($Domain)) {
        $entry = $script:MaliciousDomainCache[$Domain]
        if (($now - $entry.Timestamp).TotalSeconds -lt $script:CacheExpiration) {
            return [PSCustomObject]@{
                IsMalicious = $true
                Source = 'Cache'
                Reason = $entry.Reason
            }
        }
    }

    # Check safe cache
    if ($script:SafeDomainCache.ContainsKey($Domain)) {
        $entry = $script:SafeDomainCache[$Domain]
        if (($now - $entry.Timestamp).TotalSeconds -lt $script:CacheExpiration) {
            return [PSCustomObject]@{
                IsMalicious = $false
                Source = 'Cache'
            }
        }
    }

    return $null
}

function Test-KnownMaliciousPatterns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $risks = @()

    # Check for common suspicious patterns
    $suspiciousPatterns = @(
        @{
            Pattern = 'Invoke-Expression.*\$'
            Risk = 'Medium'
            Reason = 'Dynamic code execution with Invoke-Expression can be dangerous'
        },
        @{
            Pattern = 'iex\s+\$'
            Risk = 'Medium'
            Reason = 'Dynamic code execution (iex alias) detected'
        },
        @{
            Pattern = 'DownloadString|DownloadFile'
            Risk = 'Medium'
            Reason = 'File download detected - verify source is trusted'
        },
        @{
            Pattern = 'Start-Process.*-WindowStyle\s+Hidden'
            Risk = 'Medium'
            Reason = 'Hidden process execution detected'
        },
        @{
            Pattern = 'Remove-Item.*-Recurse.*-Force'
            Risk = 'High'
            Reason = 'Recursive force deletion - potential data loss'
        },
        @{
            Pattern = 'Format-Volume|Clear-Disk'
            Risk = 'Critical'
            Reason = 'Disk formatting command detected - potential data destruction'
        },
        @{
            Pattern = 'Get-Credential|ConvertTo-SecureString'
            Risk = 'Low'
            Reason = 'Credential handling detected - ensure this is expected'
        },
        @{
            Pattern = '-EncodedCommand|-enc\s'
            Risk = 'High'
            Reason = 'Encoded PowerShell command - potentially obfuscated malicious code'
        },
        @{
            Pattern = 'Disable-WindowsDefender|Set-MpPreference.*DisableRealtimeMonitoring'
            Risk = 'Critical'
            Reason = 'Attempt to disable security software detected'
        }
    )

    foreach ($pattern in $suspiciousPatterns) {
        if ($Command -match $pattern.Pattern) {
            $risks += [PSCustomObject]@{
                Risk = $pattern.Risk
                Reason = $pattern.Reason
                Pattern = $pattern.Pattern
            }
        }
    }

    return $risks
}

function Invoke-VirusTotalCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    try {
        $url = "https://www.virustotal.com/api/v3/domains/$Domain"
        $headers = @{
            'x-apikey' = $ApiKey
        }

        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop

        $malicious = $response.data.attributes.last_analysis_stats.malicious
        $suspicious = $response.data.attributes.last_analysis_stats.suspicious

        return [PSCustomObject]@{
            IsMalicious = ($malicious -gt 0 -or $suspicious -gt 2)
            MaliciousCount = $malicious
            SuspiciousCount = $suspicious
            Source = 'VirusTotal'
        }
    }
    catch {
        Write-Warning "VirusTotal API check failed: $_"
        return $null
    }
}

#endregion

#region Public Functions

<#
.SYNOPSIS
    Performs security check on a command.
#>
function Invoke-AstraSecurityCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $config = Get-AstraConfig -Section 'Security'
    if (-not $config) {
        # Security not configured, allow by default
        return [PSCustomObject]@{
            Blocked = $false
            Risks = @()
        }
    }

    $blocked = $false
    $risks = @()

    # Check for suspicious patterns
    $patternRisks = Test-KnownMaliciousPatterns -Command $Command

    foreach ($risk in $patternRisks) {
        $risks += $risk

        # Block critical risks
        if ($risk.Risk -eq 'Critical') {
            $blocked = $true
        }
    }

    # Check for URLs in command
    $urlPattern = 'https?://[^\s]+'
    $urls = [regex]::Matches($Command, $urlPattern) | ForEach-Object { $_.Value }

    foreach ($url in $urls) {
        $domain = Get-DomainFromUrl -Url $url

        if ($domain) {
            # Check cache first
            $cachedResult = Test-CachedDomain -Domain $domain

            if ($cachedResult) {
                if ($cachedResult.IsMalicious) {
                    $risks += [PSCustomObject]@{
                        Risk = 'Critical'
                        Reason = "Malicious domain detected: $domain ($($cachedResult.Reason))"
                        Domain = $domain
                    }
                    $blocked = $true
                }
            }
            elseif ($config.EnableVirusTotalCheck -and $config.VirusTotalApiKey) {
                # Check with VirusTotal
                Write-Verbose "Checking domain with VirusTotal: $domain"
                $vtResult = Invoke-VirusTotalCheck -Domain $domain -ApiKey $config.VirusTotalApiKey

                if ($vtResult -and $vtResult.IsMalicious) {
                    # Cache malicious domain
                    $script:MaliciousDomainCache[$domain] = @{
                        Timestamp = Get-Date
                        Reason = "VirusTotal: $($vtResult.MaliciousCount) malicious, $($vtResult.SuspiciousCount) suspicious"
                    }

                    $risks += [PSCustomObject]@{
                        Risk = 'Critical'
                        Reason = "Malicious domain detected by VirusTotal: $domain"
                        Domain = $domain
                        Details = $vtResult
                    }
                    $blocked = $true
                }
                elseif ($vtResult) {
                    # Cache safe domain
                    $script:SafeDomainCache[$domain] = @{
                        Timestamp = Get-Date
                    }
                }
            }
        }
    }

    # Determine final block status
    if ($blocked -and -not $config.BlockMaliciousUrls) {
        $blocked = $false
    }

    return [PSCustomObject]@{
        Blocked = $blocked
        Risks = $risks
        Reason = if ($blocked) {
            ($risks | Where-Object { $_.Risk -eq 'Critical' } | Select-Object -First 1).Reason
        } else { $null }
    }
}

<#
.SYNOPSIS
    Analyzes a script file for security risks.
#>
function Test-AstraScriptSecurity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script file not found: $ScriptPath"
        return
    }

    Write-Host "🔒 Analyzing script security: $ScriptPath" -ForegroundColor Cyan

    $content = Get-Content $ScriptPath -Raw
    $result = Invoke-AstraSecurityCheck -Command $content

    if ($result.Risks.Count -eq 0) {
        Write-Host "✅ No security risks detected" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠️ Security Analysis Results:" -ForegroundColor Yellow
        Write-Host ""

        $riskGroups = $result.Risks | Group-Object -Property Risk

        foreach ($group in $riskGroups | Sort-Object Name) {
            $color = switch ($group.Name) {
                'Critical' { 'Red' }
                'High' { 'Yellow' }
                'Medium' { 'Yellow' }
                'Low' { 'Gray' }
            }

            Write-Host "  $($group.Name) Risk(s): $($group.Count)" -ForegroundColor $color

            foreach ($risk in $group.Group) {
                Write-Host "    • $($risk.Reason)" -ForegroundColor Gray
            }
            Write-Host ""
        }

        if ($result.Blocked) {
            Write-Host "🚫 This script contains critical security risks and would be blocked from execution." -ForegroundColor Red
        }
    }

    return $result
}

<#
.SYNOPSIS
    Checks if a URL/domain is safe.
#>
function Test-AstraDomainSafety {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $domain = Get-DomainFromUrl -Url $Url

    if (-not $domain) {
        Write-Error "Could not extract domain from URL: $Url"
        return
    }

    Write-Host "🔍 Checking domain safety: $domain" -ForegroundColor Cyan

    # Check cache
    $cachedResult = Test-CachedDomain -Domain $domain

    if ($cachedResult) {
        if ($cachedResult.IsMalicious) {
            Write-Host "🚫 Domain is MALICIOUS (cached result)" -ForegroundColor Red
            Write-Host "   Reason: $($cachedResult.Reason)" -ForegroundColor Yellow
            return $cachedResult
        }
        else {
            Write-Host "✅ Domain is SAFE (cached result)" -ForegroundColor Green
            return $cachedResult
        }
    }

    # Check with VirusTotal if configured
    $config = Get-AstraConfig -Section 'Security'

    if ($config.EnableVirusTotalCheck -and $config.VirusTotalApiKey) {
        $vtResult = Invoke-VirusTotalCheck -Domain $domain -ApiKey $config.VirusTotalApiKey

        if ($vtResult) {
            if ($vtResult.IsMalicious) {
                Write-Host "🚫 Domain is MALICIOUS" -ForegroundColor Red
                Write-Host "   VirusTotal: $($vtResult.MaliciousCount) malicious, $($vtResult.SuspiciousCount) suspicious detections" -ForegroundColor Yellow

                # Cache result
                $script:MaliciousDomainCache[$domain] = @{
                    Timestamp = Get-Date
                    Reason = "VirusTotal: $($vtResult.MaliciousCount) malicious"
                }
            }
            else {
                Write-Host "✅ Domain is SAFE" -ForegroundColor Green
                Write-Host "   VirusTotal: No malicious detections" -ForegroundColor Gray

                # Cache result
                $script:SafeDomainCache[$domain] = @{
                    Timestamp = Get-Date
                }
            }

            return $vtResult
        }
    }
    else {
        Write-Warning "VirusTotal integration not configured. Enable with:"
        Write-Host "  Set-AstraConfig -Section Security -Key EnableVirusTotalCheck -Value `$true" -ForegroundColor Gray
        Write-Host "  Set-AstraConfig -Section Security -Key VirusTotalApiKey -Value 'your-api-key'" -ForegroundColor Gray
    }

    # Default: assume safe if no checks could be performed
    Write-Host "⚪ No threats detected (limited checking)" -ForegroundColor Gray

    return [PSCustomObject]@{
        IsMalicious = $false
        Source = 'None'
    }
}

<#
.SYNOPSIS
    Clears the domain safety cache.
#>
function Clear-AstraSecurityCache {
    [CmdletBinding()]
    param()

    $script:MaliciousDomainCache = @{}
    $script:SafeDomainCache = @{}

    Write-Host "✓ Security cache cleared" -ForegroundColor Green
}

<#
.SYNOPSIS
    Gets security statistics.
#>
function Get-AstraSecurityStats {
    [CmdletBinding()]
    param()

    Write-Host "`n🔒 Security Statistics:" -ForegroundColor Cyan
    Write-Host "  Cached malicious domains: $($script:MaliciousDomainCache.Count)" -ForegroundColor Red
    Write-Host "  Cached safe domains: $($script:SafeDomainCache.Count)" -ForegroundColor Green

    if ($script:MaliciousDomainCache.Count -gt 0) {
        Write-Host "`n  Malicious Domains:" -ForegroundColor Red
        foreach ($domain in $script:MaliciousDomainCache.Keys) {
            Write-Host "    • $domain - $($script:MaliciousDomainCache[$domain].Reason)" -ForegroundColor Gray
        }
    }

    Write-Host ""
}

#endregion

Export-ModuleMember -Function @(
    'Invoke-AstraSecurityCheck',
    'Test-AstraScriptSecurity',
    'Test-AstraDomainSafety',
    'Clear-AstraSecurityCache',
    'Get-AstraSecurityStats'
)
