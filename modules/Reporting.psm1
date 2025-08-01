#
# Module: Reporting.psm1 v27.0 (Refactored & Hardened)
# Description: Generates a world-class, internationalized report with a fully functional interactive table.
# Author: L0g0rhythm
#

#region Module Scope Setup
# Load necessary assemblies once at module import for efficiency.
Add-Type -AssemblyName System.Web
#endregion

#region Private Helper Functions

function Get-ReportJavaScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LocalizedStrings
    )

    # All JavaScript is self-contained and uses modern, efficient techniques.
    return @"
<script>
    // Handles table filtering logic.
    function filterTable(inputId, tableId) {
        const input = document.getElementById(inputId);
        const filter = input.value.toUpperCase();
        const table = document.getElementById(tableId);
        const tbody = table.getElementsByTagName("tbody")[0];
        const tr = tbody.getElementsByTagName("tr");

        for (let i = 0; i < tr.length; i++) {
            // Skip rows that are detail containers.
            if (tr[i].classList.contains('details-row')) continue;

            const row = tr[i];
            const textValue = row.textContent || row.innerText;
            const isVisible = textValue.toUpperCase().indexOf(filter) > -1;
            row.style.display = isVisible ? "" : "none";

            // Also hide the associated details row if the main row is hidden.
            const detailsRow = row.nextElementSibling;
            if (detailsRow && detailsRow.classList.contains('details-row')) {
                // If main row is visible, don't alter details visibility (it has its own state)
                // If main row is hidden, details row must also be hidden.
                if (!isVisible) {
                    detailsRow.style.display = "none";
                }
            }
        }
    }

    // Use event delegation for robust and reliable event handling for details buttons.
    document.addEventListener('DOMContentLoaded', function() {
        document.body.addEventListener('click', function(event) {
            // Ensure the click was on a details button inside a relevant table.
            if (event.target && event.target.matches('.details-button')) {
                const button = event.target;
                const mainRow = button.closest('tr');
                if (!mainRow) return;

                const detailsRow = mainRow.nextElementSibling;
                if (detailsRow && detailsRow.classList.contains('details-row')) {
                    const isVisible = detailsRow.style.display === 'table-row';
                    detailsRow.style.display = isVisible ? 'none' : 'table-row';
                    button.textContent = isVisible ? '$($LocalizedStrings.DetailsButtonView)' : '$($LocalizedStrings.DetailsButtonHide)';
                }
            }
        });
    });
</script>
"@
}

