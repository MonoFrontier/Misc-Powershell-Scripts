# Define the output file paths
$outputFile = "C:\temp\DcDiagReport_$hostname_$(Get-Date -Format 'yyyyMMdd').txt"
$htmlOutputFile = "C:\temp\DcDiagReport_$hostname_$(Get-Date -Format 'yyyyMMdd').html"

# Run DCDIAG and capture the results
Write-Host "Running DCDIAG, this may take a few minutes..."
DCDIAG /c /v > $outputFile

# Read the results
$dcDiagResults = Get-Content $outputFile

# Define a function to convert results into an HTML format
function ConvertTo-HTMLReport {
    param (
        [string[]]$Content,
        [string]$HtmlFile
    )

    # Initialize HTML content
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>DC Diagnostics Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #004085; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .pass { color: green; }
        .fail { color: red; }
    </style>
</head>
<body>
    <h1>DC Diagnostics Report - $(Get-Date -Format 'yyyy-MM-dd')</h1>
"@

    # Parse results for test summaries
    $htmlContent += "<h2>Test Summary</h2><table><tr><th>Test</th><th>Status</th></tr>"
    foreach ($line in $Content) {
        if ($line -match "Starting test") {
            $testName = $line -replace "Starting test:", ""
            $testName = $testName.Trim()
            $status = "Pass"
        }
        if ($line -match "failed|error|warning") {
            $status = "Fail"
        }

        # Add to the table
        if ($testName) {
            $statusClass = if ($status -eq "Pass") { "pass" } else { "fail" }
            $htmlContent += "<tr><td>$testName</td><td class='$statusClass'>$status</td></tr>"
            $testName = $null
        }
    }
    $htmlContent += "</table>"

    # Parse the full results for details
    $htmlContent += "<h2>Detailed Results</h2><pre style='background-color: #f5f5f5; padding: 10px;'>"
    $htmlContent += $Content -join "`n"
    $htmlContent += "</pre>"

    # Close HTML content
    $htmlContent += "</body></html>"

    # Write to the output HTML file
    Set-Content -Path $HtmlFile -Value $htmlContent
}

# Convert the DCDIAG results to HTML report
Write-Host "Generating HTML report..."
ConvertTo-HTMLReport -Content $dcDiagResults -HtmlFile $htmlOutputFile

Write-Host "HTML report generated successfully at $htmlOutputFile."
