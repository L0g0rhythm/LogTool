#
# Module: Shared.psm1 v26.2 (International Edition, Refined)
# Description: Contains shared utilities, now with a localization engine.
# Author: L0g0rhythm
#

#region Core Functions

function Get-LocalizedStrings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Language
    )

    $strings = @{
        "en-US" = @{
            # General
            InvalidSelection = "Invalid selection."
            InvalidInput = "Invalid input. Please enter a number."
            AnalysisCancelled = "Analysis cancelled."
            # Headers
            LogCollection = "LOG COLLECTION"
            AnalyzingArchive = "ANALYZING ARCHIVE"
            DiagnosticReport = "DIAGNOSTIC REPORT"
            # Status Messages
            ToolTitle = "A Professional Log Analysis Toolkit"
            ConfigNotFound = "Configuration file 'config.psd1' not found. Creating a default one."
            AvailableArchives = "Available Log Archives to Analyze:"
            EnterArchiveNumber = "[>] Enter the number of the archive to analyze (or 'q' to quit)"
            TargetArchive = "Target: {0}"
            AnalyzingEvents = "Analyzing {0} events with an optimized engine..."
            AnalysisComplete = "Analysis complete."
            NoEventsLoaded = "No valid events were loaded from the archive. Cannot generate a report."
            NoCriticalEvents = "No events from the 'CriticalEventIds' list were found."
            CollectingLog = "Collecting {0}"
            ArchivingLogs = "Archiving and securing collected logs..."
            CollectionComplete = "Log collection complete."
            ArchiveSavedTo = "Archive saved to: {0}"
            RunningCleanup = "Running archive cleanup..."
            DeletingOldByAge = "Deleting old archive (age > {0} days): {1}"
            DeletingOldByCount = "Deleting old archive (quantity > {0}): {1}"
            # Report Strings
            ReportTitle = "LogTool Diagnostic Report"
            AnalyzedArchiveLabel = "Analyzed Archive:"
            ReportGeneratedLabel = "Report Generated:"
            ExecutiveSummary = "Executive Summary"
            VerdictById = "Verdict (by ID):"
            VerdictByKeyword = "Verdict (by Keyword):"
            CriticalEventDetails = "Critical Event Details"
            KeywordAlertDetails = "Keyword Alert Details"
            DetailsButtonView = "View Details"
            DetailsButtonHide = "Hide Details"
            FilterCriticalEvents = "Filter critical events..."
            FilterKeywordEvents = "Filter keyword events..."
            NoKeywordEventsFound = "No events with suspicious keywords were found."
            ToolCreator = "Created by:"
            # Verdicts
            VerdictCritical = "ATTENTION: CRITICAL EVENTS DETECTED"
            VerdictStable = "STABLE SYSTEM"
            VerdictKeyword = "ATTENTION: SUSPICIOUS KEYWORDS FOUND"
            VerdictNoKeyword = "No suspicious keywords found"
        }
        "pt-BR" = @{
            # General
            InvalidSelection = "Seleção inválida."
            InvalidInput = "Entrada inválida. Por favor, insira um número."
            AnalysisCancelled = "Análise cancelada."
            # Headers
            LogCollection = "COLETA DE LOGS"
            AnalyzingArchive = "ANALISANDO ARQUIVO"
            DiagnosticReport = "RELATÓRIO DE DIAGNÓSTICO"
            # Status Messages
            ToolTitle = "Uma Ferramenta Profissional de Análise de Logs"
            ConfigNotFound = "Ficheiro de configuração 'config.psd1' não encontrado. A criar um por defeito."
            AvailableArchives = "Arquivos de Log Disponíveis para Análise:"
            EnterArchiveNumber = "[>] Insira o número do arquivo para analisar (ou 'q' para sair)"
            TargetArchive = "Alvo: {0}"
            AnalyzingEvents = "Analisando {0} eventos com o motor otimizado..."
            AnalysisComplete = "Análise completa."
            NoEventsLoaded = "Nenhum evento válido foi carregado do arquivo. Não é possível gerar um relatório."
            NoCriticalEvents = "Nenhum evento da lista 'CriticalEventIds' foi encontrado."
            CollectingLog = "Coletando {0}"
            ArchivingLogs = "Arquivando e protegendo os logs coletados..."
            CollectionComplete = "Coleta de logs completa."
            ArchiveSavedTo = "Arquivo salvo em: {0}"
            RunningCleanup = "Executando a limpeza de arquivos..."
            DeletingOldByAge = "Apagando arquivo antigo (idade > {0} dias): {1}"
            DeletingOldByCount = "Apagando arquivo antigo (quantidade > {0}): {1}"
            # Report Strings
            ReportTitle = "Relatório de Diagnóstico LogTool"
            AnalyzedArchiveLabel = "Arquivo Analisado:"
            ReportGeneratedLabel = "Relatório Gerado:"
            ExecutiveSummary = "Sumário Executivo"
            VerdictById = "Veredito (por ID):"
            VerdictByKeyword = "Veredito (por Palavra-Chave):"
            CriticalEventDetails = "Detalhes dos Eventos Críticos"
            KeywordAlertDetails = "Alertas por Palavra-Chave"
            DetailsButtonView = "Ver Detalhes"
            DetailsButtonHide = "Ocultar Detalhes"
            FilterCriticalEvents = "Filtrar eventos críticos..."
            FilterKeywordEvents = "Filtrar eventos por palavra-chave..."
            NoKeywordEventsFound = "Nenhum evento com palavras-chave suspeitas foi encontrado."
            ToolCreator = "Criado por:"
            # Verdicts
            VerdictCritical = "ATENÇÃO: EVENTOS CRÍTICOS DETETADOS"
            VerdictStable = "SISTEMA ESTÁVEL"
            VerdictKeyword = "ATENÇÃO: PALAVRAS-CHAVE SUSPEITAS ENCONTRADAS"
            VerdictNoKeyword = "Nenhuma palavra-chave suspeita encontrada"
        }
    }

    # Fallback to English if the selected language is not found
    if (-not $strings.ContainsKey($Language)) {
        return $strings["en-US"]
    }
    return $strings[$Language]
}

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")][string]$Level = "INFO",
        [int]$Indent = 2
    )
    $prefix = switch ($Level) {
        "SUCCESS" { "[✔]" }
        "WARN"    { "[!]" }
        "ERROR"   { "[✘]" }
        default   { "[*]" }
    }
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        default   { "Cyan" }
    }
    Write-Host (" " * $Indent + $prefix + " " + $Message) -ForegroundColor $color
}

