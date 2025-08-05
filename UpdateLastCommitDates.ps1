$logFile = "$PSScriptRoot\madcap-prebuild-log.txt"
Start-Transcript -Path $logFile -Append

Write-Host "===== Script Started ====="
Write-Host "Start Time: $(Get-Date)"
Write-Host ""

$projectRoot = $PSScriptRoot
$folder = Join-Path $projectRoot "Content\Product Documentation"

Write-Host "Scanning folder: $folder`n"

# Step 1: Get list of .htm/.html files changed in last commit
Push-Location $projectRoot
$changedFiles = git diff-tree --no-commit-id --name-only -r HEAD |
    Where-Object { $_ -match '\.html?$' -and ($_ -like "Content/Product Documentation/*") }
Pop-Location

foreach ($relativePath in $changedFiles) {
    $filePath = Join-Path $projectRoot $relativePath
    Write-Host "`n--- Processing changed file: $filePath ---"

    if (-not (Test-Path $filePath)) {
        Write-Host "File not found: $filePath"
        continue
    }

    # Get last commit date for this file
    Push-Location $projectRoot
    $gitDate = git log -1 --format="%ad" --date=format:"%d %B, %Y %I:%M %p" -- "$relativePath" 2>$null
    Pop-Location

    if (-not $gitDate) {
        Write-Host "No Git date found. Skipping: $filePath"
        continue
    }

    Write-Host "Git Date Found: $gitDate"

    $content = Get-Content -Path $filePath -Raw
    $originalContent = $content

    # Define badge comment
    $badgeComment = "<!-- last-updated-badge: $gitDate -->"
    $badgePattern = "<!-- last-updated-badge: .*? -->"

    if ($content -match $badgePattern) {
        Write-Host "Updating existing badge comment..."
        $content = [regex]::Replace($content, $badgePattern, $badgeComment)
    } elseif ($content -match "</body>") {
        Write-Host "Inserting new badge comment before </body>..."
        $content = $content -replace "</body>", "$badgeComment`n</body>"
    } else {
        Write-Host "No </body> tag found. Skipping injection."
    }

    # Save only if content changed
    if ($content -ne $originalContent) {
        Set-Content -Path $filePath -Value $content -Encoding UTF8
        Write-Host "Updated: $filePath"
    } else {
        Write-Host "No update needed."
    }
}

Write-Host "`n===== Script Completed ====="
Write-Host "End Time: $(Get-Date)"

Stop-Transcript
