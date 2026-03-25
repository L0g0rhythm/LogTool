#
# Test Suite: Collection.psm1
# Framework: Pester 5.x
# Coverage: SHA-256 manifest generation, LastWriteTime-based lifecycle
#

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "..\modules\Shared.psm1")     -Force
    Import-Module (Join-Path $PSScriptRoot "..\modules\Collection.psm1") -Force

    $script:TmpDir     = Join-Path $env:TEMP "lt_collection_test_$(New-Guid)"
    $script:MockConfig = [pscustomobject]@{
        AuditLogPath    = Join-Path $script:TmpDir "audit.log"
        LifecycleConfig = @{ Enabled = $true; MaxArchiveAgeDays = 30; MaxArchivesToKeep = 50 }
    }
    New-Item -ItemType Directory -Path $script:TmpDir | Out-Null
    Set-Content -Path $script:MockConfig.AuditLogPath -Value "" -Encoding ASCII
}

AfterAll {
    Remove-Item -Path $script:TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "New-ArchiveManifest (SHA-256 integrity)" {
    It "Creates a .sha256 sidecar file alongside the archive" {
        $archivePath = Join-Path $script:TmpDir "test_archive.zip"
        Compress-Archive -Path $PSScriptRoot -DestinationPath $archivePath -Force

        # Invoke private function via module scope
        & (Get-Module Collection) { New-ArchiveManifest -ArchivePath $using:archivePath -Configuration $using:script:MockConfig }

        Test-Path -LiteralPath ($archivePath + ".sha256") | Should -BeTrue
    }

    It "Manifest contains a valid 64-char SHA-256 hex string" {
        $archivePath = Join-Path $script:TmpDir "test_archive.zip"
        $manifest    = Get-Content -LiteralPath ($archivePath + ".sha256")
        $manifest    | Should -Match '^[A-Fa-f0-9]{64}$'
    }
}

Describe "Invoke-ArchiveCleanup — LastWriteTime (ISSUE-012)" {
    It "Deletes archives whose LastWriteTime exceeds MaxArchiveAgeDays" {
        $reportsDir = Join-Path $script:TmpDir "reports"
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null

        $oldArchive = Join-Path $reportsDir "old.zip"
        Set-Content -Path $oldArchive -Value "x" -Encoding ASCII
        # Simulate a 60-day-old file via LastWriteTime.
        (Get-Item $oldArchive).LastWriteTime = (Get-Date).AddDays(-60)

        $config = [pscustomobject]@{
            AuditLogPath    = $script:MockConfig.AuditLogPath
            LifecycleConfig = @{ Enabled = $true; MaxArchiveAgeDays = 30; MaxArchivesToKeep = 50 }
        }
        $strings = Get-LocalizedStrings -Language "en-US"

        Invoke-ArchiveCleanup -Configuration $config -ScriptRoot $script:TmpDir -LocalizedStrings $strings

        Test-Path -LiteralPath $oldArchive | Should -BeFalse
    }

    It "Preserves archives within the retention window" {
        $reportsDir  = Join-Path $script:TmpDir "reports"
        $newArchive  = Join-Path $reportsDir "recent.zip"
        Set-Content -Path $newArchive -Value "x" -Encoding ASCII
        (Get-Item $newArchive).LastWriteTime = (Get-Date).AddDays(-5)

        $config = [pscustomobject]@{
            AuditLogPath    = $script:MockConfig.AuditLogPath
            LifecycleConfig = @{ Enabled = $true; MaxArchiveAgeDays = 30; MaxArchivesToKeep = 50 }
        }
        $strings = Get-LocalizedStrings -Language "en-US"

        Invoke-ArchiveCleanup -Configuration $config -ScriptRoot $script:TmpDir -LocalizedStrings $strings

        Test-Path -LiteralPath $newArchive | Should -BeTrue
    }
}
