param([ValidateRange(1024,65535)][int]$FrontendPort = 4200)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$python = Join-Path $root '.venv/Scripts/python.exe'
if (!(Test-Path $python) -or !(Test-Path (Join-Path $root 'frontend/node_modules'))) { throw 'Faltan dependencias; consulte README.md' }
if (!(Test-Path (Join-Path $root '.env'))) { throw 'Falta .env; ejecute setup-db.ps1 o configure .env.example' }
Push-Location (Join-Path $root 'backend')
try { $port = & $python -c "from app.core.config import get_settings; print(get_settings().api_port)" } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer configuracion' }
$env:API_PORT = "$port"
function Test-LocalPort([int]$PortNumber) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try { return $client.ConnectAsync('localhost', $PortNumber).Wait(1000) -and $client.Connected }
    catch { return $false }
    finally { $client.Dispose() }
}
if (Test-LocalPort ([int]$port)) { throw "Puerto API $port ocupado. Detenga la instancia anterior o configure API_PORT." }
if (Test-LocalPort $FrontendPort) { throw "Puerto frontend $FrontendPort ocupado. Use -FrontendPort con otro puerto." }
$backend = $null
try {
    $backend = Start-Process -FilePath $python -ArgumentList @('-m','uvicorn','app.main:app','--host','127.0.0.1','--port',"$port") -WorkingDirectory (Join-Path $root 'backend') -WindowStyle Hidden -PassThru
    $ready = $false
    for ($i=0; $i -lt 20; $i++) {
        if ($backend.HasExited) { throw 'El backend termino inesperadamente' }
        try { $health = Invoke-RestMethod "http://127.0.0.1:$port/api/v1/health"; if ($health.status -eq 'ok') { $ready=$true; break } } catch { Start-Sleep -Milliseconds 500 }
    }
    if (!$ready) { throw 'Backend sin respuesta. Revise conexion SQL, permisos y puerto.' }
    Write-Host "API: http://127.0.0.1:$port/docs | Interfaz: http://localhost:$FrontendPort | Ctrl+C para detener"
    Push-Location (Join-Path $root 'frontend')
    try { & npm.cmd start -- --host localhost --port $FrontendPort } finally { Pop-Location }
} finally {
    if ($backend -and !$backend.HasExited) { & taskkill.exe /PID $backend.Id /T /F | Out-Null }
}
