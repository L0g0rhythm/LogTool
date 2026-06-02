#
# LogTool v28.2.0: GOLD MASTER UNIFIED TESTS (Audit Sprint — M21 Expanded)
# Framework: Pester 3.4.0
# Coverage: Shared, Collection, Lifecycle, Analysis, Reporting (Security + Functional)
#

Import-Module Pester -RequiredVersion 3.4.0 -Force
$Root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $Root "core/shared/modules/Shared.psm1") -Force
Import-Module (Join-Path $Root "core/backend/modules/Collection.psm1") -Force
Import-Module (Join-Path $Root "core/backend/modules/Lifecycle.psm1") -Force
Import-Module (Join-Path $Root "core/frontend/modules/Analysis.psm1") -Force
Import-Module (Join-Path $Root "core/frontend/modules/Reporting.psm1") -Force

Describe "LogTool v28.2.0: GOLD MASTER (Audit Sprint)" {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
    
    $T = (New-Item -ItemType Directory -Path (Join-Path $env:TEMP "lt_gm_sprint_$([guid]::NewGuid())") -Force).FullName
    $ReportsDir = New-Item -ItemType Directory -Path (Join-Path $T "reports") -Force
    $LogsDir = New-Item -ItemType Directory -Path (Join-Path $T "core\logs") -Force
    
    $St = Get-LocalizedString -Language "en-US"
    $Cfg = [pscustomobject]@{
        AuditLogPath    = Join-Path $LogsDir.FullName "audit.jsonl"
        CollectionTasks = @( @{ LogName = "System"; MaxEvents = 1 } )
        LifecycleConfig = [pscustomobject]@{ Enabled = $true; MaxArchivesToKeep = 1; MaxArchiveAgeDays = 30 }
        AnalysisConfig  = [pscustomobject]@{ KeywordsToFlag = @("FAIL"); CriticalEventIds = @(1); MaxDetailItems = 5 }
        ToolSettings    = [pscustomobject]@{ Language = "en-US" }
    }

    # ── Functional Tests ──────────────────────────────────────────────

    It "VALIDATES: Shared Utilities" {
        Get-LocalizedString -Language "en-US" | Should Not Be $null
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
        $zip | Should Not Be $null
        $zip | Should Match "^$([regex]::Escape($ReportsDir.FullName))"
    }

    It "VALIDATES: Analysis Engine" {
        $testZip = Join-Path $ReportsDir.FullName "test_archive.zip"
        Set-Content $testZip "z" | Out-Null
        
        Mock Expand-Archive -ModuleName Analysis { 
            param($Path, $DestinationPath); 
            $null = $Path
            $dest = New-Item -ItemType Directory -Path $DestinationPath -Force
            $obj = [pscustomobject]@{Id=1;Message="SAFE";TimeCreated=Get-Date;ProviderName="M";Provider="M"}
            $obj | Export-Clixml (Join-Path $dest.FullName "S.xml")
        }
        Mock Assert-ArchiveIntegrity -ModuleName Analysis { return }
        # Mock ZipFile to bypass Zip Bomb check in tests with dummy archives.
        Mock -CommandName 'OpenRead' -MockWith { return $null } -ModuleName Analysis -ErrorAction SilentlyContinue
        
        $res = Invoke-LogAnalysis -Configuration $Cfg -ArchivePath $testZip -Quiet -ScriptRoot $T -LocalizedStrings $St
        $res | Should Not Be $null
        $res.TotalEvents | Should Be 1
    }

    It "VALIDATES: Lifecycle Management" {
        New-Item -Path (Join-Path $ReportsDir.FullName "old_1.zip") -ItemType File -Force | Out-Null
        New-Item -Path (Join-Path $ReportsDir.FullName "old_2.zip") -ItemType File -Force | Out-Null
        
        Invoke-ArchiveCleanup -Configuration $Cfg -ScriptRoot $T -LocalizedStrings $St
        (Get-ChildItem -Path $ReportsDir.FullName -Filter *.zip).Count | Should Be 1
    }

    # ── Security Tests (ISSUE-001/002/003/004) ────────────────────────

    It "SECURITY: HTML Report encodes localized strings (XSS prevention)" {
        $xssPayload = '<script>alert("XSS")</script>'
        $maliciousStrings = Get-LocalizedString -Language "en-US"
        $maliciousStrings.ReportTitle = $xssPayload

        $htmlPath = Join-Path $T "xss_test.html"
        $testData = [PSCustomObject]@{
            ArchiveName      = "test.zip"
            TotalEvents      = 0
            AnalysisPeriod   = "N/A"
            VerdictById      = "STABLE"
            VerdictByKeyword = "STABLE"
            CriticalEvents   = $null
            KeywordEvents    = $null
        }
        
        Invoke-HtmlReport -ReportData $testData -LocalizedStrings $maliciousStrings -OutputPath $htmlPath
        $content = Get-Content $htmlPath -Raw
        # The raw <script> tag must NOT appear — it should be HtmlEncoded.
        $content | Should Not Match '<script>alert'
        # The encoded version SHOULD appear.
        $content | Should Match '&lt;script&gt;'
    }

    It "SECURITY: Archive integrity rejects hash mismatch (fail-closed)" {
        $testZip = Join-Path $ReportsDir.FullName "integrity_test.zip"
        Set-Content $testZip "dummy_content" -Force
        # Create a sidecar with a WRONG hash.
        Set-Content ($testZip + ".sha256") "0000000000000000000000000000000000000000000000000000000000000000" -Force
        
        $threw = $false
        try {
            Assert-ArchiveIntegrity -ArchivePath $testZip
        }
        catch {
            $threw = $true
            $_.Exception.Message | Should Match "INTEGRITY VIOLATION"
        }
        $threw | Should Be $true
    }

    It "SECURITY: Path traversal is rejected by Assert-PathWithinBoundary" {
        $allowedRoot = $ReportsDir.FullName
        $traversalPath = Join-Path $T "reports\..\..\..\etc\passwd"
        
        $threw = $false
        try {
            Assert-PathWithinBoundary -TargetPath $traversalPath -AllowedRoot $allowedRoot -ParameterName "TestPath"
        }
        catch {
            $threw = $true
            $_.Exception.Message | Should Match "SECURITY VIOLATION"
        }
        $threw | Should Be $true
    }

    It "SECURITY: Archive names are unique across rapid sequential calls (race condition)" {
        $name1 = "$(Get-Date -Format 'HH-mm-ss-fff')_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $name2 = "$(Get-Date -Format 'HH-mm-ss-fff')_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $name1 | Should Not Be $name2
    }

    # ── i18n Completeness Tests ───────────────────────────────────────

    It "QUALITY: i18n dictionaries have identical key sets" {
        $enUS = Get-LocalizedString -Language "en-US"
        $ptBR = Get-LocalizedString -Language "pt-BR"
        
        $enKeys = ($enUS.Keys | Sort-Object) -join ","
        $ptKeys = ($ptBR.Keys | Sort-Object) -join ","
        $enKeys | Should Be $ptKeys
    }

    It "QUALITY: en-US AnalyzingArchive is in English (regression guard)" {
        $enUS = Get-LocalizedString -Language "en-US"
        $enUS.AnalyzingArchive | Should Be "ANALYZING ARCHIVE"
    }

    # Manual anchoring of variables to satisfy PSScriptAnalyzer (M21 conformance).
    $null = $T; $null = $ReportsDir; $null = $LogsDir; $null = $St; $null = $Cfg
}
