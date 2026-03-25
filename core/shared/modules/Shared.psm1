#
# Module: Shared.psm1 v28.0 (AEGIS APEX Hardened)
# Description: Shared utilities — localization engine, JSON-structured audit log,
#              path confinement helper, and UI primitives.
# Author: L0g0rhythm
#

#region Localization Engine

function Get-LocalizedStrings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Language
    )

    $strings = @{
        "en-US" = @{
            # ISSUE-004 FIX: LanguageCode key added to both locales.
            LanguageCode = "en"
            # General
            InvalidSelection  = "Invalid selection."
            InvalidInput      = "Invalid input. Please enter a number."
            AnalysisCancelled = "Analysis cancelled."
            # Headers
            LogCollection    = "LOG COLLECTION"
            AnalyzingArchive = "ANALYZING ARCHIVE"
            DiagnosticReport = "DIAGNOSTIC REPORT"
            # Status Messages
            ToolTitle          = "A Professional Log Analysis Toolkit"
            ConfigNotFound     = "Configuration file 'config.psd1' not found. Creating a default one."
            AvailableArchives  = "Available Log Archives to Analyze:"
            EnterArchiveNumber = "[>] Enter the number of the archive to analyze (or 'q' to quit)"
            TargetArchive      = "Target: {0}"
            AnalyzingEvents    = "Analyzing {0} events with an optimized engine..."
            AnalysisComplete   = "Analysis complete."
            NoEventsLoaded     = "No valid events were loaded from the archive. Cannot generate a report."
            NoCriticalEvents   = "No events from the 'CriticalEventIds' list were found."
            CollectingLog      = "Collecting {0}"
            ArchivingLogs      = "Archiving and securing collected logs..."
            CollectionComplete = "Log collection complete."
            ArchiveSavedTo     = "Archive saved to: {0}"
            RunningCleanup     = "Running archive cleanup..."
            DeletingOldByAge   = "Deleting old archive (age > {0} days): {1}"
            DeletingOldByCount = "Deleting old archive (quantity > {0}): {1}"
            # Report Strings
            ReportTitle           = "LogTool Diagnostic Report"
            AnalyzedArchiveLabel  = "Analyzed Archive:"
            ReportGeneratedLabel  = "Report Generated:"
            ExecutiveSummary      = "Executive Summary"
            VerdictById           = "Verdict (by ID):"
            VerdictByKeyword      = "Verdict (by Keyword):"
            CriticalEventDetails  = "Critical Event Details"
            KeywordAlertDetails   = "Keyword Alert Details"
            DetailsButtonView     = "View Details"
            DetailsButtonHide     = "Hide Details"
            FilterCriticalEvents  = "Filter critical events..."
            FilterKeywordEvents   = "Filter keyword events..."
            NoKeywordEventsFound  = "No events with suspicious keywords were found."
            ToolCreator           = "Created by:"
            # Verdicts
            VerdictCritical  = "ATTENTION: CRITICAL EVENTS DETECTED"
            VerdictStable    = "STABLE SYSTEM"
            VerdictKeyword   = "ATTENTION: SUSPICIOUS KEYWORDS FOUND"
            VerdictNoKeyword = "No suspicious keywords found"
        }
        "pt-BR" = @{
            LanguageCode = "pt-BR"
            # General
            InvalidSelection  = "Selecao invalida."
            InvalidInput      = "Entrada invalida. Por favor, insira um numero."
            AnalysisCancelled = "Analise cancelada."
            # Headers
            LogCollection    = "COLETA DE LOGS"
            AnalyzingArchive = "ANALISANDO ARQUIVO"
            DiagnosticReport = "RELATORIO DE DIAGNOSTICO"
            # Status Messages
            ToolTitle          = "Uma Ferramenta Profissional de Analise de Logs"
            ConfigNotFound     = "Ficheiro de configuracao 'config.psd1' nao encontrado. A criar um por defeito."
            AvailableArchives  = "Arquivos de Log Disponiveis para Analise:"
            EnterArchiveNumber = "[>] Insira o numero do arquivo para analisar (ou 'q' para sair)"
            TargetArchive      = "Alvo: {0}"
            AnalyzingEvents    = "Analisando {0} eventos com o motor otimizado..."
            AnalysisComplete   = "Analise completa."
            NoEventsLoaded     = "Nenhum evento valido foi carregado do arquivo. Nao e possivel gerar um relatorio."
            NoCriticalEvents   = "Nenhum evento da lista 'CriticalEventIds' foi encontrado."
            CollectingLog      = "Coletando {0}"
            ArchivingLogs      = "Arquivando e protegendo os logs coletados..."
            CollectionComplete = "Coleta de logs completa."
            ArchiveSavedTo     = "Arquivo salvo em: {0}"
            RunningCleanup     = "Executando a limpeza de arquivos..."
            DeletingOldByAge   = "Apagando arquivo antigo (idade > {0} dias): {1}"
            DeletingOldByCount = "Apagando arquivo antigo (quantidade > {0}): {1}"
            # Report Strings
            ReportTitle           = "Relatorio de Diagnostico LogTool"
            AnalyzedArchiveLabel  = "Arquivo Analisado:"
            ReportGeneratedLabel  = "Relatorio Gerado:"
            ExecutiveSummary      = "Sumario Executivo"
            VerdictById           = "Veredito (por ID):"
            VerdictByKeyword      = "Veredito (por Palavra-Chave):"
            CriticalEventDetails  = "Detalhes dos Eventos Criticos"
            KeywordAlertDetails   = "Alertas por Palavra-Chave"
            DetailsButtonView     = "Ver Detalhes"
            DetailsButtonHide     = "Ocultar Detalhes"
            FilterCriticalEvents  = "Filtrar eventos criticos..."
            FilterKeywordEvents   = "Filtrar eventos por palavra-chave..."
            NoKeywordEventsFound  = "Nenhum evento com palavras-chave suspeitas foi encontrado."
            ToolCreator           = "Criado por:"
            # Verdicts
            VerdictCritical  = "ATENCAO: EVENTOS CRITICOS DETETADOS"
            VerdictStable    = "SISTEMA ESTAVEL"
            VerdictKeyword   = "ATENCAO: PALAVRAS-CHAVE SUSPEITAS ENCONTRADAS"
            VerdictNoKeyword = "Nenhuma palavra-chave suspeita encontrada"
        }
    }

    # Fallback to English when the selected locale is not supported.
    if (-not $strings.ContainsKey($Language)) {
        return $strings["en-US"]
    }
    return $strings[$Language]
}

