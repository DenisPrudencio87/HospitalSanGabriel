param([string]$Server, [string]$Database, [switch]$Demo, [switch]$ExistingEmpty)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root '.venv/Scripts/python.exe'
if (!(Test-Path $python)) { throw 'Falta .venv. Consulte README.md' }
if ($Server) { $env:SQL_SERVER = $Server }
if ($Database) { $env:SQL_DATABASE = $Database }
$arguments = @((Join-Path $root 'backend/tools/manage.py'), 'setup')
if ($Demo) { $arguments += '--demo' }
if ($ExistingEmpty) { $arguments += '--existing-empty' }
& $python @arguments
exit $LASTEXITCODE
