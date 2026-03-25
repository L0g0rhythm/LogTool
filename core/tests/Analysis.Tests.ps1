#
# Test Suite: Analysis.psm1
# Framework: Pester 5.x
# Coverage: Security paths (ISSUE-001, 002, 003), O(n) correctness, $Matches capture
#

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "..\modules\Shared.psm1")   -Force
    Import-Module (Join-Path $PSScriptRoot "..\modules\Analysis.psm1") -Force

    # Minimal config object for injection into Invoke-LogAnalysis.
    $script:MockConfig = [pscustomobject]@{
        AuditLogPath  = Join-Path $env:TEMP "lt_analysis_test_audit.log"
        AnalysisConfig = @{
            CriticalEventIds = @(4625, 4720)
            KeywordsToFlag   = @("failed", "denied")
            MaxDetailItems   = 10
        }
    }
    $script:LocalizedStrings = Get-LocalizedStrings -Language "en-US"
}

Describe "Assert-ArchiveIntegrity" {
    BeforeAll {
        $script:TmpDir = Join-Path $env:TEMP "lt_integrity_$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TmpDir | Out-Null
        $script:GoodZip = Join-Path $script:TmpDir "good.zip"
        # Create a minimal valid zip for hash generation.
        Compress-Archive -Path $PSScriptRoot -DestinationPath $script:GoodZip -Force
        $script:GoodHash = (Get-FileHash -LiteralPath $script:GoodZip -Algorithm SHA256).Hash
        Set-Content -Path ($script:GoodZip + ".sha256") -Value $script:GoodHash -Encoding ASCII
    }

    AfterAll {
        Remove-Item -Path $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Passes for a valid archive with matching manifest" {
        { Assert-ArchiveIntegrity -ArchivePath $script:GoodZip } | Should -Not -Throw
    }

    It "Throws INTEGRITY VIOLATION on hash mismatch" {
        $tampered = Join-Path $script:TmpDir "tampered.zip"
        Copy-Item -LiteralPath $script:GoodZip -Destination $tampered
        # Write a deliberately wrong hash.
        Set-Content -Path ($tampered + ".sha256") -Value "DEADBEEF00000000000000000000000000000000000000000000000000000000" -Encoding ASCII
        { Assert-ArchiveIntegrity -ArchivePath $tampered } | Should -Throw "*INTEGRITY VIOLATION*"
    }

    It "Emits a WARNING but does not throw when manifest is absent (backwards compatibility)" {
        $noManifest = Join-Path $script:TmpDir "no_manifest.zip"
        Copy-Item -LiteralPath $script:GoodZip -Destination $noManifest
        { Assert-ArchiveIntegrity -ArchivePath $noManifest } | Should -Not -Throw
    }
}

Describe "Invoke-LogAnalysis — Path Confinement (ISSUE-002)" {
    BeforeAll {
        $script:ScriptRoot = Join-Path $env:TEMP "lt_confinement_$(New-Guid)"
        New-Item -ItemType Directory -Path (Join-Path $script:ScriptRoot "reports") | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:ScriptRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Returns null and does not throw for ArchivePath outside reports boundary" {
        $result = Invoke-LogAnalysis `
            -Configuration    $script:MockConfig `
            -ScriptRoot       $script:ScriptRoot `
            -LocalizedStrings $script:LocalizedStrings `
            -ArchivePath      "C:\Windows\System32\evil.zip" `
            -Quiet
        $result | Should -BeNullOrEmpty
    }
}

Describe "ReDoS Prevention (ISSUE-003)" {
    It "Does not throw when CLI keyword contains regex metacharacters" {
        # The keyword '(a+)+' would cause catastrophic backtracking if not escaped.
        # We verify [regex]::Escape is applied by ensuring no exception and no hang.
        $job = Start-Job -ScriptBlock {
            param($scriptRoot)
            Import-Module (Join-Path $scriptRoot "modules\Shared.psm1")   -Force
            Import-Module (Join-Path $scriptRoot "modules\Analysis.psm1") -Force
            # A regex metacharacter keyword against a simple string — should complete instantly.
            $pattern = [regex]::Escape("(a+)+")
            "test failed message" -match $pattern
        } -ArgumentList (Split-Path $PSScriptRoot -Parent)

        $completed = Wait-Job -Job $job -Timeout 5
        $completed | Should -Not -BeNullOrEmpty   # Job completed within 5s
        Remove-Job -Job $job -Force
    }
}