#endregion

#region Console UI Primitives

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")][string]$Level = "INFO",
        [int]$Indent = 2
    )
    $prefix = switch ($Level) {
        "SUCCESS" { "[OK]" }
        "WARN"    { "[!]" }
        "ERROR"   { "[X]" }
        default   { "[*]" }
    }
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Cyan" }
    }
    Write-Host ((" " * $Indent) + $prefix + " " + $Message) -ForegroundColor $color
}

function Show-ToolHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]$LocalizedStrings
    )
    Clear-Host
    $logoPath = Join-Path -Path $PSScriptRoot -ChildPath '..\assets\logo.txt'
    if (Test-Path $logoPath) {
        Write-Host (Get-Content -Path $logoPath -Raw) -ForegroundColor Green
    }
    Write-Host ((" " * 12) + $LocalizedStrings.ToolTitle) -ForegroundColor Cyan
    Write-Host ""
}

function Write-SectionHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title
    )
    $formattedTitle = "  $($Title.ToUpper())  "
    $border = "=" * ($formattedTitle.Length)
    Write-Host "`n+$border+"
    Write-Host "|$formattedTitle|"
    Write-Host "+$border+`n"
}

#endregion

#region Configuration

#region Public Functions

    # Isolated environment initialization (SRP+ / AUD-03).
    function Initialize-SystemEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ScriptRoot
    )

    $reportsDir = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }

    $configPath = Join-Path -Path $ScriptRoot -ChildPath "config.psd1"
    if (-not (Test-Path $configPath)) {
        $defaultConfig = @'
@{
    # Archival Lifecycle Policy
    LifecycleConfig = @{
        Enabled            = $true
        MaxArchiveAgeDays  = 30
        MaxArchivesToKeep  = 50
    }

    # Acquisition Parameters
    CollectionTasks = @(
        @{ LogName = "System";  MaxEvents = 1000; Filter = @{ Level = 1,2 } }
        @{ LogName = "Application"; MaxEvents = 1000; Filter = @{ Level = 1,2 } }
    )
    
    # Analysis Criteria
    AnalysisThresholds = @{
        CriticalEvents = @(41, 1074, 6005, 6006, 6008)
        Keywords       = @("fail", "error", "critical", "denied", "warning")
    }
}
'@
        Set-Content -Path $configPath -Value $defaultConfig -Encoding UTF8 -Force
    }
}

    # Sync configuration retrieval (Post-AUD-03 Architecture).
    function Get-ToolConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ScriptRoot
    )

    $configPath = Join-Path -Path $ScriptRoot -ChildPath "config.psd1"
    if (-not (Test-Path $configPath)) {
        throw "System configuration missing at '$configPath'. Run initialization first."
    }

    $Configuration = Import-PowerShellDataFile -Path $configPath
    
    $machineName = Resolve-SafePathPart -PathPart $env:COMPUTERNAME
    $userName    = Resolve-SafePathPart -PathPart $env:USERNAME
    $logDirectory = Join-Path -Path $ScriptRoot -ChildPath "docs\audit\$machineName\$userName"
    
    if (-not (Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $Configuration | Add-Member -MemberType NoteProperty -Name "AuditLogPath" -Value (Join-Path -Path $logDirectory -ChildPath "events.jsonl") -Force
    
    return $Configuration
}

#endregion

#region Security Helpers

function Resolve-SafePathPart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathPart
    )
    $invalidCharsRegex = '[\\/:*?"<>|]'
    $sanitized = $PathPart -replace $invalidCharsRegex, '_'
    $reservedNames = @(
        'CON', 'PRN', 'AUX', 'NUL',
        'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
        'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
    )
    if ($reservedNames -contains $sanitized.ToUpper()) {
        return "_$sanitized"
    }
    return $sanitized
}

