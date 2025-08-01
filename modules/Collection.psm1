#region Internal Functions

function Remove-ArchiveFile {
    # Internal helper to enforce DRY principle for archive deletion.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [string]$ReasonMessage,

        [Parameter(Mandatory = $true)]
        [psobject]$Configuration
    )

    try {
        Write-Status -Level WARN -Message $ReasonMessage -Indent 4
        Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-AuditLog -Level ERROR -Message "Failed to delete old archive '$($File.FullName)'. Error: $($_.Exception.Message)" -Configuration $Configuration
        return $false
    }
}

#endregion Internal Functions

#region Public Functions

function Invoke-ArchiveCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$ScriptRoot,
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )

    #region Pre-check
    $config = $Configuration.LifecycleConfig
    if (-not $config.Enabled) { return }
    #endregion

    Write-Status -Level INFO -Message $LocalizedStrings.RunningCleanup
    $reportsDir = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsDir)) { return }

    #region Efficiency Improvement: Get all archives once and process in-memory
    $allArchives = Get-ChildItem -Path $reportsDir -Filter "*.zip" -Recurse
    if (-not $allArchives) { return }

    $deletedCount = 0
    $now = Get-Date

    $archivesToKeep = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($archive in $allArchives) {
        if (($now - $archive.CreationTime).TotalDays -gt $config.MaxArchiveAgeDays) {
            $message = $LocalizedStrings.DeletingOldByAge -f $config.MaxArchiveAgeDays, $archive.Name
            if (Remove-ArchiveFile -File $archive -ReasonMessage $message -Configuration $Configuration) {
                $deletedCount++
            }
        } else {
            $archivesToKeep.Add($archive)
        }
    }
    #endregion

    #region Count-based Cleanup (on remaining files)
    if ($archivesToKeep.Count -gt $config.MaxArchivesToKeep) {
        $sortedArchivesToKeep = $archivesToKeep | Sort-Object CreationTime -Descending
        $archivesToDelete = $sortedArchivesToKeep | Select-Object -Skip $config.MaxArchivesToKeep

        foreach ($archive in $archivesToDelete) {
            $message = $LocalizedStrings.DeletingOldByCount -f $config.MaxArchivesToKeep, $archive.Name
            if (Remove-ArchiveFile -File $archive -ReasonMessage $message -Configuration $Configuration) {
                $deletedCount++
            }
        }
    }
    #endregion

    if ($deletedCount -gt 0) {
        Write-AuditLog -Message "Archive cleanup complete. Deleted $deletedCount file(s)." -Configuration $Configuration
    }
}


