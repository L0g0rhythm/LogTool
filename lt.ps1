#
# LogTool - Smart Launcher (lt.ps1) v23.1 (Secure & Refactored)
#
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('collect', 'analyze', 'create-report', 'create-report-from')]
    [string]$Command,

    [Parameter(Position=1, Mandatory=$false)]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [int[]]$IncludeEventId,

    [Parameter(Mandatory=$false)]
    [string]$Keyword
)

#region Private Functions
# Private helper function to centralize report path generation logic.
function Get-IntelligentReportPath {
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]$ArchiveItem
    )
    process {
        $reportFileName = "LogTool_Report_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').html"
        return Join-Path -Path $ArchiveItem.DirectoryName -ChildPath $reportFileName
    }
}
#endregion

try {
    # Core Engine Validation
    $engineScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "logtool.ps1"
    if (-not (Test-Path -LiteralPath $engineScriptPath -PathType Leaf)) {
        throw "Core engine script 'logtool.ps1' not found in the script directory."
    }

    # Prepare parameters to pass to the engine
    $engineParams = @{}
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        $engineParams[$_.Key] = $_.Value
    }

    $engineParams.Remove('Command')
    if ($engineParams.ContainsKey('Path')) {
        $engineParams.Remove('Path')
    }

    # Command translation logic
    switch ($Command) {
        'collect' {
            $engineParams.Add('Mode', 'Collect')
        }
        'analyze' {
            $engineParams.Add('Mode', 'Analyze')
            if ($PSBoundParameters.ContainsKey('Path')) {
                $engineParams.Add('ArchivePath', $Path)
            }
        }
        'create-report' {
            $engineParams.Add('Mode', 'Analyze')
            $reportsDir = Join-Path -Path $PSScriptRoot -ChildPath "reports"

            # Robustness: Check if reports directory exists
            if (-not (Test-Path -Path $reportsDir -PathType Container)) {
                throw "The 'reports' directory does not exist. Run 'lt collect' first to generate log archives."
            }

            $latestArchive = Get-ChildItem -Path $reportsDir -Filter "*.zip" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $latestArchive) { throw "Could not find any log archives in '$reportsDir'. Run 'lt collect' first." }

            Write-Host "[INFO] Automatically selected the latest archive for reporting: $($latestArchive.FullName)" -ForegroundColor Cyan
            $engineParams.Add('ArchivePath', $latestArchive.FullName)

            # --- INTELLIGENT PATHING ---
            $engineParams.Add('OutputPath', (Get-IntelligentReportPath -ArchiveItem $latestArchive))
        }
        'create-report-from' {
            $engineParams.Add('Mode', 'Analyze')
            if (-not $PSBoundParameters.ContainsKey('Path')) { throw "This command requires a path to a log archive. Usage: lt create-report-from <path\to\archive.zip>" }

            $archiveInfo = Get-Item -LiteralPath $Path -ErrorAction Stop
            $engineParams.Add('ArchivePath', $archiveInfo.FullName)

            # --- INTELLIGENT PATHING ---
            $engineParams.Add('OutputPath', (Get-IntelligentReportPath -ArchiveItem $archiveInfo))
        }
    }

    & $engineScriptPath @engineParams

} catch {
    Write-Error "A critical error occurred in the launcher: $($_.Exception.Message)"
    exit 1
}
