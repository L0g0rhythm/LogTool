#region Private Helper Functions
function Get-ProviderShortName {
    # Internal helper to safely extract the short name from a provider.
    # Handles cases where the name might not contain a delimiter.
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullName
    )
    process {
        if ($null -eq $FullName) { return $null }
        if ($FullName -like '*-*') {
            return ($FullName -split '-')[-1]
        }
        return $FullName
    }
}
#endregion

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

    #region File Selection
    if (-not $ArchivePath) {
        $archiveBasePath = Join-Path -Path $ScriptRoot -ChildPath "reports"
        if (-not (Test-Path $archiveBasePath)) {
            Write-Status -Level ERROR -Message "The 'reports' directory does not exist. No archives to analyze."
            return $null
        }

        $availableArchives = Get-ChildItem -Path $archiveBasePath -Recurse -Filter "*.zip" | Sort-Object LastWriteTime -Descending

        if ($availableArchives.Count -eq 0) {
            Write-Status -Level WARN -Message "No archives found in the '$archiveBasePath' directory."
            return $null
        }

        Write-Status -Level INFO -Message $LocalizedStrings.AvailableArchives -Indent 0

        $i = 0
        $availableArchives | ForEach-Object {
            $file = $_
            $displayName = "$(Split-Path $file.DirectoryName -Leaf)\$($file.Name)"
            Write-Host (" {0,3}: {1}" -f (++$i), $displayName)
        }

        $choice = Read-Host "`n  $($LocalizedStrings.EnterArchiveNumber)"
        if ($choice -eq 'q') {
            Write-Status -Level WARN -Message $LocalizedStrings.AnalysisCancelled
            return $null
        }

        if ($choice -match '^\d+$' -and ([int]$choice - 1) -ge 0 -and ([int]$choice - 1) -lt $availableArchives.Count) {
            $index = [int]$choice - 1
            $ArchivePath = $availableArchives[$index].FullName
        } else {
            Write-Status -Level ERROR -Message $LocalizedStrings.InvalidSelection
            return $null
        }
    }
    #endregion

    if (-not $Quiet.IsPresent) {
        Write-SectionHeader -Title $LocalizedStrings.AnalyzingArchive
        Write-Status -Level INFO -Message ($LocalizedStrings.TargetArchive -f (Split-Path $ArchivePath -Leaf))
    }

    $tempExtractPath = Join-Path -Path $env:TEMP -ChildPath "LogAnalysis_$(New-Guid)"
    $reportData = $null

    try {
        #region Event Loading from Archive
        try {
            Expand-Archive -Path $ArchivePath -DestinationPath $tempExtractPath -Force -ErrorAction Stop
        } catch {
            Write-Status -Level ERROR -Message "Failed to extract archive '$ArchivePath'. It may be corrupt or you may lack permissions."
            # Exits the try block, finally will still run.
            return $null
        }

        # SECURITY NOTE: Import-Clixml deserializes objects. Only process archives from trusted sources.
        $allEvents = Get-ChildItem -Path $tempExtractPath -Filter "*.xml" | ForEach-Object {
            try {
                # Outputting to the pipeline is vastly more efficient than `+=` on an array.
                Import-Clixml -Path $_.FullName -ErrorAction Stop
            } catch {
                 if (-not $Quiet.IsPresent) { Write-Status -Level WARN -Message "Could not parse log file '$($_.Name)'. It might be corrupted or empty. Skipping." }
            }
        } | Where-Object { $null -ne $_ } # Filter out any nulls from failed imports

        if ($allEvents.Count -eq 0) {
            if (-not $Quiet.IsPresent) { Write-Status -Level WARN -Message $LocalizedStrings.NoEventsLoaded }
            return $null # Exits the try block
        }
        #endregion

        #region Optimized Data Analysis
        if (-not $Quiet.IsPresent) { Write-Status -Level INFO -Message ($LocalizedStrings.AnalyzingEvents -f $allEvents.Count) }

        # Combine configured and command-line Event IDs
        $criticalEventIds = [System.Collections.Generic.HashSet[int]]::new()
        $Configuration.AnalysisConfig.CriticalEventIds | ForEach-Object { [void]$criticalEventIds.Add($_) }
        if ($PSBoundParameters.ContainsKey('IncludeEventId')) {
            $IncludeEventId | ForEach-Object { [void]$criticalEventIds.Add($_) }
        }

        $keywords = if ($PSBoundParameters.ContainsKey('Keyword')) { @($Keyword) } else { $Configuration.AnalysisConfig.KeywordsToFlag }
        $regexKeywords = $keywords -join '|'
        # Efficiently filter events by capturing loop output
        $foundCriticalEvents = foreach ($logEvent in $allEvents) {
            if ($criticalEventIds.Contains($logEvent.Id)) {
                $logEvent
            }
        }

        $foundKeywordEvents = foreach ($logEvent in $allEvents) {
            if ($logEvent.Message -match $regexKeywords) {
                # Create a new object with the matched keyword to avoid modifying the original
                $logEvent | Select-Object *, @{N='MatchedKeyword';E={$Matches[0]}}
            }
        }

        $sortedCriticalEvents = $foundCriticalEvents | Sort-Object TimeCreated -Descending
        $sortedKeywordEvents = $foundKeywordEvents | Sort-Object TimeCreated -Descending

        # Optimized time calculation: Sort once, then pick first and last.
        $sortedByTime = $allEvents | Sort-Object TimeCreated
        $firstEventTime = $sortedByTime[0].TimeCreated
        $lastEventTime = $sortedByTime[-1].TimeCreated

        $verdictById = if ($foundCriticalEvents.Count -gt 0) { $LocalizedStrings.VerdictCritical } else { $LocalizedStrings.VerdictStable }
        $verdictByKeyword = if ($foundKeywordEvents.Count -gt 0) { $LocalizedStrings.VerdictKeyword } else { $LocalizedStrings.VerdictNoKeyword }
        #endregion

        #region Construct Result Object
        $maxItems = $Configuration.AnalysisConfig.MaxDetailItems

        $keywordEventsFormatted = $sortedKeywordEvents | Select-Object -First $maxItems | Select-Object TimeCreated, Id, @{N='Provider';E={Get-ProviderShortName -FullName $_.ProviderName}}, MatchedKeyword, @{N='Message';E={($_.Message -split "`r`n")[0].Trim()}}

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
        # This block ensures the temporary directory is ALWAYS removed, even if errors occur.
        if (Test-Path $tempExtractPath) {
            Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($reportData -and (-not $Quiet.IsPresent)) {
        Write-Status -Level SUCCESS -Message $LocalizedStrings.AnalysisComplete
    }

    return $reportData
}

function Show-ConsoleReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )

    $maxItems = $Configuration.AnalysisConfig.MaxDetailItems

    Write-SectionHeader -Title $LocalizedStrings.DiagnosticReport

    #region Dashboard
    $verdictColor = if ($Result.VerdictById.Contains("ATTENTION") -or $Result.VerdictById.Contains("ATENÇÃO")) { "Red" } else { "Green" }
    $keywordVerdictColor = if ($Result.VerdictByKeyword.Contains("ATTENTION") -or $Result.VerdictByKeyword.Contains("ATENÇÃO")) { "Yellow" } else { "Green" }

    Write-Host "  ┌─ Quick Dashboard ───────────────────────────────────────────────┐"
    Write-Host "  │"
    Write-Host ("  │ {0,-22}: " -f $LocalizedStrings.VerdictById) -NoNewline; Write-Host $Result.VerdictById -ForegroundColor $verdictColor
    Write-Host ("  │ {0,-22}: " -f $LocalizedStrings.VerdictByKeyword) -NoNewline; Write-Host $Result.VerdictByKeyword -ForegroundColor $keywordVerdictColor
    Write-Host ("  │ {0,-22}: {1}" -f "Analysis Period", $Result.AnalysisPeriod)
    Write-Host ("  │ {0,-22}: {1}" -f "Total Events Found", $Result.TotalEvents)
    Write-Host "  │"
    Write-Host "  └─────────────────────────────────────────────────────────────────┘"
    #endregion

    #region Critical Event Details (by ID)
    Write-Host "`n  ┌─ $($LocalizedStrings.CriticalEventDetails) ─────────────────────────────┐"
    Write-Host "  │"
    if ($Result.CriticalEvents) {
        $criticalSummary = $Result.CriticalEvents | Group-Object ProviderName | Select-Object Count, @{N = 'Source'; E = { $_.Name } } | Sort-Object Count -Descending | Select-Object -First $maxItems
        $criticalSummary | Format-Table -AutoSize | Out-String -Stream | ForEach-Object { "  │ $_".TrimEnd() }

        Write-Host "  │"
        Write-Host "  │ -> Details: Last $maxItems Critical Events" -ForegroundColor 'Yellow'

        # Using Splatting for better readability
        $criticalTableFormat = @{
            Property = @(
                @{N='Time';E={$_.TimeCreated}; A='left'},
                'Id',
                @{N='Provider';E={Get-ProviderShortName -FullName $_.ProviderName}},
                @{N='Message';E={($_.Message -split "`r`n")[0].Trim()}}
            )
            Wrap = $true
        }
        $Result.CriticalEvents | Format-Table @criticalTableFormat | Out-String -Stream | ForEach-Object { "  │ $_".TrimEnd() }
    } else {
        Write-Status -Level SUCCESS -Message $LocalizedStrings.NoCriticalEvents -Indent 2
    }
    Write-Host "  │"
    Write-Host "  └─────────────────────────────────────────────────────────────────┘"
    #endregion

    #region Keyword Alert Details
    if ($Result.KeywordEvents) {
        Write-Host "`n  ┌─ $($LocalizedStrings.KeywordAlertDetails) ────────────────────────────────────────┐"
        Write-Host "  │"
        Write-Host "  │ -> Details: Last $maxItems Events with Suspicious Keywords" -ForegroundColor "Yellow"

        # Using Splatting for better readability
        $keywordTableFormat = @{
            Property = 'TimeCreated', 'Id', 'Provider', 'MatchedKeyword', 'Message'
            Wrap = $true
        }
        $Result.KeywordEvents | Format-Table @keywordTableFormat | Out-String -Stream | ForEach-Object { "  │ $_".TrimEnd() }

        Write-Host "  │"
        Write-Host "  └─────────────────────────────────────────────────────────────────┘`n"
    }
    #endregion
}

Export-ModuleMember -Function Invoke-LogAnalysis, Show-ConsoleReport
