# Module: Reporting.psm1 v28.1.3 (AEGIS APEX Hardened)
# Description: Unified presentation engine for HTML interactive reports and console dashboards.
#              Migrated to Streaming I/O (AUD-PERF-02) for O(n) memory efficiency.
# Author: L0g0rhythm

#region Module Setup
Add-Type -AssemblyName System.Web
#endregion

#region Private: Assets

function Get-ReportCss {
    [CmdletBinding()]
    param()
    return @"
<style>
    :root {
        --font-serif: 'Georgia', serif;
        --font-mono: 'Courier New', monospace;
        --color-background: #ffffff;
        --color-text: #212529;
        --color-primary: #0a2b5e;
        --color-border: #dee2e6;
        --color-header-bg: #f1f3f5;
        --color-critical: #c92a2a;
        --color-keyword: #e67700;
        --color-subtle-bg: #f8f9fa;
    }
    body { font-family: var(--font-serif); background-color: #e9ecef; color: var(--color-text); margin: 0; padding: 1rem; line-height: 1.6; }
    .page { width: 210mm; min-height: 297mm; padding: 2cm; margin: 1cm auto; border: 1px solid #ccc; background: var(--color-background); box-shadow: 0 0 10px rgba(0, 0, 0, 0.15); box-sizing: border-box; }
    h1, h2 { color: var(--color-primary); font-weight: normal; margin-top: 1.5em; margin-bottom: 0.8em; border-bottom: 2px solid var(--color-primary); padding-bottom: 8px; }
    h1 { font-size: 26pt; }
    h2 { font-size: 18pt; border-bottom-width: 1px; }
    .report-header p { margin: 0.4em 0; font-size: 11pt; }
    .verdict-critical { color: var(--color-critical); font-weight: bold; }
    .verdict-keyword  { color: var(--color-keyword);  font-weight: bold; }
    .filter-input { width: 100%; padding: 8px 12px; margin-bottom: 1rem; border: 1px solid var(--color-border); border-radius: 4px; font-family: var(--font-mono); font-size: 10pt; box-sizing: border-box; }
    table { border-collapse: collapse; width: 100%; margin-top: 1rem; font-size: 9pt; }
    th, td { border: 1px solid var(--color-border); padding: 10px 14px; text-align: left; vertical-align: middle; }
    th { background-color: var(--color-header-bg); font-weight: bold; }
    td { font-family: var(--font-mono); }
    .details-row { display: none; background-color: var(--color-subtle-bg); }
    .details-row td { padding: 0; }
    .details-row pre { margin: 0; padding: 12px 16px; font-size: 8.5pt; white-space: pre-wrap; word-wrap: break-word; }
    .details-button { cursor: pointer; border: 1px solid var(--color-border); border-radius: 4px; padding: 2px 8px; font-size: 8pt; background: #fff; }
    .keyword-highlight { background-color: #ffe066; font-weight: bold; }
    .footer { text-align: center; margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--color-border); font-size: 9pt; color: #6c757d; }
    @media print {
        body { background: none; padding: 0; }
        .page { border: initial; margin: 0; box-shadow: initial; page-break-after: always; }
        .filter-input, .details-button { display: none; }
        .details-row { display: table-row !important; }
    }
</style>
"@
}

function Get-ReportJavaScript {
    [CmdletBinding()]
    param([hashtable]$LocalizedStrings)
    return @"
<script>
    function filterTable(inputId, tableId) {
        const input = document.getElementById(inputId);
        const filter = input.value.toUpperCase();
        const tbody = document.getElementById(tableId).getElementsByTagName('tbody')[0];
        const rows = tbody.getElementsByTagName('tr');
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].classList.contains('details-row')) continue;
            const visible = (rows[i].textContent || rows[i].innerText).toUpperCase().indexOf(filter) > -1;
            rows[i].style.display = visible ? '' : 'none';
            const next = rows[i].nextElementSibling;
            if (next && next.classList.contains('details-row')) next.style.display = 'none';
        }
    }
    document.addEventListener('DOMContentLoaded', () => {
        ['criticalFilter', 'keywordFilter'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.addEventListener('keyup', () => filterTable(id, id.replace('Filter', 'Table')));
        });
        document.body.addEventListener('click', e => {
            if (e.target.matches('.details-button')) {
                const btn = e.target;
                const details = btn.closest('tr').nextElementSibling;
                const vis = details.style.display === 'table-row';
                details.style.display = vis ? 'none' : 'table-row';
                btn.textContent = vis ? '$($LocalizedStrings.DetailsButtonView)' : '$($LocalizedStrings.DetailsButtonHide)';
            }
        });
    });
</script>
"@
}

#endregion

#region Public Functions

