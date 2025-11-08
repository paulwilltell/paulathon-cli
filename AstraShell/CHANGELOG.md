# AstraShell Changelog

## [1.0.1] - 2025-01-08

### Fixed
- **Critical**: Fixed wildcard path check in `Get-AstraSuggestion` (line 470)
  - Changed from `Test-Path (Join-Path $currentPath "*.sln")` to `Get-ChildItem -Path $currentPath -Filter "*.sln"`
  - The Test-Path command doesn't expand wildcards, causing .NET solution detection to fail

- **Medium**: Fixed Windows-specific path separator in RAG plugin
  - Changed from `"Data\index.json"` to platform-agnostic `Join-Path` approach
  - Improves cross-platform compatibility

### Added
- **Enhancement**: Added `Assert-AstraShellInitialized` helper function
  - Ensures AstraShell is properly initialized before operations
  - Prevents null reference errors in edge cases

- **Enhancement**: Improved `Get-AstraConfig` with section validation
  - Now warns if requested section doesn't exist
  - Returns null instead of throwing error for better error handling

- **Enhancement**: Improved `Set-AstraConfig` with key validation
  - Checks if key exists before updating
  - Can add new keys to existing sections
  - More informative success messages

- **Testing**: Added comprehensive test suite (`Test-AstraShell.ps1`)
  - 17 automated tests covering all major functionality
  - Module loading, plugin discovery, configuration, and more
  - Exit code support for CI/CD integration

- **Documentation**: Added `TESTING_GUIDE.md`
  - Comprehensive manual testing procedures
  - Edge case testing scenarios
  - Performance benchmarks
  - Troubleshooting guides

- **Documentation**: Added `BUGFIX_REPORT.md`
  - Detailed analysis of all identified bugs
  - Severity classifications
  - Recommendations for future improvements

- **Documentation**: Added `CHANGELOG.md` (this file)

### Technical Debt
- All plugins now use consistent error handling patterns
- Initialization checks added to prevent edge case failures
- Better null-safety throughout the codebase

### Validation
- ✅ All functions have proper Export-ModuleMember statements
- ✅ All plugins load correctly
- ✅ Configuration file is valid JSONC
- ✅ No syntax errors detected in static analysis
- ✅ All required files present

## [1.0.0] - 2025-01-08

### Initial Release
- Natural Language Parser (NLParser) plugin
- System Sentry monitoring plugin
- RAG (local file indexing) plugin
- Security analysis plugin
- Core module with 10 exported functions
- JSONC configuration system
- Modular plugin architecture
- Comprehensive documentation

---

## Legend
- **Critical**: Bugs that prevent core functionality
- **Medium**: Issues that affect specific features
- **Enhancement**: Improvements to existing features
- **Testing**: Test-related additions
- **Documentation**: Documentation updates
