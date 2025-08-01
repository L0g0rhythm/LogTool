#
# LogTool - Core Engine v26.2 (International & Hardened)
#
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Collect', 'Analyze')]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$ArchivePath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [int[]]$IncludeEventId,

    [Parameter(Mandatory = $false)]
    [string]$Keyword
)

#region Initial Validation and Setup
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "CRITICAL: This script requires administrative privileges."
    exit 1
}

try {
    $scriptRoot = $PSScriptRoot
    $modulesPath = Join-Path -Path $scriptRoot -ChildPath "modules"
    $importParams = @{ Force = $true; WarningAction = 'SilentlyContinue' }
    if ($PSBoundParameters.ContainsKey('Verbose')) { $importParams.WarningAction = 'Continue' }

    Import-Module (Join-Path -Path $modulesPath -ChildPath "Shared.psm1") @importParams
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Collection.psm1") @importParams
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Analysis.psm1") @importParams
    Import-Module (Join-Path -Path $modulesPath -ChildPath "Reporting.psm1") @importParams
}
catch {
    Write-Error "FATAL: Failed to load required script modules from '$($modulesPath)'. Error: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Main Execution
try {
    $config = Get-ToolConfiguration -ScriptRoot $PSScriptRoot
    $localizedStrings = Get-LocalizedStrings -Language $config.ToolSettings.Language

    # Prepare parameters to be passed to the modules
    $moduleParams = @{
        Configuration    = $config
        ScriptRoot       = $PSScriptRoot
        LocalizedStrings = $localizedStrings
    }
    if ($PSBoundParameters.ContainsKey('ArchivePath')) { $moduleParams.Add('ArchivePath', $ArchivePath) }
    if ($PSBoundParameters.ContainsKey('IncludeEventId')) { $moduleParams.Add('IncludeEventId', $IncludeEventId) }
    if ($PSBoundParameters.ContainsKey('Keyword')) { $moduleParams.Add('Keyword', $Keyword) }
    if ($PSBoundParameters.ContainsKey('Verbose')) { $moduleParams.Add('Verbose', $true) }


    switch ($Mode) {
        'Collect' {
            Invoke-LogCollection @moduleParams
        }
        'Analyze' {
            $isReportOnly = $PSBoundParameters.ContainsKey('OutputPath')

            if ($isReportOnly) {
                # --- CRITICAL SECURITY VALIDATION: Prevent Path Traversal ---
                $reportsRoot = (Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "reports")).Path
                try {
                    $resolvedOutputDir = (Resolve-Path -LiteralPath (Split-Path -Path $OutputPath -Parent -ErrorAction Stop)).Path
                } catch {
                    throw "Invalid OutputPath provided. The parent directory could not be resolved. Path: '$($OutputPath)'"
                }

                if (-not $resolvedOutputDir.StartsWith($reportsRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                    throw "SECURITY VIOLATION: The specified output path '$($OutputPath)' is outside the allowed 'reports' directory. Report generation aborted."
                }
                # --- End Security Validation ---

                $moduleParams.Add('Quiet', $true)
            }

            $analysisResult = Invoke-LogAnalysis @moduleParams

            # Robustness: Provide feedback if analysis yields no results.
            if ($null -eq $analysisResult) {
                # This assumes 'Write-Status' is loaded from a module and handles localized strings.
                Write-Status -Level INFO -Message $localizedStrings.NoEventsLoaded
                return
            }

            if (-not $isReportOnly) {
                Show-ConsoleReport -Result $analysisResult -Configuration $config -LocalizedStrings $localizedStrings
            }

            if ($isReportOnly) {
                Invoke-HtmlReport -ReportData $analysisResult -LocalizedStrings $localizedStrings | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Status -Level SUCCESS -Message "Interactive report successfully exported to: $OutputPath"
            }
        }
    }
}
catch {
    $errorMessage = "An unhandled error occurred in the core engine: $($_.Exception.Message)"
    Write-Error $errorMessage
    if (Get-Command "Write-AuditLog" -ErrorAction SilentlyContinue) {
        Write-AuditLog -Level 'ERROR' -Message $errorMessage -Configuration $config
    }
    exit 1
}
#endregion
