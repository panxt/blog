$ErrorActionPreference = "Stop"

$requiredVersion = "16.20.2"

function Ensure-NodeVersion {
    $current = (& node -v) 2>$null
    if ($LASTEXITCODE -eq 0 -and $current -eq "v$requiredVersion") {
        return
    }

    $nvmList = ((& nvm list) | Out-String)
    if ($nvmList -notmatch [regex]::Escape($requiredVersion)) {
        throw "Node.js $requiredVersion is not installed. Run 'nvm install $requiredVersion' first."
    }

    & nvm use $requiredVersion | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to switch to Node.js $requiredVersion."
    }
}

Ensure-NodeVersion

if ($args.Count -eq 0) {
    throw "Usage: powershell -File tools/hexo-node16.ps1 <hexo args>"
}

& cmd /c "node_modules\\.bin\\hexo.cmd $($args -join ' ')"
exit $LASTEXITCODE
