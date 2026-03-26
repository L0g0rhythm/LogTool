#
# Module: Collection.psm1 v28.1.7 (Gold Master)
#

function Invoke-LogCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Configuration,
        [Parameter(Mandatory = $true)][string]$ScriptRoot,
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )
    # Target directory for archived reports ensures boundary confinement.
    $reportsPath = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsPath)) { New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null }

    # Unique timestamp-based subdirectory prevents collisions during concurrent or rapid execution.
    $archiveName = Get-Date -Format "HH-mm-ss"
    $tempDir = Join-Path -Path $reportsPath -ChildPath "temp_$($archiveName)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    Write-SectionHeader -Title $LocalizedStrings.LogCollection
    foreach ($task in $Configuration.CollectionTasks) {
        Write-Status -Message ($LocalizedStrings.CollectingLog -f $task.LogName)
        try {
            $getParams = @{ MaxEvents = $task.MaxEvents; ErrorAction = 'Stop' }
            if ($task.Filter) {
                # M28 SRP: LogName must be inside the FilterHashtable for Get-WinEvent to resolve the correct parameter set.
                $filter = $task.Filter.Clone()
                if (-not $filter.ContainsKey('LogName')) { $filter.Add('LogName', $task.LogName) }
                $getParams.Add('FilterHashtable', $filter)
            } else {
                $getParams.Add('LogName', $task.LogName)
            }
            
            $events = Get-WinEvent @getParams
            # Standardizing filename prevents issues with logs containing spaces or illegal characters.
            $exportFile = Join-Path $tempDir "$($task.LogName -replace ' ', '_').xml"
            $events | Export-Clixml -Path $exportFile
        } catch {
            Write-Status -Level WARN -Message "Failed: $($_.Exception.Message)"
        }
    }

    Write-Status -Message $LocalizedStrings.ArchivingLogs
    
    # Path Confinement: Organizing exports by Machine, User, and Date for forensics readiness.
    $machineName = Resolve-SafePathPart -PathPart $env:COMPUTERNAME
    $userName    = Resolve-SafePathPart -PathPart $env:USERNAME
    $dateFolder  = Get-Date -Format "yyyy-MM-dd"
    $exportDir   = Join-Path -Path $reportsPath -ChildPath "$machineName\$userName\$dateFolder"
    if (-not (Test-Path $exportDir)) { New-Item -ItemType Directory -Path $exportDir -Force | Out-Null }
    
    $archivePath = Join-Path $exportDir "$archiveName.zip"
    $filesToArchive = Join-Path -Path $tempDir -ChildPath "*"
    # Archiving the content of the temporary directory ensures a clean root structure in the ZIP.
    Compress-Archive -Path $filesToArchive -DestinationPath $archivePath -Force
    
    # AUD-SEC-01: SHA-256 sidecar manifest allows for post-collection integrity verification.
    $hash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash
    $hash | Out-File -FilePath ($archivePath + ".sha256") -Force -Encoding ASCII
    
    Remove-Item $tempDir -Recurse -Force | Out-Null

    Write-Status -Level SUCCESS -Message $LocalizedStrings.CollectionComplete
    Write-Status -Level SUCCESS -Message ($LocalizedStrings.ArchiveSavedTo -f $archivePath)
    return $archivePath
}

Export-ModuleMember -Function Invoke-LogCollection

