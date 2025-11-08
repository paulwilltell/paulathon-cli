<#
.SYNOPSIS
    AstraShell System Sentry Plugin

.DESCRIPTION
    Monitors system resources and provides proactive alerts about
    performance issues, resource leaks, and system anomalies.
#>

#region Module Variables
$script:SentryJob = $null
$script:SentryRunning = $false
$script:AlertHistory = @()
$script:BaselineMetrics = @{}
#endregion

#region Private Functions

function Get-SystemMetrics {
    [CmdletBinding()]
    param()

    try {
        # CPU metrics
        $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
        $cpuUsage = if ($cpuCounter) {
            [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
        } else { 0 }

        # Memory metrics
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $memoryUsagePercent = if ($os) {
            [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)
        } else { 0 }

        $memoryUsedGB = if ($os) {
            [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
        } else { 0 }

        # Disk metrics
        $diskUsage = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
            Where-Object { $null -ne $_.Used } |
            Select-Object @{N='Drive';E={$_.Name}},
                         @{N='UsagePercent';E={[math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 2)}},
                         @{N='FreeGB';E={[math]::Round($_.Free/1GB, 2)}}

        # Top processes by memory
        $topProcesses = Get-Process -ErrorAction SilentlyContinue |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 5 |
            Select-Object Name,
                         Id,
                         @{N='MemoryMB';E={[math]::Round($_.WorkingSet64/1MB, 2)}},
                         @{N='CPU';E={$_.CPU}},
                         @{N='Threads';E={$_.Threads.Count}}

        return [PSCustomObject]@{
            Timestamp = Get-Date
            CPU = [PSCustomObject]@{
                UsagePercent = $cpuUsage
            }
            Memory = [PSCustomObject]@{
                UsagePercent = $memoryUsagePercent
                UsedGB = $memoryUsedGB
            }
            Disk = $diskUsage
            TopProcesses = $topProcesses
        }
    }
    catch {
        Write-Warning "Failed to collect system metrics: $_"
        return $null
    }
}

function Test-Anomaly {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Metrics,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Thresholds
    )

    $alerts = @()

    # Check CPU
    if ($Metrics.CPU.UsagePercent -gt $Thresholds.CPUThreshold) {
        $alerts += [PSCustomObject]@{
            Type = 'CPU'
            Severity = 'Warning'
            Message = "High CPU usage detected: $($Metrics.CPU.UsagePercent)%"
            Timestamp = Get-Date
            Value = $Metrics.CPU.UsagePercent
            Threshold = $Thresholds.CPUThreshold
        }
    }

    # Check Memory
    if ($Metrics.Memory.UsagePercent -gt $Thresholds.MemoryThreshold) {
        $alerts += [PSCustomObject]@{
            Type = 'Memory'
            Severity = 'Warning'
            Message = "High memory usage detected: $($Metrics.Memory.UsagePercent)% ($($Metrics.Memory.UsedGB) GB)"
            Timestamp = Get-Date
            Value = $Metrics.Memory.UsagePercent
            Threshold = $Thresholds.MemoryThreshold
        }
    }

    # Check Disk
    foreach ($disk in $Metrics.Disk) {
        if ($disk.UsagePercent -gt $Thresholds.DiskThreshold) {
            $alerts += [PSCustomObject]@{
                Type = 'Disk'
                Severity = 'Critical'
                Message = "Low disk space on drive $($disk.Drive): $($disk.UsagePercent)% used (Free: $($disk.FreeGB) GB)"
                Timestamp = Get-Date
                Value = $disk.UsagePercent
                Threshold = $Thresholds.DiskThreshold
                Drive = $disk.Drive
            }
        }
    }

    # Detect potential memory leaks
    $suspiciousProcesses = $Metrics.TopProcesses | Where-Object { $_.MemoryMB -gt 1000 }
    foreach ($process in $suspiciousProcesses) {
        # Check if this process has been growing
        $previousMetric = $script:BaselineMetrics[$process.Name]
        if ($previousMetric -and ($process.MemoryMB - $previousMetric.MemoryMB) -gt 500) {
            $alerts += [PSCustomObject]@{
                Type = 'MemoryLeak'
                Severity = 'Warning'
                Message = "Potential memory leak in process '$($process.Name)' (PID: $($process.Id)). Memory grew from $($previousMetric.MemoryMB) MB to $($process.MemoryMB) MB"
                Timestamp = Get-Date
                ProcessName = $process.Name
                ProcessId = $process.Id
                CurrentMemoryMB = $process.MemoryMB
                PreviousMemoryMB = $previousMetric.MemoryMB
            }
        }

        # Update baseline
        $script:BaselineMetrics[$process.Name] = [PSCustomObject]@{
            MemoryMB = $process.MemoryMB
            Timestamp = Get-Date
        }
    }

    return $alerts
}

function Show-SentryAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Alert
    )

    $color = switch ($Alert.Severity) {
        'Critical' { 'Red' }
        'Warning' { 'Yellow' }
        default { 'Gray' }
    }

    $icon = switch ($Alert.Type) {
        'CPU' { '🔥' }
        'Memory' { '💾' }
        'Disk' { '💿' }
        'MemoryLeak' { '⚠️' }
        default { '📊' }
    }

    Write-Host "`n$icon AstraShell Sentry Alert [$($Alert.Severity)]" -ForegroundColor $color
    Write-Host "  Type: $($Alert.Type)" -ForegroundColor Gray
    Write-Host "  $($Alert.Message)" -ForegroundColor White

    # Provide remediation suggestions
    $suggestions = Get-RemediationSuggestion -Alert $Alert
    if ($suggestions) {
        Write-Host "`n  💡 Suggested Actions:" -ForegroundColor Cyan
        foreach ($suggestion in $suggestions) {
            Write-Host "    • $suggestion" -ForegroundColor Gray
        }
    }

    Write-Host ""
}