function Invoke-LogCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$ScriptRoot,
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )

    $startTime = Get-Date
    Show-ToolHeader -LocalizedStrings $LocalizedStrings
    Write-SectionHeader -Title $LocalizedStrings.LogCollection
    Write-AuditLog -Level HEADER -Message "======== LOG COLLECTION STARTED: $startTime ========" -Configuration $Configuration

    try {
        #region Path Generation
        $machineName = Resolve-SafePathPart -PathPart $env:COMPUTERNAME
        $userName = Resolve-SafePathPart -PathPart $env:USERNAME
        $workingDirectoryPath = Join-Path -Path $ScriptRoot -ChildPath "reports\$machineName\$userName\$(Get-Date -Format 'yyyy-MM-dd')\$(Get-Date -Format 'HH-mm-ss')"
        New-Item -ItemType Directory -Path $workingDirectoryPath -Force -ErrorAction Stop | Out-Null
        #endregion

        #region Task Execution Loop
        $totalTasks = $Configuration.CollectionTasks.Count
        for ($i = 0; $i -lt $totalTasks; $i++) {
            $task = $Configuration.CollectionTasks[$i]
            $logName = $task.LogName

            #region Progress Display
            if ($VerbosePreference -eq 'Continue') {
                Write-Status -Level INFO -Message ($LocalizedStrings.CollectingLog -f $logName)
            } else {
                $progress = [math]::Ceiling((($i + 1) / $totalTasks) * 100)
                $progressBar = ("=" * ($progress / 4)) + (" " * ((100 - $progress) / 4))
                $progressMessage = $LocalizedStrings.CollectingLog -f $logName.PadRight(20)
                Write-Host -NoNewline "`r  [*] $progressMessage [$progressBar] $progress% "
            }
            #endregion
            Write-AuditLog -Message "Executing collection task for log: $logName" -Configuration $Configuration

            try {
                $outputFilePath = Join-Path -Path $workingDirectoryPath -ChildPath "$logName.xml"
                $eventParams = @{ ErrorAction = 'Stop' }
                if ($task.MaxEvents -gt 0) { $eventParams.MaxEvents = $task.MaxEvents }

                if ($null -ne $task.Filter) {
                    $task.Filter.LogName = $logName
                    $eventParams.FilterHashtable = $task.Filter
                } else {
                    $eventParams.LogName = $logName
                }

                # Robustness: Removed incorrect stream redirection (4>$null)
                $foundEvents = Get-WinEvent @eventParams

                if ($foundEvents) {
                    $foundEvents | Export-Clixml -Path $outputFilePath
                    Write-AuditLog -Message "Successfully exported $($foundEvents.Count) events from '$logName'." -Configuration $Configuration
                } else {
                    Write-AuditLog -Level WARN -Message "No events found for log '$logName' with the current filter." -Configuration $Configuration
                    Set-Content -Path $outputFilePath -Value ""
                }
            } catch {
                Write-AuditLog -Level ERROR -Message "Failed to process task for log '$logName'. Error: $($_.Exception.Message)" -Configuration $Configuration
            }
        }
        Write-Host ""
        #endregion

        #region Archiving
        Write-Status -Level INFO -Message $LocalizedStrings.ArchivingLogs
        $archivePath = Join-Path -Path (Split-Path $workingDirectoryPath -Parent) -ChildPath "$(Split-Path $workingDirectoryPath -Leaf).zip"

        if ((Get-ChildItem -Path "$workingDirectoryPath\*").Count -gt 0) {
            Compress-Archive -Path "$workingDirectoryPath\*" -DestinationPath $archivePath -Force -ErrorAction Stop
        } else {
            Write-AuditLog -Level WARN -Message "Working directory is empty. No archive will be created." -Configuration $Configuration
            Write-Status -Level WARN -Message "No events were collected, so no archive was created."
            return
        }

        if (Test-Path -LiteralPath $archivePath) {
            Remove-Item -Path $workingDirectoryPath -Recurse -Force
        } else {
            # Robustness: Using Write-Error for a more structured, non-terminating error.
            Write-Error -Message "Archive file was not found at '$archivePath' after compression." -ErrorId 'ArchiveCreationFailed' -Category OperationStopped
            return
        }
        #endregion

        #region ACL Configuration
        $acl = Get-Acl -Path $archivePath
        $acl.SetAccessRuleProtection($true, $false)
        $identities = @("S-1-5-18", "S-1-5-32-544", [System.Security.Principal.WindowsIdentity]::GetCurrent().User) | ForEach-Object { New-Object System.Security.Principal.SecurityIdentifier($_) }
        foreach ($identity in $identities) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
        }
        Set-Acl -Path $archivePath -AclObject $acl
        Write-AuditLog -Message "ACL applied successfully to archive '$archivePath'." -Configuration $Configuration
        #endregion

        Write-Status -Level SUCCESS -Message $LocalizedStrings.CollectionComplete
        Write-Host "    $($LocalizedStrings.ArchiveSavedTo -f $archivePath)"
    }
    finally {
        #region Finalization & Cleanup
        if ($Configuration.LifecycleConfig.Enabled) {
            Invoke-ArchiveCleanup -Configuration $Configuration -ScriptRoot $ScriptRoot -LocalizedStrings $LocalizedStrings
        }

        $endTime = Get-Date
        $duration = New-TimeSpan -Start $startTime -End $endTime
        Write-AuditLog -Level HEADER -Message "======== LOG COLLECTION FINISHED (Duration: $($duration.TotalSeconds.ToString('F2')) seconds) ========" -Configuration $Configuration
        #endregion
    }
}

Export-ModuleMember -Function Invoke-LogCollection

#endregion Public Functions