function Get-ReportCss {
    [CmdletBinding()]
    param()

    # All styles are self-contained.
    return @"
<style>
    @import url('https://fonts.googleapis.com/css2?family=Georgia&family=Courier+New&display=swap');
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

    body {
        font-family: var(--font-serif);
        background-color: #e9ecef;
        color: var(--color-text);
        margin: 0;
        padding: 1rem;
        line-height: 1.6;
    }

    .page {
        width: 210mm;
        min-height: 297mm;
        padding: 2cm;
        margin: 1cm auto;
        border: 1px solid #ccc;
        background: var(--color-background);
        box-shadow: 0 0 10px rgba(0, 0, 0, 0.15);
        box-sizing: border-box;
    }

    h1, h2 {
        color: var(--color-primary);
        font-weight: normal;
        margin-top: 1.5em;
        margin-bottom: 0.8em;
        border-bottom: 2px solid var(--color-primary);
        padding-bottom: 8px;
    }
    h1 { font-size: 26pt; }
    h2 { font-size: 18pt; border-bottom-width: 1px; }

    .report-header p, .verdict p {
        margin: 0.4em 0;
        font-size: 11pt;
    }

    .verdict-critical { color: var(--color-critical); font-weight: bold; }
    .verdict-keyword { color: var(--color-keyword); font-weight: bold; }

    .filter-input {
        width: 100%;
        padding: 8px 12px;
        margin-bottom: 1rem;
        border: 1px solid var(--color-border);
        border-radius: 4px;
        font-family: var(--font-mono);
        box-sizing: border-box;
        font-size: 10pt;
    }

    table {
        border-collapse: collapse;
        width: 100%;
        margin-top: 1rem;
        font-size: 9pt;
    }

    th, td {
        border: 1px solid var(--color-border);
        padding: 10px 14px;
        text-align: left;
        vertical-align: middle;
    }

    th {
        background-color: var(--color-header-bg);
        font-family: var(--font-serif);
        font-weight: bold;
    }

    td { font-family: var(--font-mono); }

    .details-row { display: none; background-color: var(--color-subtle-bg); }
    .details-row td { padding: 0; }
    .details-row pre {
        margin: 0;
        padding: 12px 16px;
        font-size: 8.5pt;
        white-space: pre-wrap;
        word-wrap: break-word;
    }

    .details-button {
        font-family: var(--font-serif);
        font-size: 8pt;
        padding: 2px 8px;
        cursor: pointer;
        border: 1px solid var(--color-border);
        background-color: #fff;
        border-radius: 4px;
    }
    .details-button:hover { background-color: var(--color-header-bg); }

    .keyword-highlight { background-color: #ffe066; font-weight: bold; }

    .footer {
        text-align: center;
        margin-top: 3rem;
        padding-top: 1rem;
        border-top: 1px solid var(--color-border);
        font-size: 9pt;
        color: #6c757d;
    }
    .footer a { color: var(--color-primary); text-decoration: none; font-weight: bold; }
    .footer a:hover { text-decoration: underline; }

    @media print {
        body { background: none; padding: 0; }
        .page { border: initial; margin: 0; box-shadow: initial; background: initial; page-break-after: always; }
        .filter-input, .details-button { display: none; }
        .details-row { display: table-row !important; }
    }
</style>
"@
}

#endregion

function Invoke-HtmlReport {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$ReportData,

        [Parameter(Mandatory = $true)]
        [hashtable]$LocalizedStrings
    )

    try {
        #region Phase 1: Asset Generation
        # Get CSS and JavaScript from helper functions for better modularity.
        $css = Get-ReportCss
        $javascript = Get-ReportJavaScript -LocalizedStrings $LocalizedStrings

        # Use StringBuilder for efficient string construction.
        $bodyBuilder = [System.Text.StringBuilder]::new()
        #endregion

        #region Phase 2: HTML Body Construction

        $bodyBuilder.AppendLine('<div class="page">') | Out-Null

        # Report Header & Executive Summary
        $bodyBuilder.AppendLine(('<h1>{0}</h1>' -f $LocalizedStrings.ReportTitle)) | Out-Null
        $bodyBuilder.AppendLine('<div class="report-header">') | Out-Null
        $bodyBuilder.AppendLine(('<p><strong>{0}</strong> {1}</p>' -f $LocalizedStrings.AnalyzedArchiveLabel, [System.Web.HttpUtility]::HtmlEncode($ReportData.ArchiveName))) | Out-Null
        $bodyBuilder.AppendLine(('<p><strong>{0}</strong> {1}</p>' -f $LocalizedStrings.ReportGeneratedLabel, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))) | Out-Null
        $bodyBuilder.AppendLine('</div>') | Out-Null

        $bodyBuilder.AppendLine(('<h2>{0}</h2>' -f $LocalizedStrings.ExecutiveSummary)) | Out-Null
        $bodyBuilder.AppendLine('<div class="verdict">') | Out-Null
        $bodyBuilder.AppendLine(('<p class="verdict-critical"><strong>{0}</strong> {1}</p>' -f $LocalizedStrings.VerdictById, $ReportData.VerdictById)) | Out-Null
        $bodyBuilder.AppendLine(('<p class="verdict-keyword"><strong>{0}</strong> {1}</p>' -f $LocalizedStrings.VerdictByKeyword, $ReportData.VerdictByKeyword)) | Out-Null
        $bodyBuilder.AppendLine('</div>') | Out-Null

        # Critical Events Table
        $bodyBuilder.AppendLine(('<h2>{0}</h2>' -f $LocalizedStrings.CriticalEventDetails)) | Out-Null
        if ($ReportData.CriticalEvents) {
            $bodyBuilder.AppendLine(('''<input type="text" id="criticalFilter" onkeyup="filterTable(''criticalFilter'', ''criticalTable'')" placeholder="{0}" class="filter-input">''' -f $LocalizedStrings.FilterCriticalEvents)) | Out-Null
            $bodyBuilder.AppendLine('<table id="criticalTable">') | Out-Null
            $bodyBuilder.AppendLine('<thead><tr><th style="width:18%;">Date/Time</th><th style="width:8%;">Id</th><th style="width:20%;">ProviderName</th><th>Message Summary</th><th style="width:12%;">Details</th></tr></thead><tbody>') | Out-Null

            foreach ($criticalEvent in $ReportData.CriticalEvents) {
                $rawMessage = if ($null -ne $criticalEvent.Message) { $criticalEvent.Message } else { '' }
                $firstLine = [System.Web.HttpUtility]::HtmlEncode(($rawMessage -split '\r?\n')[0].Trim())
                $fullMessageEncoded = [System.Web.HttpUtility]::HtmlEncode($rawMessage)

                # Main Row
                $bodyBuilder.AppendLine('<tr>') | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $criticalEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))) | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $criticalEvent.Id)) | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f [System.Web.HttpUtility]::HtmlEncode($criticalEvent.ProviderName))) | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $firstLine)) | Out-Null
                $bodyBuilder.AppendLine(('<td><button class="details-button">{0}</button></td>' -f $LocalizedStrings.DetailsButtonView)) | Out-Null
                $bodyBuilder.AppendLine('</tr>') | Out-Null

                # Hidden Details Row
                $bodyBuilder.AppendLine(('<tr class="details-row"><td colspan="5"><pre>{0}</pre></td></tr>' -f $fullMessageEncoded)) | Out-Null
            }
            $bodyBuilder.AppendLine('</tbody></table>') | Out-Null
        } else {
            $bodyBuilder.AppendLine(('<p>{0}</p>' -f $LocalizedStrings.NoCriticalEvents)) | Out-Null
        }

        # Keyword Events Table
        $bodyBuilder.AppendLine(('<h2>{0}</h2>' -f $LocalizedStrings.KeywordAlertDetails)) | Out-Null
        if ($ReportData.KeywordEvents) {
            $bodyBuilder.AppendLine(('''<input type="text" id="keywordFilter" onkeyup="filterTable(''keywordFilter'', ''keywordTable'')" placeholder="{0}" class="filter-input">''' -f $LocalizedStrings.FilterKeywordEvents)) | Out-Null
            $bodyBuilder.AppendLine('<table id="keywordTable">') | Out-Null
            $bodyBuilder.AppendLine('<thead><tr><th style="width:18%;">Date/Time</th><th style="width:8%;">Id</th><th style="width:20%;">Provider</th><th style="width:15%;">Matched Keyword</th><th>Message</th></tr></thead><tbody>') | Out-Null

            foreach ($keywordEvent in $ReportData.KeywordEvents) {
                # SECURITY FIX: Sanitize message parts around the keyword to prevent XSS.
                $rawMessage = ($keywordEvent.Message -split "`r`n")[0].Trim()
                $rawKeyword = $keywordEvent.MatchedKeyword
                $encodedKeyword = [System.Web.HttpUtility]::HtmlEncode($rawKeyword)
                $highlightSpan = "<span class='keyword-highlight'>$encodedKeyword</span>"

                $messageParts = $rawMessage -split ([regex]::Escape($rawKeyword))
                $encodedParts = foreach ($part in $messageParts) { [System.Web.HttpUtility]::HtmlEncode($part) }
                $highlightedMessage = $encodedParts -join $highlightSpan

                # Table Row
                $bodyBuilder.AppendLine('<tr>') | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $keywordEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))) | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $keywordEvent.Id)) | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f [System.Web.HttpUtility]::HtmlEncode($keywordEvent.Provider))) | Out-Null
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $encodedKeyword)) | Out-Null # Use the already encoded keyword
                $bodyBuilder.AppendLine(('<td>{0}</td>' -f $highlightedMessage)) | Out-Null
                $bodyBuilder.AppendLine('</tr>') | Out-Null
            }
            $bodyBuilder.AppendLine('</tbody></table>') | Out-Null
        } else {
            $bodyBuilder.AppendLine(('<p>{0}</p>' -f $LocalizedStrings.NoKeywordEventsFound)) | Out-Null
        }

        # Footer
        $bodyBuilder.AppendLine('<div class="footer">') | Out-Null
        $bodyBuilder.AppendLine('<p>LogTool v27.0 - Professional Analysis Artifact</p>') | Out-Null
        $bodyBuilder.AppendLine(('''<p>{0} <a href="https://l0g0rhythm.com.br/" target="_blank">L0g0rhythm</a></p>''' -f $LocalizedStrings.ToolCreator)) | Out-Null
        $bodyBuilder.AppendLine('</div>') | Out-Null

        $bodyBuilder.AppendLine('</div>') | Out-Null
        #endregion

        #region Phase 3: Final Assembly
        # Construct the final HTML document manually for full control.
        $htmlContent = @"
<!DOCTYPE html>
<html lang="$($LocalizedStrings.LanguageCode)">
<head>
    <meta charset="UTF-8">
    <title>$([System.Web.HttpUtility]::HtmlEncode($LocalizedStrings.ReportTitle)) - $([System.Web.HttpUtility]::HtmlEncode($ReportData.ArchiveName))</title>
    $css
    $javascript
</head>
<body>
$($bodyBuilder.ToString())
</body>
</html>
"@
        #endregion

        return $htmlContent

    } catch {
        # Robust error handling
        $errorMessage = "Failed to generate HTML report. Error on line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
        Write-Error $errorMessage
        # Optionally, return a simple error HTML
        return "<html><body><h1>Report Generation Failed</h1><p>$([System.Web.HttpUtility]::HtmlEncode($errorMessage))</p></body></html>"
    }
}

Export-ModuleMember -Function Invoke-HtmlReport
