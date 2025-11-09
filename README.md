# Project Chimera

**A Hyper-Advanced, Local-First AI Assistant with Tool-Using Capabilities**

> *"Not just talk — Action. Your autonomous AI agent running entirely on your laptop."*

---

## What is Project Chimera?

Project Chimera is a **tools-first, autonomous AI agent** that runs completely locally on your computer. Unlike traditional chatbots that can only *talk about* doing things, Chimera can actually *do them*:

- **Search the web** for current information
- **Read and write files** on your filesystem
- **Execute PowerShell code** safely
- **Navigate directories** and understand your project structure
- **Monitor your system** performance and processes

All powered by state-of-the-art open-source LLMs running on your own hardware via Ollama — no cloud, no API costs, complete privacy.

---

## Key Features

### 🚀 **Autonomous Agent Architecture**
Chimera doesn't just respond to prompts — it breaks down complex tasks, uses the right tools in sequence, and delivers results.

### 🔒 **100% Local & Private**
Everything runs on your machine. Your data never leaves your laptop. No telemetry, no cloud dependencies.

### 🛠️ **Tool-Using Capabilities**
Six production-ready tools out of the box:
- `Search-ChimeraWeb` - Web search with Brave API or DuckDuckGo
- `Read-ChimeraFile` - Safe file reading with encoding support
- `Write-ChimeraFile` - File creation and modification
- `Execute-ChimeraScript` - Sandboxed PowerShell execution
- `List-ChimeraDirectory` - Recursive directory trees
- `Get-ChimeraSystemStats` - Real-time system monitoring

### 🧩 **Highly Extensible**
Clean, modular architecture makes adding custom tools trivial. Built on PowerShell 7 for cross-platform compatibility.

### 🧠 **Model Agnostic**
Works with any Ollama-supported model: Llama 3.1, Mistral, CodeLlama, and more. Swap models instantly.

---

## Quick Start

