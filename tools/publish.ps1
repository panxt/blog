$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$deployDir = Join-Path $root ".manual_deploy"

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "hexo-node16.ps1") clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "hexo-node16.ps1") generate
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path $deployDir) {
    Remove-Item $deployDir -Recurse -Force
}

git clone --branch gh-pages https://github.com/panxt/blog.git $deployDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-ChildItem $deployDir -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
robocopy (Join-Path $root "public") $deployDir /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null

Push-Location $deployDir
try {
    git add --all
    git commit -m "deploy: publish updated blog"
    if ($LASTEXITCODE -ne 0) {
        $status = git status --short
        if (-not $status) {
            Write-Host "No site changes to publish."
            exit 0
        }
        exit $LASTEXITCODE
    }

    git push origin gh-pages
    exit $LASTEXITCODE
}
finally {
    Pop-Location
    if (Test-Path $deployDir) {
        Remove-Item $deployDir -Recurse -Force
    }
}