function Invoke-HtmlReport {
    # AUD-PERF-02: Generates HTML report using direct streaming to OutputPath.
    # Prevents OOM by avoiding giant string concatenation in PowerShell heap.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][psobject]$ReportData,
        [Parameter(Mandatory = $true)][hashtable]$LocalizedStrings,
        [Parameter(Mandatory = $false)][string]$OutputPath
    )

    $st = [System.IO.StreamWriter]::new($OutputPath, $false, [System.Text.Encoding]::UTF8)
    try {
        $st.AutoFlush = $true
        
        # HTML Header
        $st.WriteLine('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">')
        $st.WriteLine("<title>$($LocalizedStrings.ReportTitle)</title>")
        $st.WriteLine((Get-ReportCss))
        $st.WriteLine('</head><body><div class="page">')

        # Report Header
        $st.WriteLine("<h1>$($LocalizedStrings.ReportTitle)</h1>")
        $st.WriteLine('<div class="report-header">')
        $st.WriteLine("<p><strong>$($LocalizedStrings.AnalyzedArchiveLabel)</strong> $([System.Web.HttpUtility]::HtmlEncode($ReportData.ArchiveName))</p>")
        $st.WriteLine("<p><strong>$($LocalizedStrings.ReportGeneratedLabel)</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>")
        $st.WriteLine('</div>')

        # Executive Summary
        $st.WriteLine("<h2>$($LocalizedStrings.ExecutiveSummary)</h2>")
        $st.WriteLine('<div class="verdict">')
        $st.WriteLine("<p class='verdict-critical'><strong>$($LocalizedStrings.VerdictById)</strong> $($ReportData.VerdictById)</p>")
        $st.WriteLine("<p class='verdict-keyword'><strong>$($LocalizedStrings.VerdictByKeyword)</strong> $($ReportData.VerdictByKeyword)</p>")
        $st.WriteLine('</div>')

        # Critical Events
        $st.WriteLine("<h2>$($LocalizedStrings.CriticalEventDetails)</h2>")
        if ($ReportData.CriticalEvents) {
            $st.WriteLine("<input type='text' id='criticalFilter' placeholder='$($LocalizedStrings.FilterCriticalEvents)' class='filter-input'>")
            $st.WriteLine("<table id='criticalTable'><thead><tr><th style='width:18%;'>Date/Time</th><th style='width:8%;'>Id</th><th style='width:20%;'>Provider</th><th>Message Summary</th><th style='width:12%;'>Details</th></tr></thead><tbody>")
            
            foreach ($ev in $ReportData.CriticalEvents) {
                $msg = if ($null -ne $ev.Message) { $ev.Message } else { '' }
                $first = [System.Web.HttpUtility]::HtmlEncode(($msg -split '\n')[0].Trim())
                $full  = [System.Web.HttpUtility]::HtmlEncode($msg)
                
                $st.WriteLine("<tr><td>$($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))</td><td>$($ev.Id)</td><td>$([System.Web.HttpUtility]::HtmlEncode($ev.ProviderName))</td><td>$first</td><td><button class='details-button'>$($LocalizedStrings.DetailsButtonView)</button></td></tr>")
                $st.WriteLine("<tr class='details-row'><td colspan='5'><pre>$full</pre></td></tr>")
            }
            $st.WriteLine("</tbody></table>")
        } else {
            $st.WriteLine("<p>$($LocalizedStrings.NoCriticalEvents)</p>")
        }

        # Keyword Events
        $st.WriteLine("<h2>$($LocalizedStrings.KeywordAlertDetails)</h2>")
        if ($ReportData.KeywordEvents) {
            $st.WriteLine("<input type='text' id='keywordFilter' placeholder='$($LocalizedStrings.FilterKeywordEvents)' class='filter-input'>")
            $st.WriteLine("<table id='keywordTable'><thead><tr><th style='width:18%;'>Date/Time</th><th style='width:8%;'>Id</th><th style='width:20%;'>Provider</th><th style='width:15%;'>Keyword</th><th>Message</th></tr></thead><tbody>")
            
            foreach ($ev in $ReportData.KeywordEvents) {
                $encodedKw = [System.Web.HttpUtility]::HtmlEncode($ev.MatchedKeyword)
                $msg = [System.Web.HttpUtility]::HtmlEncode(($ev.Message -split "\n")[0].Trim())
                $st.WriteLine("<tr><td>$($ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))</td><td>$($ev.Id)</td><td>$([System.Web.HttpUtility]::HtmlEncode($ev.Provider))</td><td><span class='keyword-highlight'>$encodedKw</span></td><td>$msg</td></tr>")
            }
            $st.WriteLine("</tbody></table>")
        } else {
            $st.WriteLine("<p>$($LocalizedStrings.NoKeywordEventsFound)</p>")
        }

        $st.WriteLine("</div>") # Close .page
        $st.WriteLine("<div class='footer'><p>$($LocalizedStrings.FooterCopyright) <a href='https://github.com/L0g0rhythm/LogTool' target='_blank'>L0g0rhythm</a></p></div>")
        $st.WriteLine((Get-ReportJavaScript -LocalizedStrings $LocalizedStrings))
        $st.WriteLine("</body></html>")
    }
    finally {
        $st.Close()
        $st.Dispose()
    }
}

function Show-ConsoleReport {
    [CmdletBinding()]
    param($Result, $Configuration, $LocalizedStrings)
    $max = $Configuration.AnalysisConfig.MaxDetailItems
    Write-SectionHeader -Title $LocalizedStrings.DiagnosticReport
    $vColor = if ($Result.VerdictById -match 'ATTENTION|ATENC') { "Red" } else { "Green" }
    Write-Host "  +- Quick Dashboard -------------------------------------------------------+"
    Write-Host "  | $($LocalizedStrings.VerdictById): " -NoNewline; Write-Host $Result.VerdictById -ForegroundColor $vColor
    Write-Host "  | $($LocalizedStrings.VerdictByKeyword): " -NoNewline; Write-Host $Result.VerdictByKeyword -ForegroundColor Yellow
    Write-Host "  | Total Events: $($Result.TotalEvents)"
    Write-Host "  +-------------------------------------------------------------------------+"
    
    if ($Result.CriticalEvents) {
        Write-Host "`n  +- $($LocalizedStrings.CriticalEventDetails) (Last $max) -----------------+"
        $Result.CriticalEvents | Select-Object -First $max | Format-Table TimeCreated, Id, @{N='Provider';E={($_.ProviderName -split '-')[-1]}} | Out-String -Stream | ForEach-Object { "  | $_".TrimEnd() }
    }
}

 Export-ModuleMember -Function Invoke-HtmlReport, Show-ConsoleReport
#endregion