### Prerequisites
- **PowerShell 7+** ([Install](https://github.com/PowerShell/PowerShell/releases))
- **Ollama** ([Install](https://ollama.ai))

### Installation (60 seconds)

```powershell
# 1. Install Ollama and pull a model
ollama pull llama3.1

# 2. Start Ollama
ollama serve  # In a separate terminal

# 3. Clone/download Project Chimera
cd C:\ProjectChimera  # Or your preferred directory

# 4. Run Chimera
pwsh .\Run-Chimera.ps1
```

### First Commands

```
> What are my current system stats?

> Search the web for PowerShell 7 best practices and summarize the top 3

> Read the file C:\Scripts\deploy.ps1 and suggest improvements

> Create a Python script that lists all .txt files in my Documents folder
```

Type `exit` to quit.

---

## Example Use Cases

### 1️⃣ **Research & Summarization**
```
> Search for the latest CVEs in Docker and create a summary report in CVE-report.txt
```

Chimera will:
1. Search the web for recent Docker CVEs
2. Analyze the results
3. Generate a formatted report
4. Save it to a file

### 2️⃣ **Code Analysis**
```
> Analyze all PowerShell scripts in C:\Scripts and identify security issues
```

Chimera will:
1. List all .ps1 files
2. Read each script
3. Perform security analysis
4. Provide a detailed report

### 3️⃣ **System Automation**
```
> Monitor my system. If CPU usage is over 80%, list the top 5 processes and suggest optimizations
```

Chimera will:
1. Get current system stats
2. Check CPU usage
3. Execute process analysis
4. Provide actionable recommendations

### 4️⃣ **Multi-Step Workflows**
```
> Find all error logs from today, analyze them, and create a summary with recommended fixes
```

Chimera orchestrates multiple tools to complete complex tasks autonomously.

---

## Architecture

```
┌─────────────────────────────────────────┐
│         User (PowerShell REPL)          │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│     Agent Loop (Run-Chimera.ps1)        │
│  • Conversation management              │
│  • Tool call parsing & routing          │
│  • Multi-iteration orchestration        │
└─────┬────────────────────┬──────────────┘
      │                    │
      ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│  Chimera Tools   │  │  Ollama (LLM)    │
│  • Web Search    │  │  • Llama 3.1     │
│  • File I/O      │  │  • Mistral       │
│  • Code Exec     │  │  • CodeLlama     │
│  • System Info   │  │  • Custom Models │
└──────────────────┘  └──────────────────┘
```

**Learn more**: See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical documentation.

---

## Documentation

- **[SETUP.md](SETUP.md)** - Complete installation and configuration guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical deep-dive and system design
- **[Run-Chimera.ps1](Run-Chimera.ps1)** - Main agent script (well-commented)
- **[Chimera-Tools.psm1](Chimera-Tools.psm1)** - Tool library with examples
- **[SYSTEM_PROMPT.txt](SYSTEM_PROMPT.txt)** - Agent instructions and tool documentation

---

## Extending Chimera

Adding a new tool is straightforward:

### 1. Create the Tool Function

Add to `Chimera-Tools.psm1`:

```powershell
function Get-ChimeraWeather {
    [CmdletBinding()]
    param([string]$Location)

    try {
        # Your implementation
        return [PSCustomObject]@{
            Success = $true
            Location = $Location
            Temperature = 72
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function @(..., 'Get-ChimeraWeather')
```

### 2. Add Tool Route

In `Run-Chimera.ps1`, add to the switch statement:

```powershell
"Get-ChimeraWeather" { Get-ChimeraWeather @Parameters }
```

### 3. Document the Tool

Update `SYSTEM_PROMPT.txt` with tool description and example.

That's it! The agent can now use your new tool.

---

## Why Chimera?

### vs. Cloud AI Assistants (ChatGPT, Claude, etc.)
- ✅ **100% Private** - Your data stays on your machine
- ✅ **No API Costs** - Unlimited usage, no subscription
- ✅ **Offline Capable** - Works without internet (except web search)
- ✅ **Full System Access** - Can interact with your local environment
- ⚠️ Requires local compute resources

### vs. Simple Ollama Wrappers
- ✅ **Autonomous** - Not just chat, actual task execution
- ✅ **Tool-Using** - Real actions, not just information
- ✅ **Multi-Step Reasoning** - Handles complex workflows
- ✅ **Production-Ready** - Error handling, timeouts, safety

### vs. LangChain / AutoGPT
- ✅ **Simpler** - ~500 lines of PowerShell, easy to understand
- ✅ **No Dependencies** - Just PowerShell 7 and Ollama
- ✅ **Windows-Native** - Built for PowerShell environments
- ✅ **Transparent** - You can read and modify every line

---

## System Requirements

### Minimum
- **OS**: Windows 10/11 (Linux/macOS with minor adjustments)
- **RAM**: 8GB (16GB recommended)
- **Storage**: 10GB free (for models)
- **CPU**: Modern multi-core processor

### Recommended
- **RAM**: 16GB+
- **GPU**: NVIDIA GPU with CUDA (optional, for faster inference)
- **Storage**: SSD for faster model loading

---

## Performance

Typical response times with Llama 3.1 (8B):
- **Simple queries**: 2-5 seconds
- **Single tool call**: 3-8 seconds
- **Complex multi-step tasks**: 10-30 seconds

Use smaller models (e.g., `llama3.2` 3B) for faster responses, or larger models (e.g., 70B) for better reasoning (with appropriate hardware).

---

## Security & Safety

Project Chimera includes several safety mechanisms:

1. **Sandboxed Execution**: PowerShell code runs in isolated jobs with timeout
2. **Path Validation**: File operations validate paths and permissions
3. **API-Based Web Search**: No arbitrary URL fetching
4. **Structured Results**: All tools return success/failure status

**For production use**: Consider adding:
- User confirmations for destructive operations
- Path whitelisting/blacklisting
- Audit logging
- Rate limiting

See [ARCHITECTURE.md](ARCHITECTURE.md#security-considerations) for details.

---

## Troubleshooting

### "Cannot connect to Ollama"
Ensure Ollama is running:
```powershell
ollama serve
```

### "Model not found"
Pull the model first:
```powershell
ollama pull llama3.1
```

### "Script execution is disabled"
Set execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

For more issues, see [SETUP.md](SETUP.md#troubleshooting).

---

## Roadmap

### v1.0 (Current)
- ✅ Core agent loop with tool execution
- ✅ 6 essential tools (web, file, code, system)
- ✅ Conversation history management
- ✅ Comprehensive documentation

### v1.1 (Planned)
- [ ] Parallel tool execution
- [ ] Streaming responses for better UX
- [ ] Additional tools (git, docker, database)
- [ ] Plugin system for dynamic tool loading

### v2.0 (Vision)
- [ ] Multi-agent orchestration
- [ ] Vector database for long-term memory
- [ ] Self-improving through feedback
- [ ] Multi-modal support (images, audio)

---

## Contributing

Chimera is designed to be hackable! Some ideas:

- **Add new tools** for your specific use cases
- **Improve prompts** for better agent behavior
- **Add safety features** like confirmation dialogs
- **Create GUI frontends** (WPF, Electron, web)
- **Port to other languages** (Python, Go, Rust)
- **Benchmark different models** and share results

---

## License

This project is provided as-is for educational and personal use. Feel free to modify, extend, and share.

---

## Acknowledgments

Built with:
- **[Ollama](https://ollama.ai)** - Local LLM runtime
- **[PowerShell 7](https://github.com/PowerShell/PowerShell)** - Cross-platform automation
- **[Brave Search API](https://brave.com/search/api/)** - Web search (optional)
- Inspired by agentic frameworks like AutoGPT, BabyAGI, and LangChain

---

## Get Started

```powershell
# Let's go!
pwsh .\Run-Chimera.ps1
```

**Ready to build your autonomous AI assistant?** Read [SETUP.md](SETUP.md) for detailed instructions.

---

*Project Chimera - Because AI should do, not just talk.* 🚀