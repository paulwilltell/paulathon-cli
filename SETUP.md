# Project Chimera - Setup Guide

Complete installation and setup instructions for Project Chimera, your local-first AI assistant.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Running Chimera](#running-chimera)
5. [Usage Examples](#usage-examples)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Configuration](#advanced-configuration)

---

## Prerequisites

### Required Software

1. **PowerShell 7+** (PowerShell Core)
   - Check version: `pwsh --version`
   - If not installed, download from: https://github.com/PowerShell/PowerShell/releases
   - Windows: `winget install Microsoft.PowerShell`
   - Or use the MSI installer from the releases page

2. **Ollama** (Local LLM Runtime)
   - Download from: https://ollama.ai
   - Windows: Download and run the installer
   - Verify installation: `ollama --version`

### System Requirements

- **OS**: Windows 10/11 (Linux/macOS also supported with minor adjustments)
- **RAM**: Minimum 8GB (16GB+ recommended for larger models)
- **Disk**: 10GB+ free space for models
- **CPU**: Modern multi-core processor (GPU optional but beneficial)

---

## Installation

### Step 1: Install Ollama

1. **Download Ollama**:
   - Visit https://ollama.ai
   - Download the Windows installer
   - Run the installer and follow prompts

2. **Verify Installation**:
   ```powershell
   ollama --version
   ```

3. **Start Ollama Service**:
   ```powershell
   ollama serve
   ```

   Leave this terminal open. Ollama will run in the background.

### Step 2: Download a Model

Open a new PowerShell terminal and download a model:

```powershell
# Recommended: Llama 3.1 (8B parameters, ~4.7GB)
ollama pull llama3.1

# Alternatives:
# ollama pull llama3.2        # Smaller, faster (3B)
# ollama pull mistral         # Alternative model
# ollama pull codellama       # Specialized for coding
```

Wait for the download to complete (may take several minutes).

### Step 3: Verify Model

```powershell
# List installed models
ollama list

# Test the model
ollama run llama3.1 "Hello, who are you?"
```

Type `/bye` to exit the test.

### Step 4: Install Project Chimera

1. **Clone or Download** the Project Chimera files to a directory:
   ```powershell
   # Create project directory
   New-Item -Path "C:\ProjectChimera" -ItemType Directory -Force
   cd C:\ProjectChimera
   ```

2. **Copy Files**:
   Ensure you have these files in the directory:
   - `Run-Chimera.ps1` - Main agent script
   - `Chimera-Tools.psm1` - Tools module
   - `SYSTEM_PROMPT.txt` - System prompt
   - `SETUP.md` - This file
   - `ARCHITECTURE.md` - System architecture documentation

3. **Set Execution Policy** (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## Configuration

### Optional: Web Search API

For enhanced web search capabilities, configure a Brave Search API key:

1. **Get API Key**:
   - Visit https://brave.com/search/api/
   - Sign up for a free account
   - Get your API key

2. **Set Environment Variable**:
   ```powershell
   # Temporary (current session only)
   $env:BRAVE_API_KEY = "your-api-key-here"

   # Permanent (Windows)
   [System.Environment]::SetEnvironmentVariable('BRAVE_API_KEY', 'your-api-key-here', 'User')
   ```

   Without this key, Chimera will fall back to DuckDuckGo search (limited functionality).

### Optional: Customize Model

Edit `Run-Chimera.ps1` to change default model:

```powershell
# Line ~30
[string]$Model = "llama3.1",  # Change to your preferred model
```

Or pass it as a parameter when running:

```powershell
.\Run-Chimera.ps1 -Model "mistral"
```

---

## Running Chimera

### Basic Usage

1. **Ensure Ollama is Running**:
   ```powershell
   # In one terminal (if not already running)
   ollama serve
   ```

2. **Start Chimera** (in a new terminal):
   ```powershell
   cd C:\ProjectChimera
   pwsh .\Run-Chimera.ps1
   ```

3. **Interact**:
   ```
   > What are my system stats?
   > Search the web for PowerShell 7 best practices
   > Read the file C:\Scripts\test.ps1 and suggest improvements
   > List all files in my Documents folder
   ```

4. **Exit**:
   - Type `exit`, `quit`, or press `Ctrl+C`

### Command-Line Options

```powershell
# Use a different model
.\Run-Chimera.ps1 -Model "mistral"

# Connect to Ollama on a different host
.\Run-Chimera.ps1 -OllamaUrl "http://192.168.1.100:11434"

# Increase max tool iterations
.\Run-Chimera.ps1 -MaxIterations 20
```

### Built-in Commands

While in the Chimera REPL:

- `exit` or `quit` - Exit Chimera
- `clear` - Clear conversation history
- `stats` - Show current system statistics

---

## Usage Examples

### Example 1: Web Search

```
> Search for the latest security vulnerabilities in PowerShell and summarize the top 3

[ASSISTANT] Searching web...
[TOOL CALL] Search-ChimeraWeb
[RESULT] Success: True

Based on the search results, here are the top 3 recent security vulnerabilities...
```

### Example 2: File Operations

```
> Create a PowerShell script that lists all files modified in the last 7 days in C:\Projects

[ASSISTANT] Creating script...
[TOOL CALL] Write-ChimeraFile
[RESULT] Success: True

I've created the script at C:\Projects\recent-files.ps1. The script will...
```

### Example 3: Code Execution

```
> Show me the top 5 processes by memory usage

[ASSISTANT] Analyzing processes...
[TOOL CALL] Execute-ChimeraScript
[RESULT] Success: True

Here are the top 5 processes by memory usage:
1. Chrome.exe - 2.4 GB
2. Docker.exe - 1.8 GB
...
```

### Example 4: System Analysis

```
> What's the current state of my system?

[ASSISTANT] Gathering system stats...
[TOOL CALL] Get-ChimeraSystemStats
[RESULT] Success: True

Your system status:
- CPU Usage: 23%
- Memory: 12.4 GB / 16 GB (77% used)
- Disk C: 450 GB / 1 TB (45% used)
...
```

### Example 5: Multi-Step Task

```
> Find all PowerShell scripts in C:\Scripts, read each one, and create a summary report

[ASSISTANT] This will require multiple steps. Let me start...
[TOOL CALL] List-ChimeraDirectory (to find .ps1 files)
[TOOL CALL] Read-ChimeraFile (for each script)
[TOOL CALL] Write-ChimeraFile (to create report)

I've analyzed 15 PowerShell scripts and created a summary report at C:\Scripts\summary.txt
```

---

## Troubleshooting

### Issue: "Cannot connect to Ollama"

**Solution**:
1. Ensure Ollama is running: `ollama serve`
2. Check if Ollama is listening: Visit http://localhost:11434 in browser
3. Verify firewall isn't blocking port 11434

### Issue: "Model not found"

**Solution**:
```powershell
# List available models
ollama list

# Pull the model if missing
ollama pull llama3.1
```

### Issue: "Chimera-Tools.psm1 not found"

**Solution**:
1. Verify all files are in the same directory
2. Run from the correct directory: `cd C:\ProjectChimera`
3. Check file paths: `ls *.ps* *.txt`

### Issue: "Script execution is disabled"

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Tool calls fail or timeout

**Solution**:
1. Increase timeout: `.\Run-Chimera.ps1 -MaxIterations 20`
2. Check network connectivity (for web search)
3. Verify file paths are correct and accessible
4. Ensure sufficient permissions for file operations

### Issue: Responses are slow

**Solution**:
1. Use a smaller model: `ollama pull llama3.2`
2. Reduce model size in parameters
3. Close other memory-intensive applications
4. Consider using GPU acceleration if available

### Issue: Web search returns no results

**Solution**:
1. Set BRAVE_API_KEY environment variable (see Configuration)
2. Check internet connectivity
3. Verify API key is valid
4. DuckDuckGo fallback may have rate limits

---

## Advanced Configuration

### Customizing System Prompt

Edit `SYSTEM_PROMPT.txt` to modify:
- Agent behavior
- Tool usage guidelines
- Response style
- Safety restrictions

### Adding Custom Tools

1. Open `Chimera-Tools.psm1`
2. Add your function following the existing pattern
3. Add to `Export-ModuleMember` at the bottom
4. Update `SYSTEM_PROMPT.txt` to document the new tool
5. Add tool handling in `Run-Chimera.ps1` (switch statement in `Invoke-ChimeraTool`)

### Performance Tuning

Edit `Run-Chimera.ps1`:

```powershell
# Adjust temperature (creativity vs. consistency)
options = @{
    temperature = 0.7  # Lower = more focused, Higher = more creative
}

# Increase context window
num_ctx = 4096  # Default, increase for longer conversations
```

### Multi-User Setup

For shared environments, use user-specific API keys:

```powershell
# In user's profile ($PROFILE)
$env:BRAVE_API_KEY = "user-specific-key"
$env:OLLAMA_HOST = "http://shared-ollama-server:11434"
```

### Logging

Add logging to `Run-Chimera.ps1`:

```powershell
# Add after script parameters
$LogFile = "C:\ProjectChimera\chimera.log"
Start-Transcript -Path $LogFile -Append
```

---

## Next Steps

1. **Read** `ARCHITECTURE.md` to understand how Chimera works
2. **Experiment** with different queries and tasks
3. **Customize** the system prompt for your use case
4. **Add** your own tools to extend functionality
5. **Share** feedback and improvements with the community

---

## Support & Resources

- **Ollama Documentation**: https://github.com/ollama/ollama
- **PowerShell Documentation**: https://learn.microsoft.com/powershell/
- **Brave Search API**: https://brave.com/search/api/

---

**Enjoy your local-first AI assistant!** 🚀