function Assert-PathWithinBoundary {
    # Fail-Closed confinement prevents traversal attacks.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$AllowedRoot,
        [Parameter(Mandatory = $true)][string]$ParameterName
    )

    try {
        $resolved = (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
    }
    catch {
        throw "SECURITY: '$ParameterName' could not be resolved. Path: '$TargetPath'. Error: $($_.Exception.Message)"
    }

    if (-not $resolved.StartsWith($AllowedRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
        throw "SECURITY VIOLATION: '$ParameterName' ('$TargetPath') is outside the allowed boundary ('$AllowedRoot'). Aborted."
    }

    return $resolved
}

#endregion

#region Audit Logging

# Module-scoped correlation ID: one GUID per session for full log traceability.
$script:SessionCorrelationId = [System.Guid]::NewGuid().ToString()

function Write-AuditLog {
    # SIEM-ready structured JSON logging.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)]$Configuration,
        [ValidateSet("INFO", "WARN", "ERROR", "HEADER")][string]$Level = "INFO"
    )

    # HEADER entries are plain-text session delimiters for human readability in the log file.
    if ($Level -eq 'HEADER') {
        $logEntry = "`n" + $Message
    }
    else {
        # Structured JSON for SIEM ingest (Splunk, Elastic, Sentinel).
        $logEntry = [ordered]@{
            timestamp      = (Get-Date -Format 'o')       # ISO-8601 with timezone offset
            level          = $Level
            correlation_id = $script:SessionCorrelationId
            host           = $env:COMPUTERNAME
            message        = $Message
        } | ConvertTo-Json -Compress
    }

    try {
        # AUD-OBS-01: Auto-rotation if log exceeds 10MB to prevent disk inflation.
        if (Test-Path -LiteralPath $Configuration.AuditLogPath) {
            $logFile = Get-Item -LiteralPath $Configuration.AuditLogPath
            if ($logFile.Length -gt 10MB) {
                $oldPath = $Configuration.AuditLogPath + ".old"
                Move-Item -LiteralPath $Configuration.AuditLogPath -Destination $oldPath -Force -ErrorAction SilentlyContinue
            }
        }
        Add-Content -Path $Configuration.AuditLogPath -Value $logEntry -ErrorAction Stop
    }
    catch {
        # Non-silent: operator must know if audit logging is broken.
        Write-Status -Level WARN -Message "CRITICAL: Audit log write failed. Path: '$($Configuration.AuditLogPath)'. Error: $($_.Exception.Message)"
    }
}

#endregion

Export-ModuleMember -Function Initialize-SystemEnvironment, Get-ToolConfiguration, Get-LocalizedStrings, Assert-PathWithinBoundary, Write-AuditLog, Resolve-SafePathPart, Write-Status, Show-ToolHeader, Write-SectionHeader
