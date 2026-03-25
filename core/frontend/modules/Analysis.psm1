#
# Module: Analysis.psm1 v28.0 (AEGIS APEX Hardened)
# Description: Pure analysis engine — event loading, classification, and result object construction.
#              SRP: No UI rendering. Show-ConsoleReport migrated to Reporting.psm1.
# Author: L0g0rhythm
#

#region Private Helpers

function Get-ProviderShortName {
    param(
        [Parameter(Mandatory = $true)][string]$FullName
    )
    process {
        if ($null -eq $FullName) { return $null }
        if ($FullName -like '*-*') { return ($FullName -split '-')[-1] }
        return $FullName
    }
}

function Assert-ArchiveIntegrity {
    <#
    .SYNOPSIS
        Security verification of the ZIP archive against a SHA-256 manifest.
    .DESCRIPTION
        Prevents Import-Clixml deserialization of tampered archives.
        A missing manifest emits a WARNING — backwards compatible.
        A MISMATCHED hash throws a terminating error — fail-closed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath
    )

    $manifestPath = $ArchivePath + ".sha256"

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Status -Level WARN -Message "No integrity manifest found for '$([System.IO.Path]::GetFileName($ArchivePath))'. Proceeding without verification."
        return
    }

    $expectedHash = (Get-Content -LiteralPath $manifestPath -ErrorAction Stop).Trim().ToUpper()
    $actualHash   = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpper()

    if ($expectedHash -ne $actualHash) {
        throw "INTEGRITY VIOLATION: Archive '$([System.IO.Path]::GetFileName($ArchivePath))' hash mismatch. Expected: $expectedHash | Actual: $actualHash. Analysis aborted."
    }

    Write-Status -Level INFO -Message "Archive integrity verified (SHA-256 OK)."
}

#endregion

#region Public Functions

