# Stops Git from tracking these folders but KEEPS all files on your computer.
# Run in PowerShell from this folder (right-click -> Run with PowerShell),
# or:  cd "path\to\corefx"  ;  .\untrack-ignored-folders.ps1
#
# Requires Git (Git for Windows / PATH).

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found in PATH. Open 'Git Bash' here and run:" -ForegroundColor Red
    Write-Host '  git rm -r --cached Documents AI GIS Images Graphics Data Dataout' -ForegroundColor Yellow
    exit 1
}

$folders = @(
    "Documents",
    "AI",
    "GIS",
    "Images",
    "Graphics",
    "Data",
    "Dataout"
)

foreach ($f in $folders) {
    if (-not (Test-Path $f)) { continue }
    $tracked = git ls-files -- $f 2>$null
    if ($tracked) {
        Write-Host "Untracking: $f" -ForegroundColor Cyan
        git rm -r --cached -- $f
    } else {
        Write-Host "Skip (not tracked): $f" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  git add .gitignore"
Write-Host "  git commit -m ""Stop tracking Documents and other ignored folders (files stay local)"""
Write-Host "  git push"
