#!/usr/bin/env pwsh
# Run-Chimera.ps1
# Project Chimera - Local-First AI Assistant with Tool-Using Capabilities
# Version: 1.0.0

<#
.SYNOPSIS
    Main entry point for Project Chimera AI Assistant.

.DESCRIPTION
    An autonomous AI agent that runs locally using Ollama and has access to various tools
    for web search, file operations, code execution, and system monitoring.

.PARAMETER Model
    The Ollama model to use (default: llama3.1).

.PARAMETER OllamaUrl
    The Ollama API URL (default: http://localhost:11434).

.PARAMETER MaxIterations
    Maximum tool-calling iterations per query (default: 10).

.EXAMPLE
    .\Run-Chimera.ps1 -Model "llama3.1"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Model = "llama3.1",

    [Parameter(Mandatory = $false)]
    [string]$OllamaUrl = "http://localhost:11434",

    [Parameter(Mandatory = $false)]
    [int]$MaxIterations = 10
)

#region Setup and Initialization

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import Chimera Tools module
$ToolsModulePath = Join-Path $ScriptDir "Chimera-Tools.psm1"
if (Test-Path $ToolsModulePath) {
    Import-Module $ToolsModulePath -Force -Global
    Write-Host "[CHIMERA] Tools module loaded successfully" -ForegroundColor Green
} else {
    Write-Host "[CHIMERA] ERROR: Chimera-Tools.psm1 not found at $ToolsModulePath" -ForegroundColor Red
    exit 1
}

# Load system prompt
$SystemPromptPath = Join-Path $ScriptDir "SYSTEM_PROMPT.txt"
if (Test-Path $SystemPromptPath) {
    $SYSTEM_PROMPT = Get-Content -Path $SystemPromptPath -Raw
    Write-Host "[CHIMERA] System prompt loaded successfully" -ForegroundColor Green
} else {
    Write-Host "[CHIMERA] ERROR: SYSTEM_PROMPT.txt not found at $SystemPromptPath" -ForegroundColor Red
    exit 1
}

#endregion

#region Ollama API Functions

