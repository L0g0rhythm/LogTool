# LogTool - Backend Domain Engine v28.0 (SRP Max)
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [Parameter(Mandatory = $false)][string]$ArchivePath,
    [Parameter(Mandatory = $false)][int[]]$IncludeEventId,
    [Parameter(Mandatory = $false)][string]$Keyword
)

#region Domain Bootstrap: Module Loading
try {
    $domainRoot  = $PSScriptRoot
    $sharedRoot  = Join-Path -Path $domainRoot -ChildPath "..\shared"
    $importParams = @{ Force = $true; WarningAction = 'SilentlyContinue' }

    Import-Module (Join-Path -Path $sharedRoot -ChildPath "modules\Shared.psm1")      @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Collection.psm1") @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Lifecycle.psm1")  @importParams
}
catch {
    Write-Error "FATAL (Backend Domain): Failed to load modules. Error: $($_.Exception.Message)"
    exit 1
}
#endregion

#region Domain Execution
try {
    $config           = Get-ToolConfiguration -ScriptRoot (Join-Path -Path $domainRoot -ChildPath "..")
    $localizedStrings = Get-LocalizedStrings -Language $config.ToolSettings.Language

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "CRITICAL: Backend 'Collect' operation requires administrative privileges."
        exit 1
    }

    $moduleParams = @{
        Configuration    = $config
        ScriptRoot       = (Join-Path -Path $domainRoot -ChildPath "..\..") # Project Root
        LocalizedStrings = $localizedStrings
    }
    if ($PSBoundParameters.ContainsKey('Verbose')) { $moduleParams.Add('Verbose', $true) }

    Invoke-LogCollection @moduleParams
}
catch {
    $errorMessage = "Unhandled error in backend domain: $($_.Exception.Message)"
    Write-Error $errorMessage
    if (Get-Command "Write-AuditLog" -ErrorAction SilentlyContinue) {
        Write-AuditLog -Level 'ERROR' -Message $errorMessage -Configuration $config
    }
    exit 1
}
#endregion
