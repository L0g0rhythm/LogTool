# LogTool Frontend Engine v28.1.7 (SRP Max)
#

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [Parameter(Mandatory = $true)][string]$ScriptRoot,
    [Parameter(Mandatory = $false)][string]$Language = "en-US",
    [Parameter(Mandatory = $false)][string]$ArchivePath,
    [Parameter(Mandatory = $false)][string]$OutputPath,
    [Parameter(Mandatory = $false)][int[]]$IncludeEventId,
    [Parameter(Mandatory = $false)][string]$Keyword
)

# Domain Boundary: The frontend engine is isolated from collection logic.
$domainRoot = $PSScriptRoot
$sharedRoot = Join-Path -Path $domainRoot -ChildPath "..\shared"

# Security & SRP: Loading only the modules required for analysis and reporting.
try {
    $importParams = @{ Force = $true; WarningAction = 'SilentlyContinue' }
    Import-Module (Join-Path -Path $sharedRoot -ChildPath "modules\Shared.psm1")     @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Analysis.psm1")   @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Reporting.psm1")  @importParams
}
catch {
    Write-Error "FATAL (Frontend): Failed to load modules. Error: $($_.Exception.Message)"
    exit 1
}

try {
    # SSOT Configuration is the root of trust for all subsequent operations.
    $config = Get-ToolConfiguration -ScriptRoot $ScriptRoot
    $localizedStrings = Get-LocalizedString -Language $Language
    
    $moduleParams = @{
        Configuration    = $config
        ScriptRoot       = $ScriptRoot
        LocalizedStrings = $localizedStrings
    }
    if ($PSBoundParameters.ContainsKey('ArchivePath'))    { $moduleParams.Add('ArchivePath',    $ArchivePath) }
    if ($PSBoundParameters.ContainsKey('IncludeEventId')) { $moduleParams.Add('IncludeEventId', $IncludeEventId) }
    if ($PSBoundParameters.ContainsKey('Keyword'))        { $moduleParams.Add('Keyword',        $Keyword) }
    
    $isExportMode = $PSBoundParameters.ContainsKey('OutputPath')
    if ($isExportMode) {
        # Path Confinement: Ensuring reports remain within the 'reports' hierarchy (M24 compliance).
        $reportsRoot = (Resolve-Path (Join-Path -Path $ScriptRoot -ChildPath "reports")).Path
        $targetDir   = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        
        $resolvedTargetDir = (Resolve-Path -LiteralPath $targetDir).Path
        if (-not $resolvedTargetDir.StartsWith($reportsRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            throw "SECURITY VIOLATION: Export path is outside the reports boundary."
        }
        $moduleParams.Add('Quiet', $true)
    }

    $analysisResult = Invoke-LogAnalysis @moduleParams
    if ($null -eq $analysisResult) { return }

    if (-not $isExportMode) {
        # High-level console dashboard for rapid triage.
        Show-ConsoleReport -Result $analysisResult -Configuration $config -LocalizedStrings $localizedStrings
        
        # Automatic HTML report generation is triggered unless an explicit OutputPath was provided via CLI.
        $htmlOutputPath = $ArchivePath -replace '\.zip$', '.html'
        Invoke-HtmlReport -ReportData $analysisResult -LocalizedStrings $localizedStrings -OutputPath $htmlOutputPath
    }
    else {
        # AUD-PERF-02: Direct streaming to provided OutputPath for large-scale export operations.
        Invoke-HtmlReport -ReportData $analysisResult -LocalizedStrings $localizedStrings -OutputPath $OutputPath
    }
}
catch {
    Write-Status -Level ERROR -Message "FRONTEND CRITICAL: $($_.Exception.Message)"
    exit 1
}
