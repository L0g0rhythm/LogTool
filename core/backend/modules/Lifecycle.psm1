#
# Module: Lifecycle.psm1 v28.0 (SRP Max)
# Description: Professional archive maintenance and lifecycle enforcement.
#              SRP: Isolated from core collection logic for domain purity.
# Author: L0g0rhythm
#

#region Private Helpers

    # DRY helper for secure archive removal and manifest cleanup.
    function Remove-ArchiveFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$ReasonMessage,
        [Parameter(Mandatory = $true)][psobject]$Configuration
    )
    try {
        Write-Status -Level WARN -Message $ReasonMessage -Indent 4
        Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
        
        $manifestPath = $File.FullName + ".sha256"
        if (Test-Path -LiteralPath $manifestPath) {
            Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
        }
        return $true
    }
    catch {
        Write-AuditLog -Level ERROR -Message "Failed to delete archive '$($File.FullName)'. Error: $($_.Exception.Message)" -Configuration $Configuration
        return $false
    }
}

#endregion

#region Public Functions

    # Enforcement engine for count-based and age-based archival rotation policies.
    function Invoke-ArchiveCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$ScriptRoot,
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )

    $config = $Configuration.LifecycleConfig
    if (-not $config.Enabled) { return }

    Write-Status -Level INFO -Message $LocalizedStrings.RunningCleanup
    $reportsDir = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsDir)) { return }

    $allArchives = Get-ChildItem -Path $reportsDir -Filter "*.zip" -Recurse
    if (-not $allArchives) { return }

    $deletedCount = 0
    $now = Get-Date
    $archivesToKeep = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($archive in $allArchives) {
        # Validates LastWriteTime to ensure integrity across filesystem sync operations.
        $ageDays = ($now - $archive.LastWriteTime).TotalDays

        if ($ageDays -gt $config.MaxArchiveAgeDays) {
            $message = $LocalizedStrings.DeletingOldByAge -f $config.MaxArchiveAgeDays, $archive.Name
            if (Remove-ArchiveFile -File $archive -ReasonMessage $message -Configuration $Configuration) {
                $deletedCount++
            }
        }
        else {
            $archivesToKeep.Add($archive)
        }
    }

    if ($archivesToKeep.Count -gt $config.MaxArchivesToKeep) {
        $sortedToKeep = $archivesToKeep | Sort-Object LastWriteTime -Descending
        $toDelete = $sortedToKeep | Select-Object -Skip $config.MaxArchivesToKeep

        foreach ($archive in $toDelete) {
            $message = $LocalizedStrings.DeletingOldByCount -f $config.MaxArchivesToKeep, $archive.Name
            if (Remove-ArchiveFile -File $archive -ReasonMessage $message -Configuration $Configuration) {
                $deletedCount++
            }
        }
    }

    if ($deletedCount -gt 0) {
        Write-AuditLog -Message "Archive cleanup complete. Deleted $deletedCount file(s)." -Configuration $Configuration
    }
}

#endregion

Export-ModuleMember -Function Invoke-ArchiveCleanup
