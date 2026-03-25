# LogTool - Frontend Domain Engine v28.0 (SRP Max)
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [Parameter(Mandatory = $false)][string]$ArchivePath,
    [Parameter(Mandatory = $false)][string]$OutputPath,
    [Parameter(Mandatory = $false)][int[]]$IncludeEventId,
    [Parameter(Mandatory = $false)][string]$Keyword
)

#region Domain Bootstrap: Module Loading
try {
    $domainRoot  = $PSScriptRoot
    $sharedRoot  = Join-Path -Path $domainRoot -ChildPath "..\shared"
    $importParams = @{ Force = $true; WarningAction = 'SilentlyContinue' }

    Import-Module (Join-Path -Path $sharedRoot -ChildPath "modules\Shared.psm1")     @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Analysis.psm1")   @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Reporting.psm1")  @importParams
}
catch {
    Write-Error "FATAL (Frontend Domain): Failed to load modules. Error: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Domain Execution
try {
    $projectRoot      = (Resolve-Path (Join-Path -Path $domainRoot -ChildPath "..\..")).Path
    $coreRoot         = (Resolve-Path (Join-Path -Path $domainRoot -ChildPath "..")).Path
    $config           = Get-ToolConfiguration -ScriptRoot $coreRoot
    $localizedStrings = Get-LocalizedStrings -Language $config.ToolSettings.Language

    $moduleParams = @{
        Configuration    = $config
        ScriptRoot       = $projectRoot
        LocalizedStrings = $localizedStrings
    }
    if ($PSBoundParameters.ContainsKey('ArchivePath'))    { $moduleParams.Add('ArchivePath',    $ArchivePath) }
    if ($PSBoundParameters.ContainsKey('IncludeEventId')) { $moduleParams.Add('IncludeEventId', $IncludeEventId) }
    if ($PSBoundParameters.ContainsKey('Keyword'))        { $moduleParams.Add('Keyword',        $Keyword) }
    if ($PSBoundParameters.ContainsKey('Verbose'))        { $moduleParams.Add('Verbose',        $true) }

    $isReportOnly = $PSBoundParameters.ContainsKey('OutputPath')
    if ($isReportOnly) {
        #region OutputPath Path Confinement (M24 Hardened)
        $reportsRoot = (Resolve-Path (Join-Path -Path $projectRoot -ChildPath "reports")).Path
        try {
            $resolvedOutputDir = (Resolve-Path -LiteralPath (Split-Path -Path $OutputPath -Parent -ErrorAction Stop)).Path
        }
        catch {
            throw "Invalid OutputPath: parent directory could not be resolved. Path: '$OutputPath'"
        }

        if (-not $resolvedOutputDir.StartsWith($reportsRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            throw "SECURITY VIOLATION: OutputPath '$OutputPath' is outside the root 'reports' directory. Aborted."
        }
        #endregion

        $moduleParams.Add('Quiet', $true)
    }

    $analysisResult = Invoke-LogAnalysis @moduleParams
    if ($null -eq $analysisResult) {
        Write-Status -Level INFO -Message $localizedStrings.NoEventsLoaded
        return
    }

    if (-not $isReportOnly) {
        Show-ConsoleReport -Result $analysisResult -Configuration $config -LocalizedStrings $localizedStrings
    }
    else {
        # AUD-PERF-02: Direct streaming to OutputPath for maximum memory efficiency.
        Invoke-HtmlReport -ReportData $analysisResult -LocalizedStrings $localizedStrings -OutputPath $OutputPath
        Write-Status -Level SUCCESS -Message "Report exported to: $OutputPath"
    }
}
catch {
    $errorMessage = "Unhandled error in frontend domain: $($_.Exception.Message)"
    Write-Error $errorMessage
    if (Get-Command "Write-AuditLog" -ErrorAction SilentlyContinue) {
        Write-AuditLog -Level 'ERROR' -Message "Frontend Domain Error: $($_.Exception.Message)" -Configuration $config
    }
    exit 1
}
#endregion