function Test-OllamaConnection {
    param([string]$BaseUrl)

    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/tags" -Method Get -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-OllamaChat {
    param(
        [string]$BaseUrl,
        [string]$ModelName,
        [array]$Messages,
        [double]$Temperature = 0.7
    )

    try {
        $body = @{
            model = $ModelName
            messages = $Messages
            stream = $false
            options = @{
                temperature = $Temperature
            }
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod `
            -Uri "$BaseUrl/api/chat" `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -TimeoutSec 120

        return $response.message.content
    }
    catch {
        throw "Ollama API error: $($_.Exception.Message)"
    }
}

#endregion

#region Tool Execution Engine

function Invoke-ChimeraTool {
    param(
        [string]$ToolName,
        [hashtable]$Parameters
    )

    Write-Host "`n[TOOL CALL] $ToolName" -ForegroundColor Cyan
    Write-Host "[PARAMS] $($Parameters | ConvertTo-Json -Compress)" -ForegroundColor DarkCyan

    try {
        $result = switch ($ToolName) {
            "Search-ChimeraWeb" {
                Search-ChimeraWeb @Parameters
            }
            "Read-ChimeraFile" {
                Read-ChimeraFile @Parameters
            }
            "Write-ChimeraFile" {
                Write-ChimeraFile @Parameters
            }
            "Execute-ChimeraScript" {
                Execute-ChimeraScript @Parameters
            }
            "List-ChimeraDirectory" {
                List-ChimeraDirectory @Parameters
            }
            "Get-ChimeraSystemStats" {
                Get-ChimeraSystemStats @Parameters
            }
            default {
                [PSCustomObject]@{
                    Success = $false
                    Error = "Unknown tool: $ToolName"
                }
            }
        }

        Write-Host "[RESULT] Success: $($result.Success)" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
        return $result
    }
    catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}

function Parse-ToolCall {
    param([string]$Response)

    # Look for JSON tool call format: {"tool_to_use": "ToolName", "parameters": {...}}
    # Use regex to extract JSON blocks
    $jsonPattern = '\{[^{}]*"tool_to_use"[^{}]*\}'
    $match = [regex]::Match($Response, $jsonPattern)

    if ($match.Success) {
        try {
            $toolCall = $match.Value | ConvertFrom-Json

            if ($toolCall.tool_to_use -and $toolCall.parameters) {
                return @{
                    HasToolCall = $true
                    ToolName = $toolCall.tool_to_use
                    Parameters = $toolCall.parameters
                    RawResponse = $Response
                }
            }
        }
        catch {
            # JSON parsing failed, no tool call
        }
    }

    # Also check for multi-line JSON (more complex pattern)
    $multilinePattern = '(?s)\{.*?"tool_to_use".*?\}'
    $multiMatch = [regex]::Match($Response, $multilinePattern)

    if ($multiMatch.Success) {
        try {
            $toolCall = $multiMatch.Value | ConvertFrom-Json

            if ($toolCall.tool_to_use -and $toolCall.parameters) {
                return @{
                    HasToolCall = $true
                    ToolName = $toolCall.tool_to_use
                    Parameters = $toolCall.parameters
                    RawResponse = $Response
                }
            }
        }
        catch {
            # JSON parsing failed, no tool call
        }
    }

    return @{
        HasToolCall = $false
        ToolName = $null
        Parameters = $null
        RawResponse = $Response
    }
}

#endregion

#region Agent Loop

function Invoke-ChimeraAgent {
    param(
        [string]$UserQuery,
        [array]$ConversationHistory
    )

    Write-Host "`n[USER] $UserQuery" -ForegroundColor Yellow

    # Build messages array
    $messages = @(
        @{
            role = "system"
            content = $SYSTEM_PROMPT
        }
    )

    # Add conversation history
    $messages += $ConversationHistory

    # Add user query
    $messages += @{
        role = "user"
        content = $UserQuery
    }

    # Agent loop
    $iteration = 0
    $finalResponse = ""

    while ($iteration -lt $MaxIterations) {
        $iteration++
        Write-Host "`n[ITERATION $iteration/$MaxIterations]" -ForegroundColor Magenta

        # Get LLM response
        Write-Host "[THINKING]..." -ForegroundColor DarkGray
        $llmResponse = Invoke-OllamaChat -BaseUrl $OllamaUrl -ModelName $Model -Messages $messages

        # Parse for tool calls
        $parsed = Parse-ToolCall -Response $llmResponse

        if ($parsed.HasToolCall) {
            # Execute tool
            $toolResult = Invoke-ChimeraTool -ToolName $parsed.ToolName -Parameters $parsed.Parameters

            # Add assistant's tool call to messages
            $messages += @{
                role = "assistant"
                content = $llmResponse
            }

            # Add tool result as user message
            $toolResultText = "TOOL_RESULT for $($parsed.ToolName):`n$($toolResult | ConvertTo-Json -Depth 5)"
            $messages += @{
                role = "user"
                content = $toolResultText
            }
        }
        else {
            # No tool call, this is the final response
            $finalResponse = $llmResponse
            Write-Host "`n[ASSISTANT] $finalResponse" -ForegroundColor Green
            break
        }
    }

    if ($iteration -ge $MaxIterations) {
        $finalResponse = "Maximum iterations reached. The task may require manual intervention."
        Write-Host "`n[ASSISTANT] $finalResponse" -ForegroundColor Yellow
    }

    return @{
        Response = $finalResponse
        Messages = $messages
    }
}

#endregion

#region Main REPL

function Start-ChimeraREPL {
    Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                    PROJECT CHIMERA v1.0                       ║
║          Local-First AI Assistant with Tool Capabilities      ║
╚═══════════════════════════════════════════════════════════════╝

Model: $Model
Ollama: $OllamaUrl
Max Iterations: $MaxIterations

Type your query and press Enter. Type 'exit', 'quit', or press Ctrl+C to exit.
Type 'clear' to clear conversation history.
Type 'stats' to see system statistics.

"@ -ForegroundColor Cyan

    # Test Ollama connection
    Write-Host "Testing Ollama connection..." -ForegroundColor Yellow
    if (-not (Test-OllamaConnection -BaseUrl $OllamaUrl)) {
        Write-Host "ERROR: Cannot connect to Ollama at $OllamaUrl" -ForegroundColor Red
        Write-Host "Please ensure Ollama is running: ollama serve" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Connected to Ollama successfully!`n" -ForegroundColor Green

    # Conversation history
    $conversationHistory = @()

    # REPL loop
    while ($true) {
        Write-Host "`n> " -ForegroundColor White -NoNewline
        $userInput = Read-Host

        # Handle commands
        if ($userInput -in @('exit', 'quit', 'q')) {
            Write-Host "`nGoodbye!" -ForegroundColor Cyan
            break
        }

        if ($userInput -eq 'clear') {
            $conversationHistory = @()
            Write-Host "Conversation history cleared." -ForegroundColor Green
            continue
        }

        if ($userInput -eq 'stats') {
            $stats = Get-ChimeraSystemStats
            Write-Host ($stats | ConvertTo-Json -Depth 5) -ForegroundColor Cyan
            continue
        }

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            continue
        }

        # Process query
        try {
            $result = Invoke-ChimeraAgent -UserQuery $userInput -ConversationHistory $conversationHistory

            # Update conversation history with latest exchange
            $conversationHistory += @{
                role = "user"
                content = $userInput
            }
            $conversationHistory += @{
                role = "assistant"
                content = $result.Response
            }

            # Keep history manageable (last 10 exchanges)
            if ($conversationHistory.Count -gt 20) {
                $conversationHistory = $conversationHistory[-20..-1]
            }
        }
        catch {
            Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

#endregion

# Start the REPL
Start-ChimeraREPL
