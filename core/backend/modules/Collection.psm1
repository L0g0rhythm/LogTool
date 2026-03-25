# Module: Collection.psm1 v28.0 (SRP Max)
# Description: Professional log collection engine for Windows Event Logs and filesystem artifacts.
#              SRP: Strictly limited to acquisition and pre-deserialization hashing.
# Author: L0g0rhythm
#

#region Private Helpers


function New-ArchiveManifest {
    # Non-negotiable integrity anchor for pre-deserialization safety.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][psobject]$Configuration
    )
    try {
        $hash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256 -ErrorAction Stop).Hash
        $manifestPath = $ArchivePath + ".sha256"
        Set-Content -Path $manifestPath -Value $hash -Encoding ASCII -ErrorAction Stop
        Write-AuditLog -Message "Integrity manifest created for '$([System.IO.Path]::GetFileName($ArchivePath))'. SHA256: $hash" -Configuration $Configuration
    }
    catch {
        Write-AuditLog -Level WARN -Message "Could not create integrity manifest for '$ArchivePath'. Error: $($_.Exception.Message)" -Configuration $Configuration
    }
}

function Invoke-CompressedArchiveWithTimeout {
    # Isolate compression in a background job to prevent process-level deadlock.
    # Default 60s timeout for stability; fails closed if exceeded.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [int]$TimeoutSec = 60
    )
    $job = Start-Job -ScriptBlock {
        param($s, $d)
        Compress-Archive -Path $s -DestinationPath $d -Force
    } -ArgumentList $Source, $Destination

    if (Wait-Job $job -Timeout $TimeoutSec) {
        $result = Receive-Job $job -ErrorAction Stop
        Remove-Job $job
        if (-not (Test-Path -LiteralPath $Destination)) {
            throw "Compression job finished but destination file is missing."
        }
    }
    else {
        Stop-Job $job
        Remove-Job $job
        throw "Compression timed out after $TimeoutSec seconds. Check for I/O locks by external processes (AV/EDR)."
    }
}


#endregion

#region Public Functions



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
        $userName    = Resolve-SafePathPart -PathPart $env:USERNAME
        $workingDirectoryPath = Join-Path -Path $ScriptRoot -ChildPath "reports\$machineName\$userName\$(Get-Date -Format 'yyyy-MM-dd')\$(Get-Date -Format 'HH-mm-ss')"
        New-Item -ItemType Directory -Path $workingDirectoryPath -Force -ErrorAction Stop | Out-Null
        #endregion

        #region Task Execution Loop
        $totalTasks = $Configuration.CollectionTasks.Count
        for ($i = 0; $i -lt $totalTasks; $i++) {
            $task    = $Configuration.CollectionTasks[$i]
            $logName = $task.LogName

            #region Progress Display
            if ($VerbosePreference -eq 'Continue') {
                Write-Status -Level INFO -Message ($LocalizedStrings.CollectingLog -f $logName)
            }
            else {
                $progress        = [math]::Ceiling((($i + 1) / $totalTasks) * 100)
                $progressBar     = ("=" * ($progress / 4)) + (" " * ((100 - $progress) / 4))
                $progressMessage = $LocalizedStrings.CollectingLog -f $logName.PadRight(20)
                Write-Host -NoNewline "`r  [*] $progressMessage [$progressBar] $progress% "
            }
            #endregion

            Write-AuditLog -Message "Executing collection task for log: $logName" -Configuration $Configuration

            try {
                $outputFilePath = Join-Path -Path $workingDirectoryPath -ChildPath "$logName.xml"
                $eventParams    = @{ ErrorAction = 'Stop' }

                if ($task.MaxEvents -gt 0) { $eventParams.MaxEvents = $task.MaxEvents }

                if ($null -ne $task.Filter) {
                    $task.Filter.LogName   = $logName
                    $eventParams.FilterHashtable = $task.Filter
                }
                else {
                    $eventParams.LogName = $logName
                }

                $foundEvents = Get-WinEvent @eventParams

                if ($foundEvents) {
                    $foundEvents | Export-Clixml -Path $outputFilePath
                    Write-AuditLog -Message "Exported $($foundEvents.Count) events from '$logName'." -Configuration $Configuration
                }
                else {
                    Write-AuditLog -Level WARN -Message "No events found for '$logName' with current filter." -Configuration $Configuration
                    Set-Content -Path $outputFilePath -Value ""
                }
            }
            catch {
                Write-AuditLog -Level ERROR -Message "Failed collection task for '$logName'. Error: $($_.Exception.Message)" -Configuration $Configuration
            }
        }
        Write-Host ""
        #endregion

        #region Archiving
        Write-Status -Level INFO -Message $LocalizedStrings.ArchivingLogs
        $archivePath = Join-Path -Path (Split-Path $workingDirectoryPath -Parent) -ChildPath "$(Split-Path $workingDirectoryPath -Leaf).zip"

        if ((Get-ChildItem -Path "$workingDirectoryPath\*").Count -gt 0) {
            # AUD-RES-01: Resilient compression with explicit 60s timeout.
            Invoke-CompressedArchiveWithTimeout -Source "$workingDirectoryPath\*" -Destination $archivePath -TimeoutSec 60
        }
        else {
            Write-AuditLog -Level WARN -Message "Working directory is empty. No archive created." -Configuration $Configuration
            Write-Status -Level WARN -Message "No events were collected. No archive created."
            return
        }

        if (Test-Path -LiteralPath $archivePath) {
            Remove-Item -Path $workingDirectoryPath -Recurse -Force
        }
        else {
            Write-Error -Message "Archive not found at '$archivePath' after compression." -ErrorId 'ArchiveCreationFailed' -Category OperationStopped
            return
        }
        #endregion

        # Pre-deserialization integrity anchor (v28+ Protocol).
        New-ArchiveManifest -ArchivePath $archivePath -Configuration $Configuration
        #endregion

        #region ACL Hardening
        $acl = Get-Acl -Path $archivePath
        $acl.SetAccessRuleProtection($true, $false)
        $identities = @(
            "S-1-5-18",        # SYSTEM
            "S-1-5-32-544",    # BUILTIN\Administrators
            [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        ) | ForEach-Object { New-Object System.Security.Principal.SecurityIdentifier($_) }

        foreach ($identity in $identities) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
        }
        Set-Acl -Path $archivePath -AclObject $acl
        Write-AuditLog -Message "ACL hardening applied to '$([System.IO.Path]::GetFileName($archivePath))'." -Configuration $Configuration
        #endregion

        Write-Status -Level SUCCESS -Message $LocalizedStrings.CollectionComplete
        Write-Host "    $($LocalizedStrings.ArchiveSavedTo -f $archivePath)"
    }
    finally {
        if ($Configuration.LifecycleConfig.Enabled) {
            Invoke-ArchiveCleanup -Configuration $Configuration -ScriptRoot $ScriptRoot -LocalizedStrings $LocalizedStrings
        }

        $endTime  = Get-Date
        $duration = New-TimeSpan -Start $startTime -End $endTime
        Write-AuditLog -Level HEADER -Message "======== LOG COLLECTION FINISHED (Duration: $($duration.TotalSeconds.ToString('F2'))s) ========" -Configuration $Configuration
    }
}

#endregion

Export-ModuleMember -Function Invoke-LogCollection