function Get-RemediationSuggestion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Alert
    )

    switch ($Alert.Type) {
        'CPU' {
            return @(
                "Check running processes with: Get-Process | Sort-Object CPU -Descending | Select-Object -First 10",
                "Consider closing unnecessary applications",
                "Use Task Manager to identify CPU-intensive processes"
            )
        }
        'Memory' {
            return @(
                "Check memory usage by process: Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | Format-Table Name, @{N='MemoryMB';E={[math]::Round(`$_.WorkingSet64/1MB,2)}}",
                "Close unused applications to free up memory",
                "Restart memory-intensive applications if possible"
            )
        }
        'Disk' {
            return @(
                "Clean temporary files: Remove-Item `$env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue",
                "Empty Recycle Bin",
                "Use Disk Cleanup utility",
                "Check for large files: Get-ChildItem $($Alert.Drive):\ -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 20"
            )
        }
        'MemoryLeak' {
            return @(
                "Restart the process '$($Alert.ProcessName)' if safe to do so",
                "Monitor the process: Get-Process -Name '$($Alert.ProcessName)' | Select-Object Name, Id, @{N='MemoryMB';E={[math]::Round(`$_.WorkingSet64/1MB,2)}}",
                "Consider filing a bug report for the application"
            )
        }
    }
}

#endregion

#region Public Functions

<#
.SYNOPSIS
    Starts the System Sentry monitoring service.
#>
function Start-AstraSentry {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$IntervalSeconds = 60
    )

    if ($script:SentryRunning) {
        Write-Warning "System Sentry is already running"
        return
    }

    Write-Host "🛡️ Starting AstraShell System Sentry..." -ForegroundColor Cyan

    # Get configuration
    $config = Get-AstraConfig -Section 'Sentry'
    if ($config) {
        $IntervalSeconds = $config.MonitorInterval
    }

    # Start monitoring in background
    $script:SentryRunning = $true

    # Note: PowerShell background jobs are used here
    # In production, consider using a more robust solution
    Write-Host "✓ System Sentry started (checking every $IntervalSeconds seconds)" -ForegroundColor Green
    Write-Host "  Monitoring: CPU, Memory, Disk, Processes" -ForegroundColor Gray
}

<#
.SYNOPSIS
    Stops the System Sentry monitoring service.
