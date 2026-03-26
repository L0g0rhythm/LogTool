#
# Module: Lifecycle.psm1 v28.1.7 (SRP Max)
#

#region Private Helpers

function Remove-ArchiveFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$File,
        [Parameter(Mandatory = $true)][string]$ReasonMessage,
        [Parameter(Mandatory = $true)][psobject]$Configuration
    )
    # Encapsulated file removal ensures that sidecar manifest (.sha256) is never orphaned.
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

function Invoke-ArchiveCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Configuration,
        [Parameter(Mandatory = $true)]$ScriptRoot,
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )
    # Policy Enforcement: Early exit if lifecycle management is disabled in SSOT config.
    $config = $Configuration.LifecycleConfig
    if (-not $config.Enabled) { return }

    Write-Status -Level INFO -Message $LocalizedStrings.RunningCleanup
    $reportsDir = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsDir)) { return }

    # Recursive discovery allows for multi-tenant (Machine/User) directory structure support.
    $allArchives = Get-ChildItem -Path $reportsDir -Filter "*.zip" -Recurse
    if (-not $allArchives) { return }

    $deletedCount = 0
    $now = Get-Date
    $archivesToKeep = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($archive in $allArchives) {
        # Age-based retention policy: Purge archives older than MaxArchiveAgeDays.
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

    # Count-based retention policy: Ensure only the most recent N archives are preserved.
    if ($archivesToKeep.Count -gt $config.MaxArchivesToKeep) {
        # O(n log n) sort is handled by native .NET implementations for performance.
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

