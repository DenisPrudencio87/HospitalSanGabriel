$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root '.venv/Scripts/python.exe'
if (!(Test-Path $python) -or !(Test-Path (Join-Path $root 'frontend/node_modules'))) { throw 'Faltan dependencias; consulte README.md' }
if (!(Test-Path (Join-Path $root '.env'))) { throw 'Falta .env; ejecute setup-db.ps1 o configure .env.example' }
$port = & $python -c "import sys; sys.path.insert(0,r'$root/backend'); from app.core.config import get_settings; print(get_settings().api_port)"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer configuracion' }
$env:API_PORT = "$port"
$backend = $null
try {
    $backend = Start-Process -FilePath $python -ArgumentList @('-m','uvicorn','app.main:app','--host','127.0.0.1','--port',"$port") -WorkingDirectory (Join-Path $root 'backend') -WindowStyle Hidden -PassThru
    $ready = $false
    for ($i=0; $i -lt 20; $i++) {
        if ($backend.HasExited) { throw 'El backend termino inesperadamente' }
        try { $health = Invoke-RestMethod "http://127.0.0.1:$port/api/v1/health"; if ($health.status -eq 'ok') { $ready=$true; break } } catch { Start-Sleep -Milliseconds 500 }
    }
    if (!$ready) { throw 'Backend sin respuesta. Revise conexion SQL, permisos y puerto.' }
    Write-Host "API: http://127.0.0.1:$port/docs | Interfaz: http://localhost:4200 | Ctrl+C para detener"
    Push-Location (Join-Path $root 'frontend')
    try { & npm.cmd start -- --host localhost } finally { Pop-Location }
} finally {
    if ($backend -and !$backend.HasExited) { Stop-Process -Id $backend.Id }
}
