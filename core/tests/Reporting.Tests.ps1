#
# Test Suite: Reporting.psm1
# Framework: Pester 5.x
# Coverage: HTML output correctness, XSS encoding, LanguageCode, no inline handlers, no CDN import
#

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "..\modules\Shared.psm1")     -Force
    Import-Module (Join-Path $PSScriptRoot "..\modules\Reporting.psm1")  -Force

    $script:Strings = Get-LocalizedStrings -Language "en-US"

    $script:MockResult = [PSCustomObject]@{
        ArchiveName      = "test_archive.zip"
        TotalEvents      = 3
        AnalysisPeriod   = "2026-01-01 to 2026-01-02"
        VerdictById      = "STABLE SYSTEM"
        VerdictByKeyword = "No suspicious keywords found"
        CriticalEvents   = @()
        KeywordEvents    = @()
    }
}

Describe "Invoke-HtmlReport" {
    It "Produces non-empty HTML output" {
        $html = Invoke-HtmlReport -ReportData $script:MockResult -LocalizedStrings $script:Strings
        $html | Should -Not -BeNullOrEmpty
    }

    It "Emits correct lang attribute from LanguageCode (ISSUE-004)" {
        $html = Invoke-HtmlReport -ReportData $script:MockResult -LocalizedStrings $script:Strings
        $html | Should -Match '<html lang="en">'
    }

    It "Does NOT contain Google Fonts CDN import (ISSUE-005)" {
        $html = Invoke-HtmlReport -ReportData $script:MockResult -LocalizedStrings $script:Strings
        $html | Should -Not -Match 'fonts\.googleapis\.com'
    }

    It "Does NOT contain inline onkeyup handlers (ISSUE-006)" {
        $html = Invoke-HtmlReport -ReportData $script:MockResult -LocalizedStrings $script:Strings
        $html | Should -Not -Match 'onkeyup='
    }

    It "HtmlEncodes the archive name to prevent XSS" {
        $xssResult = $script:MockResult.PSObject.Copy()
        $xssResult.ArchiveName = '<script>alert(1)</script>.zip'
        $html = Invoke-HtmlReport -ReportData $xssResult -LocalizedStrings $script:Strings
        $html | Should -Not -Match '<script>alert'
        $html | Should -Match '&lt;script&gt;'
    }

    It "Contains addEventListener wiring for filter inputs (CSP-safe)" {
        $html = Invoke-HtmlReport -ReportData $script:MockResult -LocalizedStrings $script:Strings
        $html | Should -Match "addEventListener\('keyup'"
    }
}

Describe "Show-ConsoleReport (migrated from Analysis.psm1 — ISSUE-010)" {
    It "Is exported by Reporting.psm1 — not Analysis.psm1" {
        $reportingCommands = Get-Module Reporting | Select-Object -ExpandProperty ExportedCommands
        $reportingCommands.Keys | Should -Contain "Show-ConsoleReport"
    }

    It "Executes without throwing for a valid result object" {
        $config = [pscustomobject]@{
            AnalysisConfig = @{ MaxDetailItems = 5 }
        }
        { Show-ConsoleReport -Result $script:MockResult -Configuration $config -LocalizedStrings $script:Strings } |
            Should -Not -Throw
    }
}
