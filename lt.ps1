# LogTool Professional Launcher v28.1.7 (SSOT Orchestrator)
#

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [ValidateSet('Collect', 'Analyze', 'Report')]
    [string]$Command = 'Collect',

    [Parameter(Mandatory = $false)]
    [string]$ArchivePath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [int[]]$IncludeEventId,

    [Parameter(Mandatory = $false)]
    [string]$Keyword,

    [Parameter(Mandatory = $false)]
    [string]$Language,

    [Parameter(Mandatory = $false)]
    [switch]$AutoReport = $true
)

# Portable ScriptRoot resolution ensures reliability across different execution contexts.
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = Get-Location }

# Shared dependency loading is centralized to maintain DR (Don't Repeat Yourself) principles.
$sharedModule = Join-Path -Path $ScriptRoot -ChildPath "core\shared\modules\Shared.psm1"
if (-not (Test-Path $sharedModule)) {
    Write-Error "CRITICAL: Shared module not found at '$sharedModule'. Repository integrity compromised."
    exit 1
}
Import-Module $sharedModule -Force

try {
    # SSOT: Centralized configuration is the source of truth for all domain parameters.
    $config = Get-ToolConfiguration -ScriptRoot $ScriptRoot
    
    if (-not $Language) { $Language = $config.ToolSettings.Language }
    $localizedStrings = Get-LocalizedStrings -Language $Language

    switch ($Command) {
        'Collect' {
            # Backend Delegation: Launcher orchestrates the backend transition for log extraction.
            $backendEngine = Join-Path -Path $ScriptRoot -ChildPath "core\backend\engine.ps1"
            if (-not (Test-Path $backendEngine)) { throw "Backend engine missing." }

            # ArchivePath returned from backend allows for seamless frontend automation.
            $finalArchivePath = & $backendEngine -Mode "Collect" -Language $Language -ScriptRoot $ScriptRoot
            
            # Post-Collection Workflow: Automatic reporting bridges the gap between raw data and insights.
            if ($AutoReport -and $finalArchivePath -and (Test-Path $finalArchivePath)) {
                $frontendEngine = Join-Path -Path $ScriptRoot -ChildPath "core\frontend\engine.ps1"
                if (Test-Path $frontendEngine) {
                    & $frontendEngine -Mode "Analysis" -ArchivePath $finalArchivePath -Language $Language -ScriptRoot $ScriptRoot
                }
            }
        }

        'Analyze' {
            # Frontend Delegation: Launcher hands off control for event processing and dashboard rendering.
            $frontendEngine = Join-Path -Path $ScriptRoot -ChildPath "core\frontend\engine.ps1"
            if (-not (Test-Path $frontendEngine)) { throw "Frontend engine missing." }

            $engineParams = @{ Mode = "Analysis"; Language = $Language; ScriptRoot = $ScriptRoot }
            if ($ArchivePath) { $engineParams.Add('ArchivePath', $ArchivePath) }
            if ($IncludeEventId) { $engineParams.Add('IncludeEventId', $IncludeEventId) }
            if ($Keyword) { $engineParams.Add('Keyword', $Keyword) }

            & $frontendEngine @engineParams
        }

        'Report' {
            # Forensic Mode: Specifically designed for exporting results to a target path without UI noise.
            if (-not $ArchivePath -or -not $OutputPath) {
                Write-Status -Level ERROR -Message "Usage: .\lt.ps1 Report -ArchivePath <path> -OutputPath <path>"
                return
            }

            $frontendEngine = Join-Path -Path $ScriptRoot -ChildPath "core\frontend\engine.ps1"
            if (-not (Test-Path $frontendEngine)) { throw "Frontend engine missing." }

            & $frontendEngine -Mode "Analysis" -ArchivePath $ArchivePath -OutputPath $OutputPath -Language $Language -ScriptRoot $ScriptRoot
        }
    }
}
catch {
    Write-Status -Level ERROR -Message "ORCHESTRATION FAILURE: $($_.Exception.Message)"
    exit 1
}