function Get-ToolConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )

    $logDirectory = Join-Path -Path $ScriptRoot -ChildPath "logs"
    if (-not (Test-Path $logDirectory)) {
        try {
            New-Item -ItemType Directory -Path $logDirectory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error "Failed to create log directory at '$logDirectory'. Please check permissions."
            throw
        }
    }

    $configPath = Join-Path -Path $ScriptRoot -ChildPath "config.psd1"

    if (-not (Test-Path $configPath)) {
        # REFACTOR: Use the standardized Write-Status function for UI consistency.
        $tempStrings = Get-LocalizedStrings -Language 'en-US' # Use default for this one-time message
        Write-Status -Level INFO -Message $tempStrings.ConfigNotFound

        $defaultConfigString = @'
# Default configuration file for LogTool
@{
    ToolSettings = @{
        Language = "en-US"
    }
    CollectionTasks = @(
        @{ LogName = "Security"; MaxEvents = 10000; Filter = @{ ID = 4625, 4624, 4720, 4722, 4724, 4725, 4726, 4732 } },
        @{ LogName = "Application"; MaxEvents = 5000; Filter = @{ Level = 1, 2 } },
        @{ LogName = "System"; MaxEvents = 5000; Filter = @{ ProviderName = "EventLog", "VSS"; ID = 6008, 1074 } },
        @{ LogName = "Windows PowerShell"; MaxEvents = 2000; Filter = $null }
    )
    AnalysisConfig = @{
        CriticalEventIds = @( 4625, 4720, 4726, 4732, 6008, 1000 )
        KeywordsToFlag   = @( "failed", "denied", "exception", "critical", "corrupt" )
        MaxDetailItems   = 15
    }
    LifecycleConfig = @{
        Enabled           = $true
        MaxArchiveAgeDays = 30
        MaxArchivesToKeep = 50
    }
}
'@
        try {
            $defaultConfigString | Set-Content -Path $configPath -Encoding UTF8 -ErrorAction Stop
        } catch {
            throw "FATAL: Failed to create default configuration file at '$configPath'. Please check permissions."
        }
    }

    $config = $null
    try {
        $config = Import-PowerShellDataFile -Path $configPath
    }
    catch {
        throw "FATAL: The configuration file '$configPath' is corrupt or cannot be read. Please delete it and run the script again. Error: $($_.Exception.Message)"
    }

    if ($null -eq $config) {
        throw "FATAL: The configuration file '$configPath' is empty. Please delete it and run the script again."
    }

    $config.AuditLogPath = Join-Path -Path $logDirectory -ChildPath "collector_audit.log"
    return $config
}

function Resolve-SafePathPart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathPart
    )
    $invalidCharsRegex = '[\\/:*?"<>|]'
    $sanitized = $PathPart -replace $invalidCharsRegex, '_'
    $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
    if ($reservedNames -contains $sanitized.ToUpper()) {
        return "_$sanitized"
    }
    return $sanitized
}

function Write-AuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$true)]$Configuration,
        [ValidateSet("INFO", "WARN", "ERROR", "HEADER")][string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($Level -eq 'HEADER') { $logEntry = "`n" + $Message }
    else { $logEntry = "[$timestamp] [$Level] - $Message" }

    try {
        Add-Content -Path $Configuration.AuditLogPath -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Error "CRITICAL: Failed to write to audit log file '$($Configuration.AuditLogPath)'. Error: $($_.Exception.Message)"
    }
}

#endregion

#region UI and Formatting Functions

function Show-ToolHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]$LocalizedStrings
    )
    Clear-Host
    $titleColor = "Cyan"
    $logoColor = "Green"
    $logoPath = Join-Path -Path $PSScriptRoot -ChildPath '..\assets\logo.txt'
    if (Test-Path $logoPath) {
        $logo = Get-Content -Path $logoPath -Raw
        Write-Host $logo -ForegroundColor $logoColor
    }
    Write-Host (" " * 12 + $LocalizedStrings.ToolTitle) -ForegroundColor $titleColor
    Write-Host ""
}

function Write-SectionHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Title
    )
    $formattedTitle = "  $($Title.ToUpper())  "
    $border = "═" * ($formattedTitle.Length)
    Write-Host "`n╔$border╗"
    Write-Host "║$formattedTitle║"
    Write-Host "╚$border╝`n"
}

#endregion

Export-ModuleMember -Function Get-ToolConfiguration, Get-LocalizedStrings, Resolve-SafePathPart, Write-AuditLog, Show-ToolHeader, Write-Status, Write-SectionHeader
