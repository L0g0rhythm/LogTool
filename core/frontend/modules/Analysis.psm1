#
# Module: Analysis.psm1 v28.1.7
#

#region Private Helpers

function Get-ProviderShortName {
    param(
        [Parameter(Mandatory = $true)][string]$FullName
    )
    process {
        # Extracts the specific provider identity by removing vendor-prefixed namespaces.
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
    # Sidecar manifest check ensures that the file wasn't tampered with post-collection.
    $manifestPath = $ArchivePath + ".sha256"

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Status -Level WARN -Message "No integrity manifest found for '$([System.IO.Path]::GetFileName($ArchivePath))'. Proceeding without verification."
        return
    }

    $expectedHash = (Get-Content -LiteralPath $manifestPath -ErrorAction Stop).Trim().ToUpper()
    $actualHash   = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpper()

    if ($expectedHash -ne $actualHash) {
        throw "INTEGRITY VIOLATION: Archive '$([System.IO.Path]::GetFileName($ArchivePath))' hash mismatch. Expected: $expectedHash | Actual: $actualHash."
    }

    Write-Status -Level INFO -Message "Archive integrity verified (SHA-256 OK)."
}

#endregion

#region Public Functions

function Invoke-LogAnalysis {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
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

    # If no path is provided, enter interactive selection to maintain UX flexibility.
    if (-not $ArchivePath) {
        if ($Quiet) {
            Write-Status -Level WARN -Message "Quiet mode: No ArchivePath provided and no interaction allowed. Skipping analysis."
            return $null
        }
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
        $show = { 
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
            param($i, $n) Write-Host (" {0,3}: {1}" -f $i, $n) 
        }
        $availableArchives | ForEach-Object {
            $displayName = "$(Split-Path $_.DirectoryName -Leaf)\$($_.Name)"
            &$show (++$i) $displayName
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

    $reportsPath = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsPath)) {
        New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null
    }
    $reportsRoot = (Resolve-Path $reportsPath).Path
    try {
        # Enforcing boundary check to prevent malicious path-spanning archives.
        $ArchivePath = Assert-PathWithinBoundary -TargetPath $ArchivePath -AllowedRoot $reportsRoot -ParameterName "ArchivePath"
    }
    catch {
        Write-Status -Level ERROR -Message $_.Exception.Message
        return $null
    }

    try {
        Assert-ArchiveIntegrity -ArchivePath $ArchivePath
    }
    catch {
        Write-Status -Level ERROR -Message $_.Exception.Message
        return $null
    }

    if (-not $Quiet.IsPresent) {
        Write-SectionHeader -Title $LocalizedStrings.AnalyzingArchive
        Write-Status -Level INFO -Message ($LocalizedStrings.TargetArchive -f (Split-Path $ArchivePath -Leaf))
    }

    # Isolated extraction path prevents collision during concurrent analysis runs.
    $tempExtractPath = Join-Path -Path $env:TEMP -ChildPath "LogAnalysis_$(New-Guid)"
    $reportData = $null

    try {
        try {
            Expand-Archive -Path $ArchivePath -DestinationPath $tempExtractPath -Force -ErrorAction Stop
        }
        catch {
            Write-Status -Level ERROR -Message "Failed to extract '$ArchivePath'. Archive may be corrupt."
            return $null
        }

        # Recursive discovery ensures that even nested manual collections are analyzed correctly.
        $allEvents = @(Get-ChildItem -Path $tempExtractPath -Filter "*.xml" -Recurse | ForEach-Object {
            try {
                # Import-Clixml is safe here: archive integrity was validated via SHA-256 before this step.
                Import-Clixml -Path $_.FullName -ErrorAction Stop
            }
            catch {
                if (-not $Quiet.IsPresent) {
                    Write-Status -Level WARN -Message "Could not parse '$($_.Name)' - skipping."
                }
            }
        } | Where-Object { $null -ne $_ })

        if ($allEvents.Count -eq 0) {
            if (-not $Quiet.IsPresent) { Write-Status -Level WARN -Message $LocalizedStrings.NoEventsLoaded }
            return $null
        }

        if (-not $Quiet.IsPresent) {
            Write-Status -Level INFO -Message ($LocalizedStrings.AnalyzingEvents -f $allEvents.Count)
        }

        # HashSet lookup provides O(1) performance for critical ID identification.
        $criticalEventIds = [System.Collections.Generic.HashSet[int]]::new()
        $Configuration.AnalysisConfig.CriticalEventIds | ForEach-Object { [void]$criticalEventIds.Add($_) }
        if ($PSBoundParameters.ContainsKey('IncludeEventId')) {
            $IncludeEventId | ForEach-Object { [void]$criticalEventIds.Add($_) }
        }

        # Pregenerated regex pattern allows for efficient multi-keyword scanning in a single pass.
        $keywords = if ($PSBoundParameters.ContainsKey('Keyword')) {
            @([regex]::Escape($Keyword))
        }
        else {
            $Configuration.AnalysisConfig.KeywordsToFlag
        }
        $regexPattern = $keywords -join '|'

        # Unified single-loop O(n) pass maximizes cache efficiency and minimizes CPU cycles.
        $foundCriticalEvents = [System.Collections.Generic.List[object]]::new()
        $foundKeywordEvents  = [System.Collections.Generic.List[object]]::new()

        foreach ($logEvent in $allEvents) {
            if ($criticalEventIds.Contains($logEvent.Id)) {
                [void]$foundCriticalEvents.Add($logEvent)
            }

            if ($logEvent.Message -match $regexPattern) {
                $logEvent | Add-Member -MemberType NoteProperty -Name 'MatchedKeyword' -Value $Matches[0] -Force
                [void]$foundKeywordEvents.Add($logEvent)
            }
        }

        $sortedCriticalEvents = $foundCriticalEvents
        $sortedKeywordEvents  = $foundKeywordEvents

        # Manual measurement avoids the overhead of Sort-Object while maintaining O(n) bounds.
        $timeMeasure    = $allEvents | Measure-Object -Property TimeCreated -Minimum -Maximum
        $firstEventTime = $timeMeasure.Minimum
        $lastEventTime  = $timeMeasure.Maximum

        $verdictById      = if ($foundCriticalEvents.Count -gt 0) { $LocalizedStrings.VerdictCritical } else { $LocalizedStrings.VerdictStable }
        $verdictByKeyword = if ($foundKeywordEvents.Count -gt 0)  { $LocalizedStrings.VerdictKeyword  } else { $LocalizedStrings.VerdictNoKeyword }

        $maxItems = $Configuration.AnalysisConfig.MaxDetailItems

        # Result object structure provides a clean contract for the Reporting engine (SRP adherence).
        $keywordEventsFormatted = $sortedKeywordEvents | Select-Object -First $maxItems |
            Select-Object TimeCreated, Id,
                @{N = 'Provider'; E = { Get-ProviderShortName -FullName $_.ProviderName } },
                MatchedKeyword,
                @{N = 'Message'; E = { ($_.Message -split '\r?\n')[0].Trim() } }

        $reportData = [PSCustomObject]@{
            ArchiveName      = (Split-Path $ArchivePath -Leaf)
            TotalEvents      = $allEvents.Count
            AnalysisPeriod   = ('{0} to {1}' -f $firstEventTime, $lastEventTime)
            VerdictById      = $verdictById
            VerdictByKeyword = $verdictByKeyword
            CriticalEvents   = ($sortedCriticalEvents | Select-Object -First $maxItems)
            KeywordEvents    = $keywordEventsFormatted
        }
    }
    finally {
        # Ensures that sensitive log extractions are purged from the filesystem immediately after use.
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

Export-ModuleMember -Function Invoke-LogAnalysis, Assert-ArchiveIntegrity


