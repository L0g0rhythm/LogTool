#
# LogTool v28.1.7: GOLD MASTER UNIFIED TESTS
# Framework: Pester 5.7.1 (AEGIS Purified)
#

$Root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $Root "core/shared/modules/Shared.psm1") -Force
Import-Module (Join-Path $Root "core/backend/modules/Collection.psm1") -Force
Import-Module (Join-Path $Root "core/backend/modules/Lifecycle.psm1") -Force
Import-Module (Join-Path $Root "core/frontend/modules/Analysis.psm1") -Force

Describe "LogTool v28.1.7: GOLD MASTER (Purified)" {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
    BeforeAll {
        $T = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "lt_gm_purified_$([guid]::NewGuid())") -Force).FullName
        $ReportsDir = New-Item -ItemType Directory -Path (Join-Path $T "reports") -Force
        
        $St = Get-LocalizedString -Language "en-US"
        $Cfg = [pscustomobject]@{
            AuditLogPath    = Join-Path $T "audit.log"
            CollectionTasks = @( @{ LogName = "System"; MaxEvents = 1 } )
            LifecycleConfig = [pscustomobject]@{ Enabled = $true; MaxArchivesToKeep = 1; MaxArchiveAgeDays = 30 }
            AnalysisConfig  = [pscustomobject]@{ KeywordsToFlag = @("FAIL"); CriticalEventIds = @(1); MaxDetailItems = 5 }
            ToolSettings    = [pscustomobject]@{ Language = "en-US" }
        }
    }

    It "VALIDATES: Shared Utilities" {
        Get-LocalizedString -Language "en-US" | Should -Not -BeNullOrEmpty
    }

    It "VALIDATES: Collection Cycle" {
        Mock Get-WinEvent -ModuleName Collection { return @([pscustomobject]@{ Id=1; Message="OK"; TimeCreated=Get-Date; ProviderName="M" }) }
        Mock Export-Clixml -ModuleName Collection { 
            param($Path, $InputObject); 
            $null = $Path; $null = $InputObject
        }
        Mock Compress-Archive -ModuleName Collection { 
            param($Path, $DestinationPath); 
            $null = $Path; Set-Content $DestinationPath "z" | Out-Null 
        }
        
        $zip = Invoke-LogCollection -Configuration $Cfg -ScriptRoot $T -LocalizedStrings $St
        $zip | Should -Not -BeNullOrEmpty
        $zip | Should -Match "^$([regex]::Escape($ReportsDir.FullName))"
    }

    It "VALIDATES: Analysis Engine" {
        # Prepare test archive within the allowed 'reports' boundary.
        $testZip = Join-Path $ReportsDir.FullName "test_archive.zip"
        Set-Content $testZip "z" | Out-Null
        
        Mock Expand-Archive -ModuleName Analysis { 
            param($Path, $DestinationPath); 
            $null = $Path
            $dest = New-Item -ItemType Directory -Path $DestinationPath -Force
            $obj = [pscustomobject]@{Id=1;Message="SAFE";TimeCreated=Get-Date;ProviderName="M";Provider="M"}
            $obj | Export-Clixml (Join-Path $dest.FullName "S.xml")
            Write-Output "[MOCK] Exported S.xml to $($dest.FullName)"
        }
        Mock Assert-ArchiveIntegrity -ModuleName Analysis { return }
        
        $res = Invoke-LogAnalysis -Configuration $Cfg -ArchivePath $testZip -Quiet -ScriptRoot $T -LocalizedStrings $St
        if ($null -eq $res) { Write-Output "[DEBUG] Analysis result is NULL" }
        else { Write-Output "[DEBUG] Analysis result found. TotalEvents: $($res.TotalEvents)" }
        
        $res | Should -Not -BeNullOrEmpty
        $res.TotalEvents | Should -Be 1
    }

    It "VALIDATES: Lifecycle Management" {
        # Populate reports directory for count-based cleanup test.
        New-Item -Path (Join-Path $ReportsDir.FullName "old_1.zip") -ItemType File -Force | Out-Null
        New-Item -Path (Join-Path $ReportsDir.FullName "old_2.zip") -ItemType File -Force | Out-Null
        
        Invoke-ArchiveCleanup -Configuration $Cfg -ScriptRoot $T -LocalizedStrings $St
        (Get-ChildItem -Path $ReportsDir.FullName -Filter *.zip).Count | Should -Be 1
    }

    AfterAll {
        if (Test-Path $T) { Remove-Item -Path $T -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