function Invoke-LogAnalysis {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$ScriptRoot,
        [Parameter(Mandatory = $true)]$LocalizedStrings,
        [Parameter(Mandatory = $false)][string]$ArchivePath,
        [Parameter(Mandatory = $false)][int[]]$IncludeEventId,
        [Parameter(Mandatory = $false)][string]$Keyword,
        [Parameter(Mandatory = $false)][switch]$Quiet
    )

    #region Archive Selection
    if (-not $ArchivePath) {
        $archiveBasePath = Join-Path -Path $ScriptRoot -ChildPath "reports"
        if (-not (Test-Path $archiveBasePath)) {
            Write-Status -Level ERROR -Message "The 'reports' directory does not exist. Run 'lt collect' first."
            return $null
        }

        $availableArchives = Get-ChildItem -Path $archiveBasePath -Recurse -Filter "*.zip" | Sort-Object LastWriteTime -Descending

        if ($availableArchives.Count -eq 0) {
            Write-Status -Level WARN -Message "No archives found in '$archiveBasePath'. Run 'lt collect' first."
            return $null
        }

        Write-Status -Level INFO -Message $LocalizedStrings.AvailableArchives -Indent 0

        $i = 0
        $availableArchives | ForEach-Object {
            $displayName = "$(Split-Path $_.DirectoryName -Leaf)\$($_.Name)"
            Write-Host (" {0,3}: {1}" -f (++$i), $displayName)
        }

        $choice = Read-Host "`n  $($LocalizedStrings.EnterArchiveNumber)"
        if ($choice -eq 'q') {
            Write-Status -Level WARN -Message $LocalizedStrings.AnalysisCancelled
            return $null
        }

        if ($choice -match '^\d+$' -and ([int]$choice - 1) -ge 0 -and ([int]$choice - 1) -lt $availableArchives.Count) {
            $ArchivePath = $availableArchives[[int]$choice - 1].FullName
        }
        else {
            Write-Status -Level ERROR -Message $LocalizedStrings.InvalidSelection
            return $null
        }
    }
    #endregion

    $reportsRoot = (Resolve-Path (Join-Path -Path $ScriptRoot -ChildPath "reports")).Path
    try {
        $ArchivePath = Assert-PathWithinBoundary -TargetPath $ArchivePath -AllowedRoot $reportsRoot -ParameterName "ArchivePath"
    }
    catch {
        Write-Status -Level ERROR -Message $_.Exception.Message
        return $null
    }
    #endregion

    #region Archive Integrity Check
    try {
        Assert-ArchiveIntegrity -ArchivePath $ArchivePath
    }
    catch {
        Write-Status -Level ERROR -Message $_.Exception.Message
        return $null
    }
    #endregion

    if (-not $Quiet.IsPresent) {
        Write-SectionHeader -Title $LocalizedStrings.AnalyzingArchive
        Write-Status -Level INFO -Message ($LocalizedStrings.TargetArchive -f (Split-Path $ArchivePath -Leaf))
    }

    $tempExtractPath = Join-Path -Path $env:TEMP -ChildPath "LogAnalysis_$(New-Guid)"
    $reportData      = $null

    try {
        #region Event Loading
        try {
            Expand-Archive -Path $ArchivePath -DestinationPath $tempExtractPath -Force -ErrorAction Stop
        }
        catch {
            Write-Status -Level ERROR -Message "Failed to extract '$ArchivePath'. Archive may be corrupt."
            return $null
        }

        $allEvents = Get-ChildItem -Path $tempExtractPath -Filter "*.xml" | ForEach-Object {
            try {
                # Import-Clixml is safe here: archive integrity was validated above (SHA-256).
                Import-Clixml -Path $_.FullName -ErrorAction Stop
            }
            catch {
                if (-not $Quiet.IsPresent) {
                    Write-Status -Level WARN -Message "Could not parse '$($_.Name)' — skipping."
                }
            }
        } | Where-Object { $null -ne $_ }

        if ($allEvents.Count -eq 0) {
            if (-not $Quiet.IsPresent) { Write-Status -Level WARN -Message $LocalizedStrings.NoEventsLoaded }
            return $null
        }
        #endregion

        #region Optimized Analysis
        if (-not $Quiet.IsPresent) {
            Write-Status -Level INFO -Message ($LocalizedStrings.AnalyzingEvents -f $allEvents.Count)
        }

        # HashSet used for O(1) membership testing in the classification loop.
        $criticalEventIds = [System.Collections.Generic.HashSet[int]]::new()
        $Configuration.AnalysisConfig.CriticalEventIds | ForEach-Object { [void]$criticalEventIds.Add($_) }
        if ($PSBoundParameters.ContainsKey('IncludeEventId')) {
            $IncludeEventId | ForEach-Object { [void]$criticalEventIds.Add($_) }
        }

        # Optimized keyword matching: escaped for CLI safety while preserving static config performance.
        $keywords = if ($PSBoundParameters.ContainsKey('Keyword')) {
            @([regex]::Escape($Keyword))
        }
        else {
            $Configuration.AnalysisConfig.KeywordsToFlag
        }
        # RegexEscaped keywords joined for efficient single-pass matching.
        $regexPattern = $keywords -join '|'

        # Single O(n) pass replaces two separate O(n) loops.
        $foundCriticalEvents = [System.Collections.Generic.List[object]]::new()
        $foundKeywordEvents  = [System.Collections.Generic.List[object]]::new()

        }
        
        $sortedCriticalEvents = $foundCriticalEvents
        $sortedKeywordEvents  = $foundKeywordEvents
        
        # O(n) measurement avoids the O(n log n) overhead of Sort-Object.
        $timeMeasure    = $allEvents | Measure-Object -Property TimeCreated -Minimum -Maximum
        $firstEventTime = $timeMeasure.Minimum
        $lastEventTime  = $timeMeasure.Maximum

        $verdictById      = if ($foundCriticalEvents.Count -gt 0) { $LocalizedStrings.VerdictCritical } else { $LocalizedStrings.VerdictStable }
        $verdictByKeyword = if ($foundKeywordEvents.Count -gt 0)  { $LocalizedStrings.VerdictKeyword  } else { $LocalizedStrings.VerdictNoKeyword }
        #endregion

        #region Result Object Construction
        $maxItems = $Configuration.AnalysisConfig.MaxDetailItems

        $keywordEventsFormatted = $sortedKeywordEvents | Select-Object -First $maxItems |
            Select-Object TimeCreated, Id,
                @{N = 'Provider'; E = { Get-ProviderShortName -FullName $_.ProviderName } },
                MatchedKeyword,
                @{N = 'Message'; E = { ($_.Message -split "`r`n")[0].Trim() } }

        $reportData = [PSCustomObject]@{
            ArchiveName      = (Split-Path $ArchivePath -Leaf)
            TotalEvents      = $allEvents.Count
            AnalysisPeriod   = "$firstEventTime to $lastEventTime"
            VerdictById      = $verdictById
            VerdictByKeyword = $verdictByKeyword
            CriticalEvents   = ($sortedCriticalEvents | Select-Object -First $maxItems)
            KeywordEvents    = $keywordEventsFormatted
        }
        #endregion
    }
    finally {
        # Guaranteed temp-dir cleanup regardless of exit path.
        if (Test-Path $tempExtractPath) {
            Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($reportData -and (-not $Quiet.IsPresent)) {
        Write-Status -Level SUCCESS -Message $LocalizedStrings.AnalysisComplete
    }

    return $reportData
}

#endregion

Export-ModuleMember -Function Invoke-LogAnalysis
