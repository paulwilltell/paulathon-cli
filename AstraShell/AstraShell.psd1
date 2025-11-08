# Module manifest for AstraShell
@{
    RootModule = 'AstraShell.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a8f3d4c2-1e5b-4a9c-8d7f-2b3e4c5a6b7c'
    Author = 'AstraShell Development Team'
    CompanyName = 'Unknown'
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'AstraShell - Advanced PowerShell CLI with Natural Language Processing, System Monitoring, and Local RAG capabilities'
    PowerShellVersion = '7.0'

    # Functions to export
    FunctionsToExport = @(
        'Invoke-Astra',
        'Start-AstraShell',
        'Stop-AstraShell',
        'Get-AstraConfig',
        'Set-AstraConfig',
        'Get-AstraSuggestion',
        'Enable-AstraPlugin',
        'Disable-AstraPlugin',
        'Get-AstraPlugin',
        'Invoke-AstraQuery'
    )

    # Cmdlets to export
    CmdletsToExport = @()

    # Variables to export
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport = @('astra')

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('AI', 'CLI', 'NaturalLanguage', 'Automation', 'RAG')
            ProjectUri = 'https://github.com/yourusername/astrashell'
            RequireLicenseAcceptance = $false
        }
    }
}
