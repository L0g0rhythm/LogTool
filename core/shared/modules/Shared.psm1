#
# Module: Shared.psm1 v28.2.0 (SSOT Hardened + Audit Sprint)
#

# Session-scoped correlation ID for forensic traceability (M22 compliance).
$script:CorrelationId = [guid]::NewGuid().ToString('N')

function Get-LocalizedString {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Language)
    # i18n Dictionary for multi-language support (M28 compliance).
    $strings = @{
        "en-US" = @{ 
            ToolTitle = "LogTool Professional"; 
            LogCollection = "LOG COLLECTION"; 
            CollectingLog = "Collecting {0}"; 
            ArchivingLogs = "Archiving..."; 
            CollectionComplete = "Complete."; 
            ArchiveSavedTo = "Saved: {0}"; 
            RunningCleanup = "Cleanup..."; 
            DeletingOldByAge = "Deleting (>{0}d): {1}";
            DeletingOldByCount = "Deleting {1}";
            DetailsButtonView = "View";
            DetailsButtonHide = "Hide";
            ReportTitle = "LogTool Diagnostic Report";
            AnalyzedArchiveLabel = "Analyzed Archive:";
            ReportGeneratedLabel = "Generated:";
            ExecutiveSummary = "Executive Summary";
            VerdictById = "Verdict (by Event ID)";
            VerdictByKeyword = "Verdict (by Keyword)";
            CriticalEventDetails = "Critical Event Details";
            KeywordAlertDetails = "Keyword Alert Details";
            FilterCriticalEvents = "Filter critical events...";
            FilterKeywordEvents = "Filter keyword events...";
            NoCriticalEvents = "No critical events found.";
            NoKeywordEventsFound = "No keyword matches found.";
            FooterCopyright = "LogTool v28.2.0 | Audit by";
            DiagnosticReport = "DIAGNOSTIC REPORT";
            AvailableArchives = "Available Archives:";
            EnterArchiveNumber = "Enter archive number (or 'q' to quit):";
            AnalysisCancelled = "Analysis cancelled.";
            InvalidSelection = "Invalid selection.";
            AnalyzingArchive = "ANALYZING ARCHIVE";
            TargetArchive = "Target: {0}";
            NoEventsLoaded = "No events were loaded for analysis.";
            AnalyzingEvents = "Analyzing {0} events...";
            AnalysisComplete = "Analysis complete.";
            VerdictCritical = "ATTENTION REQUIRED (Critical IDs Found)";
            VerdictStable = "STABLE (No Critical IDs Found)";
            VerdictKeyword = "ATTENTION REQUIRED (Keywords Found)";
            VerdictNoKeyword = "STABLE (No Keywords Found)";
        }
        "pt-BR" = @{ 
            ToolTitle = "LogTool Profissional"; 
            LogCollection = "COLETA DE LOGS"; 
            CollectingLog = "Coletando {0}"; 
            ArchivingLogs = "Arquivando..."; 
            CollectionComplete = "Sucesso."; 
            ArchiveSavedTo = "Salvo: {0}"; 
            RunningCleanup = "Limpeza..."; 
            DeletingOldByAge = "Apagando (>{0}d): {1}";
            DeletingOldByCount = "Apagando {1}";
            DetailsButtonView = "Ver";
            DetailsButtonHide = "Ocultar";
            ReportTitle = "Relatorio de Diagnostico LogTool";
            AnalyzedArchiveLabel = "Arquivo Analisado:";
            ReportGeneratedLabel = "Gerado em:";
            ExecutiveSummary = "Sumario Executivo";
            VerdictById = "Veredito (por ID)";
            VerdictByKeyword = "Veredito (por Palavra-chave)";
            CriticalEventDetails = "Detalhes de Eventos Criticos";
            KeywordAlertDetails = "Detalhes de Alertas de Palavras-chave";
            FilterCriticalEvents = "Filtrar eventos criticos...";
            FilterKeywordEvents = "Filtrar palavras-chave...";
            NoCriticalEvents = "Nenhum evento critico encontrado.";
            NoKeywordEventsFound = "Nenhuma palavra-chave encontrada.";
            FooterCopyright = "LogTool v28.2.0 | Auditoria por";
            DiagnosticReport = "RELATORIO DE DIAGNOSTICO";
            AvailableArchives = "Arquivos Disponiveis:";
            EnterArchiveNumber = "Digite o numero do arquivo (ou 'q' para sair):";
            AnalysisCancelled = "Analise cancelada.";
            InvalidSelection = "Selecao invalida.";
            AnalyzingArchive = "ANALISANDO ARQUIVO";
            TargetArchive = "Alvo: {0}";
            NoEventsLoaded = "Nenhum evento foi carregado para analise.";
            AnalyzingEvents = "Analisando {0} eventos...";
            AnalysisComplete = "Analise concluida.";
            VerdictCritical = "ATENCAO REQUERIDA (IDs Criticos Encontrados)";
            VerdictStable = "ESTAVEL (Nenhum ID Critico Encontrado)";
            VerdictKeyword = "ATENCAO REQUERIDA (Palavras-chave Encontradas)";
            VerdictNoKeyword = "ESTAVEL (Nenhuma Palavra-chave Encontrada)";
        }
    }
    if ($strings.ContainsKey($Language)) { return $strings[$Language] }
    return $strings["en-US"]
}

