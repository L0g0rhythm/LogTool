# LogTool Backend Engine v28.1.7 (SRP Max)
#

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [Parameter(Mandatory = $true)][string]$ScriptRoot,
    [Parameter(Mandatory = $false)][string]$Language = "en-US"
)

# Domain Boundary: The backend engine resides within its own physical subdirectory.
$domainRoot = $PSScriptRoot
$sharedRoot = Join-Path -Path $domainRoot -ChildPath "..\shared"

# Security & SRP: Loading only the modules required for backend operations.
try {
    $importParams = @{ Force = $true; WarningAction = 'SilentlyContinue' }
    Import-Module (Join-Path -Path $sharedRoot -ChildPath "modules\Shared.psm1")      @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Collection.psm1") @importParams
    Import-Module (Join-Path -Path $domainRoot -ChildPath "modules\Lifecycle.psm1")  @importParams
}
catch {
    Write-Error "FATAL (Backend): Failed to load modules. Error: $($_.Exception.Message)"
    exit 1
}

try {
    # SSOT: Fetching configuration to ensure all subsequent parameters follow the central policy.
    $config = Get-ToolConfiguration -ScriptRoot $ScriptRoot
    $localizedStrings = Get-LocalizedString -Language $Language
    
    # Environment synchronization ensures prerequisite directories exist.
    Initialize-SystemEnvironment -ScriptRoot $ScriptRoot
    
    if ($Mode -eq 'Collect') {
        # Lifecycle management is triggered before collection to prevent storage exhaustion or noise.
        Invoke-ArchiveCleanup -Configuration $config -ScriptRoot $ScriptRoot -LocalizedStrings $localizedStrings
        
        # Explicit return of the archive path allows the launcher to orchestrate the frontend transition.
        return Invoke-LogCollection -Configuration $config -ScriptRoot $ScriptRoot -LocalizedStrings $localizedStrings
    }
}
catch {
    Write-Status -Level ERROR -Message "BACKEND CRITICAL: $($_.Exception.Message)"
    exit 1
}

