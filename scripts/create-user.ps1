param([string]$Username)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$arguments = @((Join-Path $root 'backend/tools/manage.py'), 'create-user')
if ($Username) { $arguments += @('--username', $Username) }
& (Join-Path $root '.venv/Scripts/python.exe') @arguments
exit $LASTEXITCODE
