# Project Chimera - Architecture Overview

This document provides a comprehensive technical overview of Project Chimera's architecture, design decisions, and implementation details.

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Tool Execution Model](#tool-execution-model)
6. [Design Decisions](#design-decisions)
7. [Security Considerations](#security-considerations)
8. [Extensibility](#extensibility)

---

## System Overview

Project Chimera is a **local-first, tool-using AI agent** built on three core principles:

1. **Autonomy**: The AI can take actions, not just provide information
2. **Privacy**: Everything runs locally, no cloud dependencies
3. **Extensibility**: Easy to add new tools and capabilities

### Core Components

```
┌─────────────────────────────────────────────────┐
│           Project Chimera Stack                 │
├─────────────────────────────────────────────────┤
│  User Interface (PowerShell REPL)               │
├─────────────────────────────────────────────────┤
│  Agent Loop (Run-Chimera.ps1)                   │
│  ├─ Conversation Management                     │
│  ├─ Tool Call Parser                            │
│  └─ Orchestration Logic                         │
├─────────────────────────────────────────────────┤
│  Tools Module (Chimera-Tools.psm1)              │
│  ├─ Search-ChimeraWeb                           │
│  ├─ Read-ChimeraFile                            │
│  ├─ Write-ChimeraFile                           │
│  ├─ Execute-ChimeraScript                       │
│  ├─ List-ChimeraDirectory                       │
│  └─ Get-ChimeraSystemStats                      │
├─────────────────────────────────────────────────┤
│  LLM Runtime (Ollama)                           │
│  └─ Local Model (Llama 3.1, Mistral, etc.)     │
├─────────────────────────────────────────────────┤
│  Operating System (Windows PowerShell 7)        │
└─────────────────────────────────────────────────┘
```

---

## Architecture Diagram

### High-Level Flow

```
┌──────────┐
│   User   │
└────┬─────┘
     │ Natural Language Query
     ▼
┌─────────────────────┐
│  REPL Interface     │
│  (Start-ChimeraREPL)│
└─────────┬───────────┘
          │
          ▼
┌──────────────────────────────────────────┐
│     Agent Loop (Invoke-ChimeraAgent)     │
│  ┌────────────────────────────────────┐  │
│  │  1. Build Message History          │  │
│  │  2. Send to LLM                    │  │
│  │  3. Parse Response for Tool Calls  │  │
│  │  4. Execute Tool (if needed)       │  │
│  │  5. Add Result to History          │  │
│  │  6. Repeat until final answer      │  │
│  └────────────────────────────────────┘  │
└─────────┬───────────────┬────────────────┘
          │               │
          │ Tool Call     │ Chat Request
          ▼               ▼
┌──────────────────┐   ┌─────────────┐
│  Chimera Tools   │   │   Ollama    │
│  Module          │   │   API       │
│  ├─ Web Search   │   │             │
│  ├─ File I/O     │   │  (Local     │
│  ├─ Code Exec    │   │   LLM)      │
│  └─ System Info  │   │             │
└──────────────────┘   └─────────────┘
```

### Detailed Agent Loop Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Agent Loop Iteration                     │
└─────────────────────────────────────────────────────────────┘

User Query: "Search for Python best practices and save to file"

┌───────────────────────────────────────────────────────────┐
│ Iteration 1                                               │
├───────────────────────────────────────────────────────────┤
│ Messages: [system, user_query]                           │
│          ↓                                                │
│ LLM Response: {"tool_to_use": "Search-ChimeraWeb", ...}  │
│          ↓                                                │
│ Parser: HasToolCall=true                                 │
│          ↓                                                │
│ Execute: Search-ChimeraWeb(Query="Python best practices")│
│          ↓                                                │
│ Tool Result: {Success=true, Results=[...]}               │
│          ↓                                                │
│ Messages: [..., assistant_tool_call, tool_result]        │
└───────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────┐
│ Iteration 2                                               │
├───────────────────────────────────────────────────────────┤
│ Messages: [...previous..., tool_result]                  │
│          ↓                                                │
│ LLM Response: {"tool_to_use": "Write-ChimeraFile", ...}  │
│          ↓                                                │
│ Parser: HasToolCall=true                                 │
│          ↓                                                │
│ Execute: Write-ChimeraFile(FilePath="...", Content="...")│
│          ↓                                                │
│ Tool Result: {Success=true, FilePath="..."}              │
│          ↓                                                │
│ Messages: [..., assistant_tool_call, tool_result]        │
└───────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────┐
│ Iteration 3 (Final)                                       │
├───────────────────────────────────────────────────────────┤
│ Messages: [...previous..., tool_result]                  │
│          ↓                                                │
│ LLM Response: "I've searched for Python best practices   │
│               and saved the results to best_practices.txt"│
│          ↓                                                │
│ Parser: HasToolCall=false (final answer)                 │
│          ↓                                                │
│ Return Response to User                                   │
└───────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Run-Chimera.ps1 (Agent Core)

**Responsibilities**:
- REPL interface for user interaction
- Message history management
- Tool call detection and parsing
- Orchestrating LLM + Tool interactions
- Error handling and recovery

**Key Functions**:

```powershell
# Main REPL loop
Start-ChimeraREPL
  ├─ Handles user input
  ├─ Manages conversation state
  └─ Invokes agent for each query

# Agent orchestration
Invoke-ChimeraAgent($UserQuery, $ConversationHistory)
  ├─ Builds message array with system prompt
  ├─ Iterates until final response or max iterations
  ├─ Calls Invoke-OllamaChat for LLM inference
  ├─ Calls Parse-ToolCall to detect tool usage
  └─ Calls Invoke-ChimeraTool to execute tools

# Tool call parsing
Parse-ToolCall($Response)
  ├─ Regex-based JSON extraction
  ├─ Handles single-line and multi-line JSON
  └─ Returns structured tool call object

# Tool execution router
Invoke-ChimeraTool($ToolName, $Parameters)
  ├─ Switch statement to route to correct tool
  ├─ Calls tool from Chimera-Tools module
  └─ Returns structured result
```

**Error Handling**:
- Timeout protection on LLM calls (120s)
- Max iteration limit (default: 10)
- Try-catch blocks around tool execution
- Graceful degradation on tool failures

### 2. Chimera-Tools.psm1 (Tool Library)

**Design Pattern**: Each tool follows a consistent pattern:

```powershell
function ToolName {
    [CmdletBinding()]
    param(...)

    try {
        # 1. Validate inputs
        # 2. Execute core logic
        # 3. Return success result
        return [PSCustomObject]@{
            Success = $true
            # ... result data ...
        }
    }
    catch {
        # 4. Return error result
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
            ErrorDetails = $_.Exception.ToString()
        }
    }
}
```

**Tool Categories**:

1. **Information Retrieval**: Search-ChimeraWeb
2. **File Operations**: Read-ChimeraFile, Write-ChimeraFile, List-ChimeraDirectory
3. **Code Execution**: Execute-ChimeraScript
4. **System Monitoring**: Get-ChimeraSystemStats

**Return Type Convention**: All tools return `PSCustomObject` with:
- `Success` (bool): Indicates if operation succeeded
- Result data (varies by tool)
- `Error` / `ErrorDetails` (on failure)

### 3. SYSTEM_PROMPT.txt (Agent Instructions)

**Purpose**: Teaches the LLM how to be an agent

**Structure**:
1. **Identity & Mission**: Defines agent role
2. **Tool Catalog**: Lists all available tools with parameters
3. **Protocol**: Exact JSON format for tool calls
4. **Examples**: Demonstrates multi-step workflows
5. **Guidelines**: Best practices and limitations

**Critical Elements**:
- JSON schema for tool calls
- Clear parameter documentation
- TOOL_RESULT format specification
- Multi-step reasoning examples

### 4. Ollama Integration

**API Endpoints Used**:
```
GET  /api/tags         - List models
POST /api/chat         - Chat completion
```

**Message Format**:
```json
{
  "model": "llama3.1",
  "messages": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ],
  "stream": false,
  "options": {
    "temperature": 0.7
  }
}
```

**Response Format**:
```json
{
  "message": {
    "role": "assistant",
    "content": "..."
  },
  "done": true
}
```

---

## Data Flow

### Complete Request-Response Cycle

```
User Input
    ↓
[REPL] Capture input
    ↓
[Agent] Build message history
    ├─ Add system prompt
    ├─ Add conversation history
    └─ Add current user query
    ↓
[Ollama API] Send chat request
    ↓
[LLM] Generate response
    ↓
[Agent] Receive LLM response
    ↓
[Parser] Check for tool call JSON
    ├─ YES: Tool call detected
    │   ↓
    │   [Router] Route to correct tool
    │   ↓
    │   [Tool] Execute operation
    │   ↓
    │   [Tool] Return result
    │   ↓
    │   [Agent] Add tool result to messages
    │   ↓
    │   [Agent] Loop back to Ollama API ──┐
    │                                      │
    └─ NO: Final answer                   │
        ↓                                  │
        [REPL] Display response            │
        ↓                                  │
        [History] Store exchange           │
        ↓                                  │
        Wait for next user input ←─────────┘
```

### Conversation State Management

```
$conversationHistory = @(
    @{role="user", content="Query 1"},
    @{role="assistant", content="Response 1"},
    @{role="user", content="Query 2"},
    @{role="assistant", content="Tool call JSON"},
    @{role="user", content="TOOL_RESULT for ..."},
    @{role="assistant", content="Response 2"},
    ...
)

# Trimmed to last 20 messages to manage context window
```

---

## Tool Execution Model

### Sandboxing Strategy

1. **Execute-ChimeraScript**: Uses PowerShell jobs
   - Runs in separate runspace
   - Timeout protection (default 30s)
   - Captures STDOUT/STDERR
   - Isolated from main session

2. **File Operations**: Path validation
   - Resolves relative paths to absolute
   - Checks file/directory existence
   - Validates write permissions
   - Creates parent directories as needed

3. **Web Search**: Network isolation
   - API-based (no arbitrary URL fetching)
   - Rate limiting (implicit via API)
   - HTML sanitization on fallback

### Error Handling Strategy

```
Tool Execution
    ├─ Try
    │   ├─ Validate inputs
    │   ├─ Execute operation
    │   └─ Return {Success: true, ...}
    └─ Catch
        └─ Return {Success: false, Error: "...", ErrorDetails: "..."}

Agent Loop
    ├─ Check tool result Success field
    ├─ If false: Include error in next LLM message
    └─ LLM can retry with corrected parameters or explain failure
```

---

## Design Decisions

### Why PowerShell 7?

1. **Cross-platform**: Runs on Windows, Linux, macOS
2. **Rich ecosystem**: Direct access to .NET libraries
3. **System integration**: Native OS management capabilities
4. **Object pipeline**: Structured data handling
5. **Job control**: Built-in sandboxing for code execution

### Why Ollama?

1. **Local-first**: Complete privacy, no API costs
2. **Model agnostic**: Supports Llama, Mistral, CodeLlama, etc.
3. **Simple API**: RESTful, easy to integrate
4. **Resource efficient**: Optimized inference engine
5. **Active development**: Regular updates and improvements

### Why Tool-First Architecture?

1. **Separation of concerns**: Tools are independent, testable modules
2. **Extensibility**: Add tools without modifying core agent
3. **Reusability**: Tools can be used outside of Chimera
4. **Debuggability**: Each tool has clear inputs/outputs
5. **LLM flexibility**: Can swap models without changing tools

### Tool Call Format Choice

**Chosen**: JSON object `{"tool_to_use": "...", "parameters": {...}}`

**Alternatives considered**:
- XML: Too verbose, harder for LLM to generate
- Function calling (OpenAI style): Not supported by all local models
- Natural language parsing: Unreliable, brittle

**Rationale**: JSON is structured, parseable, and most LLMs are trained on it extensively.

---

## Security Considerations

### Threat Model

**Trusted User**: Assumes user operates in good faith
**Untrusted Input**: File paths and web content are untrusted

### Mitigations

1. **Code Execution**:
   - Runs in PowerShell job (isolated runspace)
   - Timeout enforcement
   - No interactive input allowed
   - Recommendation: Add confirmation for destructive operations

2. **File Operations**:
   - Path validation and resolution
   - No arbitrary file deletion (not implemented)
   - Write operations create parent directories safely
   - Recommendation: Add path whitelist/blacklist

3. **Web Search**:
   - API-based (controlled endpoints)
   - No arbitrary URL fetching
   - HTML content sanitization
   - Recommendation: Add content filtering

4. **System Stats**:
   - Read-only operations
   - No privilege escalation
   - Standard WMI/CIM queries

### Recommendations for Production

1. **Add audit logging**: Record all tool calls
2. **Implement confirmations**: Ask before destructive operations
3. **Add path restrictions**: Whitelist accessible directories
4. **Rate limiting**: Prevent tool abuse
5. **User authentication**: Multi-user scenarios
6. **Input sanitization**: Validate all parameters

---

## Extensibility

### Adding New Tools

**Step 1**: Add function to `Chimera-Tools.psm1`

```powershell
function Get-ChimeraWeather {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Location
    )

    try {
        # Implementation here
        return [PSCustomObject]@{
            Success = $true
            Location = $Location
            Temperature = 72
            Conditions = "Sunny"
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function @(
    # ... existing tools ...
    'Get-ChimeraWeather'  # Add here
)
```

**Step 2**: Add route in `Run-Chimera.ps1`

```powershell
function Invoke-ChimeraTool {
    param(...)

    $result = switch ($ToolName) {
        # ... existing tools ...
        "Get-ChimeraWeather" {
            Get-ChimeraWeather @Parameters
        }
    }
}
```

**Step 3**: Document in `SYSTEM_PROMPT.txt`

```
### 7. Get-ChimeraWeather
**Purpose**: Get weather information for a location
**Parameters**:
- Location (string, required): City name or ZIP code

**Example**:
{"tool_to_use": "Get-ChimeraWeather", "parameters": {"Location": "Seattle"}}
```

### Integration Points

1. **Alternative LLM backends**:
   - Replace `Invoke-OllamaChat` with API of choice
   - OpenAI, Claude, local models via llama.cpp, etc.

2. **GUI frontend**:
   - Replace `Start-ChimeraREPL` with GUI event loop
   - Same agent logic, different interface

3. **Web API**:
   - Wrap `Invoke-ChimeraAgent` in REST endpoints
   - Enable remote access (with authentication!)

4. **Database integration**:
   - Add tools for SQL queries
   - Structured data retrieval and updates

---

## Performance Characteristics

### Latency Breakdown (Typical)

```
User Input → LLM Response: 2-10s (depends on model size)
Tool Execution:
  - File I/O: <100ms
  - Web Search: 1-3s (network dependent)
  - Code Execution: Variable (timeout: 30s)
  - System Stats: 100-500ms

Total per iteration: 2-15s
Multi-step tasks: 10-60s (3-5 iterations average)
```

### Resource Usage

```
Memory:
  - Ollama (8B model): 4-6 GB
  - PowerShell: 50-100 MB
  - Total: ~5-7 GB

CPU:
  - LLM inference: High during generation
  - Idle: Minimal
  - Tool execution: Variable

Disk:
  - Models: 4-20 GB depending on size
  - Conversation logs: Minimal
```

### Optimization Opportunities

1. **Model selection**: Smaller models for faster responses
2. **Prompt caching**: Reuse system prompt embedding
3. **Tool batching**: Execute multiple independent tools in parallel
4. **Response streaming**: Stream LLM output for perceived speed
5. **GPU acceleration**: Use CUDA for faster inference

---

## Future Enhancements

### Planned Features

1. **Parallel tool execution**: Run independent tools concurrently
2. **Persistent memory**: Vector DB for long-term knowledge
3. **Plugin system**: Dynamic tool loading
4. **Multi-agent**: Specialized agents for different domains
5. **Self-improvement**: Agent learns from feedback

### Research Directions

1. **Autonomous goal setting**: Agent proposes tasks
2. **Chain-of-thought**: Explicit reasoning traces
3. **Tool synthesis**: Agent creates new tools
4. **Multi-modal**: Image, audio input/output
5. **Collaborative agents**: Multiple agents working together

---

## Conclusion

Project Chimera demonstrates a clean, extensible architecture for building tool-using AI agents on local infrastructure. The separation of concerns between the agent loop, tool library, and LLM runtime enables independent evolution of each component.

Key architectural strengths:
- **Modularity**: Clear component boundaries
- **Testability**: Tools are pure functions
- **Extensibility**: Easy to add capabilities
- **Privacy**: Fully local operation
- **Portability**: PowerShell runs everywhere

This foundation can scale from personal automation to enterprise agentic systems.

---

**Built with**: PowerShell 7, Ollama, and a vision for autonomous AI assistants.
