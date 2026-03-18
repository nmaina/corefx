# Run AFTER untrack-ignored-folders.ps1 (or if you already ran git rm --cached).
# From project folder:  .\commit-after-untrack.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Install Git or open Git Bash here, then run:" -ForegroundColor Red
    Write-Host '  git add -u .gitignore' -ForegroundColor Yellow
    Write-Host '  git commit -m "Stop tracking ignored folders; files stay local"' -ForegroundColor Yellow
    Write-Host '  git push' -ForegroundColor Yellow
    exit 1
}

# Stage removal from index + .gitignore changes
git add .gitignore
git add -u

git status

$msg = "Stop tracking Documents and other ignored folders (files stay local)"
git commit -m $msg

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nPushing..." -ForegroundColor Cyan
    git push
}