function Write-Status {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param([string]$Message, [string]$Level = "INFO", [int]$Indent = 0)
    # Use curated color palette to ensure high visibility and professional aesthetics.
    $c = switch($Level) { 
        "SUCCESS"{"Green"} 
        "WARN"{"Yellow"} 
        "ERROR"{"Red"} 
        default{"Cyan"} 
    }
    $spaces = "  " * $Indent
    Write-Host "$spaces[*] $Message" -ForegroundColor $c
}

function Write-SectionHeader {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param([string]$Title)
    # Blue background highlights major operation boundaries for improved UX.
    Write-Host "`n=== $Title ===`n" -ForegroundColor White -BackgroundColor Blue
}

function Resolve-SafePathPart {
    [CmdletBinding()]
    param([string]$PathPart)
    # Sanitization ensures filesystem compatibility by removing illegal characters.
    return $PathPart -replace '[\\/:*?"<>|]', '_'
}

function Assert-PathWithinBoundary {
    [CmdletBinding()]
    param([string]$TargetPath, [string]$AllowedRoot, [string]$ParameterName)
    # Security Confinement: Prevents Path Traversal by resolving and validating target root.
    $resolved = (Resolve-Path -LiteralPath $TargetPath -ErrorAction Stop).Path
    if (-not $resolved.StartsWith($AllowedRoot, [System.StringComparison]::InvariantCultureIgnoreCase)) {
        throw "SECURITY VIOLATION: $ParameterName is outside boundary."
    }
    return $resolved
}

function Write-AuditLog {
    [CmdletBinding()]
    param([string]$Message, $Configuration, [string]$Level = "INFO")
    # RFC 3339 formatted logs with correlation_id enable deterministic forensic trace reconstruction.
    try {
        $logPath = $Configuration.AuditLogPath
        # Rotation gate: rotate at 10MB to prevent unbounded growth (M22 compliance).
        if ((Test-Path $logPath) -and ((Get-Item $logPath).Length -gt 10MB)) {
            $rotatedPath = $logPath + '.old'
            Move-Item -Path $logPath -Destination $rotatedPath -Force -ErrorAction SilentlyContinue
        }
        $entry = @{
            t   = (Get-Date -Format 'o')
            m   = $Message
            l   = $Level
            cid = $script:CorrelationId
            h   = $env:COMPUTERNAME
            pid = $PID
        } | ConvertTo-Json -Compress
        Add-Content -Path $logPath -Value $entry -ErrorAction Stop
    }
    catch {
        Write-Status -Level ERROR -Message "AUDIT FAILURE: Could not write to '$($Configuration.AuditLogPath)'. Error: $($_.Exception.Message)"
    }
}

function Initialize-SystemEnvironment {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ScriptRoot)
    # ISSUE-008 FIX: Purge rogue root config FIRST — before any module can read it.
    $rootConfig = Join-Path -Path $ScriptRoot -ChildPath "config.psd1"
    if (Test-Path $rootConfig) {
        Remove-Item $rootConfig -Force
        Write-Status -Level WARN -Message "Insecure root config.psd1 removed to enforce SSOT."
    }

    $reportsDir = Join-Path -Path $ScriptRoot -ChildPath "reports"
    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
        Write-Status -Level INFO -Message "Created missing reports directory."
    }

    # ISSUE-011 FIX: Ensure audit log directory exists to prevent Write-AuditLog failures.
    $logsDir = Join-Path -Path $ScriptRoot -ChildPath "core\logs"
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        Write-Status -Level INFO -Message "Created missing logs directory."
    }
}

function Get-ToolConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ScriptRoot)
    # SSOT: Configuration MUST reside in 'core\config.psd1' for architectural purity.
    $configPath = Join-Path -Path $ScriptRoot -ChildPath "core\config.psd1"
    if (-not (Test-Path $configPath)) {
        throw "CRITICAL: Configuration file not found at '$configPath'."
    }
    $config = Import-PowerShellDataFile -Path $configPath
    
    # Inject AuditLog path dynamically for portability across different host environments.
    $config | Add-Member -MemberType NoteProperty -Name 'AuditLogPath' -Value (Join-Path -Path $ScriptRoot -ChildPath "core\logs\audit.jsonl") -Force
    
    return $config
}

Export-ModuleMember -Function Get-LocalizedString, Write-Status, Write-SectionHeader, Resolve-SafePathPart, Assert-PathWithinBoundary, Write-AuditLog, Initialize-SystemEnvironment, Get-ToolConfiguration



