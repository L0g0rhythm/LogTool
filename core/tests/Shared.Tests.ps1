#
# Test Suite: Shared.psm1
# Framework: Pester 5.x
# Coverage: Assert-PathWithinBoundary, Get-LocalizedStrings, Write-AuditLog
#

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\modules\Shared.psm1"
    Import-Module $modulePath -Force
}

Describe "Assert-PathWithinBoundary" {
    BeforeAll {
        # Create a temp boundary directory with a safe child for positive tests.
        $script:BoundaryRoot = Join-Path -Path $env:TEMP -ChildPath "lt_test_boundary_$(New-Guid)"
        New-Item -ItemType Directory -Path $script:BoundaryRoot | Out-Null
        $script:SafeChild = Join-Path -Path $script:BoundaryRoot -ChildPath "safe_archive.zip"
        Set-Content -Path $script:SafeChild -Value "test" -Encoding ASCII
    }

    AfterAll {
        Remove-Item -Path $script:BoundaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Returns resolved path for a legitimate child path" {
        $result = Assert-PathWithinBoundary -TargetPath $script:SafeChild -AllowedRoot $script:BoundaryRoot -ParameterName "TestPath"
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match [regex]::Escape($script:BoundaryRoot)
    }

    It "Throws on path traversal attempt (../../)" {
        $traversalPath = Join-Path -Path $script:BoundaryRoot -ChildPath "..\..\Windows\System32\cmd.exe"
        { Assert-PathWithinBoundary -TargetPath $traversalPath -AllowedRoot $script:BoundaryRoot -ParameterName "ArchivePath" } |
            Should -Throw "*SECURITY VIOLATION*"
    }

    It "Throws for a path that does not exist" {
        { Assert-PathWithinBoundary -TargetPath "C:\nonexistent\path\archive.zip" -AllowedRoot $script:BoundaryRoot -ParameterName "ArchivePath" } |
            Should -Throw "*SECURITY*"
    }
}

Describe "Get-LocalizedStrings" {
    It "Returns en-US strings with LanguageCode = 'en'" {
        $strings = Get-LocalizedStrings -Language "en-US"
        $strings.LanguageCode | Should -Be "en"
        $strings.VerdictStable | Should -Not -BeNullOrEmpty
    }

    It "Returns pt-BR strings with LanguageCode = 'pt-BR'" {
        $strings = Get-LocalizedStrings -Language "pt-BR"
        $strings.LanguageCode | Should -Be "pt-BR"
    }

    It "Falls back to en-US for unsupported locale" {
        $strings = Get-LocalizedStrings -Language "xx-XX"
        $strings.LanguageCode | Should -Be "en"
    }

    It "LanguageCode key is never null or empty in any locale" {
        foreach ($lang in @("en-US", "pt-BR")) {
            $strings = Get-LocalizedStrings -Language $lang
            $strings.LanguageCode | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Write-AuditLog" {
    BeforeAll {
        $script:TempLogDir  = Join-Path -Path $env:TEMP -ChildPath "lt_auditlog_$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TempLogDir | Out-Null
        $script:MockConfig  = [pscustomobject]@{
            AuditLogPath = Join-Path -Path $script:TempLogDir -ChildPath "test_audit.log"
        }
    }

    AfterAll {
        Remove-Item -Path $script:TempLogDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Writes a valid JSON line for INFO level" {
        Write-AuditLog -Message "Test info message" -Configuration $script:MockConfig -Level INFO
        $line = Get-Content -Path $script:MockConfig.AuditLogPath | Select-Object -Last 1
        { $line | ConvertFrom-Json } | Should -Not -Throw
        ($line | ConvertFrom-Json).level | Should -Be "INFO"
    }

    It "Written JSON entry contains required SIEM fields" {
        Write-AuditLog -Message "SIEM field test" -Configuration $script:MockConfig -Level WARN
        $entry = Get-Content -Path $script:MockConfig.AuditLogPath | Select-Object -Last 1 | ConvertFrom-Json
        $entry.timestamp      | Should -Not -BeNullOrEmpty
        $entry.correlation_id | Should -Not -BeNullOrEmpty
        $entry.host           | Should -Not -BeNullOrEmpty
        $entry.message        | Should -Be "SIEM field test"
    }

    It "HEADER level writes plain text, not JSON" {
        Write-AuditLog -Message "=== SESSION START ===" -Configuration $script:MockConfig -Level HEADER
        $line = Get-Content -Path $script:MockConfig.AuditLogPath | Select-Object -Last 1
        { $line | ConvertFrom-Json } | Should -Throw
        $line | Should -Match "SESSION START"
    }

    It "All entries share the same correlation_id within a session" {
        Write-AuditLog -Message "msg1" -Configuration $script:MockConfig
        Write-AuditLog -Message "msg2" -Configuration $script:MockConfig
        $lines = Get-Content -Path $script:MockConfig.AuditLogPath |
            Where-Object { $_ -match '"level"' } |
            ForEach-Object { $_ | ConvertFrom-Json }
        $uniqueIds = $lines | Select-Object -ExpandProperty correlation_id -Unique
        $uniqueIds.Count | Should -Be 1
    }
}
