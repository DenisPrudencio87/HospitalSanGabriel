$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
foreach ($tool in @('git','node','npm.cmd','py')) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) { & $tool --version } else { Write-Warning "$tool no disponible" }
}
$python = Join-Path $root '.venv/Scripts/python.exe'
if (Test-Path $python) {
    & $python (Join-Path $root 'backend/tools/manage.py') check
    exit $LASTEXITCODE
}
Write-Warning 'Falta .venv. Cree el entorno e instale backend/requirements.txt; luego repita para comprobar SQL.'
