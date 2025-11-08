#!/bin/bash
#
# AstraShell Basic Validation (Linux/Bash)
# This performs basic checks that don't require PowerShell
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

tests_passed=0
tests_failed=0

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         AstraShell Basic Validation (Linux/Bash)              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}NOTE: This performs basic structural checks only.${NC}"
echo -e "${YELLOW}For full testing, run Test-AstraShell.ps1 on Windows PowerShell 7+${NC}"
echo ""

test_step() {
    local test_name="$1"
    local test_command="$2"

    echo -e "${YELLOW}[TEST] ${test_name}${NC}"
    if eval "$test_command"; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        tests_passed=$((tests_passed + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        tests_failed=$((tests_failed + 1))
        return 1
    fi
}

# Test 1: Required files exist
test_step "Required Module Files Exist" '
    required_files=(
        "AstraShell.psd1"
        "AstraShell.psm1"
        "config.jsonc"
        "Plugins/AstraShell.NLParser.psm1"
        "Plugins/AstraShell.Sentry.psm1"
        "Plugins/AstraShell.RAG.psm1"
        "Plugins/AstraShell.Security.psm1"
        "Install.ps1"
        "README.md"
        "Test-AstraShell.ps1"
    )

    all_exist=true
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "    Missing: $file"
            all_exist=false
        fi
    done

    if [ "$all_exist" = true ]; then
        echo "    All 10 required files present"
        return 0
    else
        return 1
    fi
'

# Test 2: Configuration file is valid JSON (after comment removal)
test_step "Configuration File Valid JSON" '
    if command -v python3 &> /dev/null; then
        # Remove comments and validate JSON
        python3 -c "
import json, re
with open(\"config.jsonc\", \"r\") as f:
    content = f.read()
    # Remove // comments
    content = re.sub(r\"(?m)//.*$\", \"\", content)
    # Remove /* */ comments
    content = re.sub(r\"(?ms)/\*.*?\*/\", \"\", content)
    # Remove trailing commas before } or ]
    content = re.sub(r\",\s*([}\])])\", r\"\1\", content)
    # Remove empty lines
    content = \"\n\".join([line for line in content.split(\"\n\") if line.strip()])
    try:
        config = json.loads(content)
        assert \"Features\" in config
        assert \"RAG\" in config
        assert \"Sentry\" in config
        assert \"Security\" in config
        print(\"    Configuration has all required sections\")
    except Exception as e:
        print(f\"    JSON validation error: {e}\")
        raise
" && return 0 || return 1
    else
        echo "    Python3 not available, skipping JSON validation"
        return 0
    fi
'

# Test 3: PowerShell files have no syntax errors (basic check)
test_step "PowerShell Files Syntax Check (Basic)" '
    syntax_ok=true

    # Check for unmatched braces in main module
    open_braces=$(grep -o "{" AstraShell.psm1 | wc -l)
    close_braces=$(grep -o "}" AstraShell.psm1 | wc -l)

    if [ "$open_braces" -ne "$close_braces" ]; then
        echo "    AstraShell.psm1: Unmatched braces (open: $open_braces, close: $close_braces)"
        syntax_ok=false
    fi

    # Check all plugins
    for plugin in Plugins/*.psm1; do
        open=$(grep -o "{" "$plugin" | wc -l)
        close=$(grep -o "}" "$plugin" | wc -l)
        if [ "$open" -ne "$close" ]; then
            echo "    $plugin: Unmatched braces (open: $open, close: $close)"
            syntax_ok=false
        fi
    done

    if [ "$syntax_ok" = true ]; then
        echo "    All PowerShell files have balanced braces"
        return 0
    else
        return 1
    fi
'

# Test 4: All plugins have Export-ModuleMember
test_step "Plugins Have Export Statements" '
    all_exported=true

    for plugin in Plugins/*.psm1; do
        if ! grep -q "Export-ModuleMember" "$plugin"; then
            echo "    Missing export: $plugin"
            all_exported=false
        fi
    done

    if [ "$all_exported" = true ]; then
        echo "    All 4 plugins have Export-ModuleMember"
        return 0
    else
        return 1
    fi
'

# Test 5: Main module has export statement
test_step "Main Module Has Export Statement" '
    if grep -q "Export-ModuleMember" AstraShell.psm1; then
        echo "    Export-ModuleMember found in main module"
        return 0
    else
        return 1
    fi
'

# Test 6: Function definitions are valid
test_step "Function Definitions Valid" '
    # Check for function definitions
    func_count=$(grep -c "^function " AstraShell.psm1 || true)

    if [ "$func_count" -ge 10 ]; then
        echo "    Found $func_count function definitions"
        return 0
    else
        echo "    Only found $func_count functions (expected 10+)"
        return 1
    fi
'

# Test 7: No obvious PowerShell syntax errors
test_step "No Obvious Syntax Errors" '
    errors=0

    # Check for common syntax issues
    if grep -n "function.*{$" AstraShell.psm1 > /dev/null; then
        true  # Functions properly formatted
    else
        echo "    Warning: Function formatting may have issues"
        ((errors++))
    fi

    # Check for proper param blocks
    if grep -n "param(" AstraShell.psm1 > /dev/null; then
        true  # Param blocks found
    else
        echo "    Warning: No param blocks found"
        ((errors++))
    fi

    if [ "$errors" -eq 0 ]; then
        echo "    No obvious syntax issues detected"
        return 0
    else
        return 1
    fi
'

# Test 8: Documentation files exist
test_step "Documentation Files Present" '
    docs=(
        "README.md"
        "EXAMPLES.md"
        "TESTING_GUIDE.md"
        "CHANGELOG.md"
        "LICENSE"
    )

    all_docs=true
    for doc in "${docs[@]}"; do
        if [ ! -f "$doc" ]; then
            echo "    Missing: $doc"
            all_docs=false
        fi
    done

    if [ "$all_docs" = true ]; then
        echo "    All 5 documentation files present"
        return 0
    else
        return 1
    fi
'

# Test 9: Module manifest is valid PowerShell
test_step "Module Manifest Structure" '
    # Basic check for manifest structure
    if grep -q "RootModule.*=.*AstraShell.psm1" AstraShell.psd1 && \
       grep -q "ModuleVersion" AstraShell.psd1 && \
       grep -q "FunctionsToExport" AstraShell.psd1; then
        echo "    Module manifest has required fields"
        return 0
    else
        echo "    Module manifest may be incomplete"
        return 1
    fi
'

# Test 10: File permissions
test_step "File Permissions Correct" '
    # Check that .ps1 files are readable
    all_readable=true

    for file in *.ps1 Plugins/*.psm1 *.psm1; do
        if [ -f "$file" ] && [ ! -r "$file" ]; then
            echo "    Not readable: $file"
            all_readable=false
        fi
    done

    if [ "$all_readable" = true ]; then
        echo "    All PowerShell files are readable"
        return 0
    else
        return 1
    fi
'

# Summary
echo ""
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                       Validation Summary                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  Total Tests: $((tests_passed + tests_failed))"
echo -e "  ${GREEN}✓ Passed: $tests_passed${NC}"
echo -e "  ${RED}✗ Failed: $tests_failed${NC}"
echo ""

if [ "$tests_failed" -eq 0 ]; then
    echo -e "${GREEN}✅ All basic validation tests passed!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Transfer these files to a Windows machine with PowerShell 7+"
    echo "  2. Run the full test suite:"
    echo -e "     ${YELLOW}cd AstraShell${NC}"
    echo -e "     ${YELLOW}.\\Test-AstraShell.ps1${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠️ Some basic validation tests failed.${NC}"
    echo "  Please review the errors above."
    echo ""
    exit 1
fi
