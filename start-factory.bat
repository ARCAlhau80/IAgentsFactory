@echo off
setlocal
cd /d "%~dp0"

title IAgentsFactory - One Click Start
color 0A

set "FACTORY_ROOT=%~dp0"
set "PS1=%FACTORY_ROOT%iagents-factory.ps1"
set "FACTORY_URL=http://localhost:3010"
set "HEALTH_URL=%FACTORY_URL%/health"

if not exist "%PS1%" (
    echo.
    echo [ERR] iagents-factory.ps1 nao encontrado em:
    echo       %PS1%
    echo.
    pause
    exit /b 1
)

echo.
echo [1/3] Inicializando Knowledge Hub (idempotente)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" init
if errorlevel 1 (
    echo.
    echo [WARN] Falha no init. Tentando subir dashboard mesmo assim...
)

echo.
echo [2/3] Subindo dashboard da Factory em nova janela...
start "IAgentsFactory Dashboard" powershell -NoExit -NoProfile -ExecutionPolicy Bypass -Command "Set-Location '%FACTORY_ROOT%'; .\iagents-factory.ps1 dashboard"

echo.
echo [3/3] Validando health endpoint e abrindo navegador...
powershell -NoProfile -ExecutionPolicy Bypass -Command "for($i=0;$i -lt 20;$i++){ try { $r=Invoke-WebRequest -UseBasicParsing '%HEALTH_URL%' -TimeoutSec 2; if($r.StatusCode -eq 200){ exit 0 } } catch {}; Start-Sleep -Milliseconds 500 }; exit 1"
if errorlevel 1 (
    echo [WARN] Dashboard ainda inicializando. Abra manualmente: %FACTORY_URL%
) else (
    start "" "%FACTORY_URL%"
    echo [OK] Dashboard ativo em %FACTORY_URL%
)

echo.
echo Dica: para parar, feche a janela "IAgentsFactory Dashboard" ou use Ctrl+C nela.
echo.
endlocal
exit /b 0