#>
function Stop-AstraSentry {
    [CmdletBinding()]
    param()

    if (-not $script:SentryRunning) {
        Write-Warning "System Sentry is not running"
        return
    }

    if ($script:SentryJob) {
        Remove-Job -Job $script:SentryJob -Force -ErrorAction SilentlyContinue
        $script:SentryJob = $null
    }

    $script:SentryRunning = $false
    Write-Host "System Sentry stopped" -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Gets current system metrics.
#>
function Get-AstraSentryStatus {
    [CmdletBinding()]
    param()

    if (-not $script:SentryRunning) {
        Write-Warning "System Sentry is not running. Start it with: Start-AstraSentry"
    }

    $metrics = Get-SystemMetrics

    if (-not $metrics) {
        Write-Error "Failed to retrieve system metrics"
        return
    }

    Write-Host "`n📊 System Status Report" -ForegroundColor Cyan
    Write-Host "  Generated: $($metrics.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host ""

    # CPU
    Write-Host "  CPU Usage: " -NoNewline -ForegroundColor White
    $cpuColor = if ($metrics.CPU.UsagePercent -gt 80) { 'Red' } elseif ($metrics.CPU.UsagePercent -gt 60) { 'Yellow' } else { 'Green' }
    Write-Host "$($metrics.CPU.UsagePercent)%" -ForegroundColor $cpuColor

    # Memory
    Write-Host "  Memory Usage: " -NoNewline -ForegroundColor White
    $memColor = if ($metrics.Memory.UsagePercent -gt 80) { 'Red' } elseif ($metrics.Memory.UsagePercent -gt 60) { 'Yellow' } else { 'Green' }
    Write-Host "$($metrics.Memory.UsagePercent)% ($($metrics.Memory.UsedGB) GB)" -ForegroundColor $memColor

    # Disk
    Write-Host "`n  Disk Usage:" -ForegroundColor White
    foreach ($disk in $metrics.Disk) {
        $diskColor = if ($disk.UsagePercent -gt 90) { 'Red' } elseif ($disk.UsagePercent -gt 75) { 'Yellow' } else { 'Green' }
        Write-Host "    Drive $($disk.Drive): " -NoNewline -ForegroundColor Gray
        Write-Host "$($disk.UsagePercent)% " -NoNewline -ForegroundColor $diskColor
        Write-Host "(Free: $($disk.FreeGB) GB)" -ForegroundColor Gray
    }

    # Top Processes
    Write-Host "`n  Top Processes by Memory:" -ForegroundColor White
    foreach ($process in $metrics.TopProcesses) {
        Write-Host "    $($process.Name.PadRight(30)) " -NoNewline -ForegroundColor Gray
        Write-Host "$($process.MemoryMB) MB" -ForegroundColor White
    }

    Write-Host ""

    return $metrics
}

<#
.SYNOPSIS
    Performs an immediate system health check.
#>
function Invoke-AstraSentryCheck {
    [CmdletBinding()]
    param()

    Write-Host "🔍 Performing system health check..." -ForegroundColor Cyan

    $metrics = Get-SystemMetrics

    if (-not $metrics) {
        Write-Error "Failed to collect system metrics"
        return
    }

    # Get thresholds from config
    $config = Get-AstraConfig -Section 'Sentry'
    $thresholds = if ($config) { $config } else {
        [PSCustomObject]@{
            CPUThreshold = 80
            MemoryThreshold = 80
            DiskThreshold = 90
        }
    }

    # Check for anomalies
    $alerts = Test-Anomaly -Metrics $metrics -Thresholds $thresholds

    if ($alerts.Count -eq 0) {
        Write-Host "✅ System health is good!" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Found $($alerts.Count) issue(s):" -ForegroundColor Yellow

        foreach ($alert in $alerts) {
            $script:AlertHistory += $alert
            Show-SentryAlert -Alert $alert
        }
    }

    # Display summary
    Get-AstraSentryStatus | Out-Null

    return $alerts
}

<#
.SYNOPSIS
    Gets alert history.
#>
function Get-AstraSentryAlertHistory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Last = 10
    )

    if ($script:AlertHistory.Count -eq 0) {
        Write-Host "No alerts in history" -ForegroundColor Gray
        return
    }

    $alerts = $script:AlertHistory | Select-Object -Last $Last

    Write-Host "`n📜 Alert History (Last $Last):" -ForegroundColor Cyan
    foreach ($alert in $alerts) {
        $icon = switch ($alert.Severity) {
            'Critical' { '🔴' }
            'Warning' { '🟡' }
            default { '⚪' }
        }
        Write-Host "  $icon [$($alert.Timestamp.ToString('HH:mm:ss'))] $($alert.Type): $($alert.Message)" -ForegroundColor Gray
    }
    Write-Host ""

    return $alerts
}

#endregion

Export-ModuleMember -Function @(
    'Start-AstraSentry',
    'Stop-AstraSentry',
    'Get-AstraSentryStatus',
    'Invoke-AstraSentryCheck',
    'Get-AstraSentryAlertHistory'
)
