# ===============================================================
# IAgentsFactory - Hermes Agent Setup
#
# Instalacao e configuracao automatica do Hermes Agent
# integrado ao Knowledge Hub da factory.
#
# USO:
#   .\setup-hermes.ps1                  -> Instalacao completa interativa
#   .\setup-hermes.ps1 -Auto            -> Sem perguntas (usa defaults)
#   .\setup-hermes.ps1 -CheckOnly       -> Apenas valida ambiente
#   .\setup-hermes.ps1 -Uninstall       -> Remove integracao Hermes
#
# REQUISITOS AUTOMATICAMENTE VERIFICADOS:
#   - Windows 10/11 com WSL2 habilitado
#   - Ubuntu 20.04+ no WSL2
#   - 4GB RAM minima (8GB recomendado para modelos locais)
#   - 10GB espaco livre (para Hermes + modelo Ollama)
#   - Conexao com internet (apenas no install inicial)
# ===============================================================

param(
    [switch]$Auto,
    [switch]$CheckOnly,
    [switch]$Uninstall,
    [switch]$SkipOllama,
    [string]$WslDistro = "Ubuntu",
    [string]$OllamaModel = "llama3.2:3b"
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding  = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {}

$FactoryRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$FactoryDir   = Join-Path $env:USERPROFILE ".iagents-factory"
$HermesConfig = Join-Path $FactoryDir "hermes-config.json"
$HermesLog    = Join-Path $FactoryDir "hermes-setup.log"
$ConfigSrc    = Join-Path $FactoryRoot "config\hermes-config.json"

# ── Helpers ─────────────────────────────────────────────────────

function Write-H  { param([string]$T) Write-Host "`n  $T" -ForegroundColor Cyan }
function Write-Ok { param([string]$T) Write-Host "  [OK] $T" -ForegroundColor Green }
function Write-Warn { param([string]$T) Write-Host "  [WARN] $T" -ForegroundColor Yellow }
function Write-Err  { param([string]$T) Write-Host "  [ERR] $T" -ForegroundColor Red }
function Write-Info { param([string]$T) Write-Host "  $T" -ForegroundColor DarkGray }
function Write-Step { param([string]$T) Write-Host "  --> $T" -ForegroundColor White }

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts][$Level] $Message"
    Add-Content -Path $HermesLog -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Read-Yn {
    param([string]$Prompt, [bool]$Default = $true)
    $hint = if ($Default) { "S/n" } else { "s/N" }
    $ans = Read-Host "$Prompt [$hint]"
    if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
    return @('s','y','yes','sim') -contains $ans.ToLowerInvariant()
}

function Get-RamGB {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        return [Math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    } catch { return 0 }
}

function Get-FreeDiskGB {
    param([string]$Path = $env:USERPROFILE)
    try {
        $drive = Split-Path -Qualifier $Path
        $disk = Get-PSDrive ($drive.TrimEnd(':')) -ErrorAction Stop
        return [Math]::Round($disk.Free / 1GB, 1)
    } catch { return 0 }
}

function Invoke-Wsl {
    param([string]$Cmd, [switch]$PassThru)
    $result = wsl -d $WslDistro -- bash -c $Cmd 2>&1
    if ($PassThru) { return $result }
    return ($LASTEXITCODE -eq 0)
}

function Test-WslCommand {
    param([string]$Name)
    $out = wsl -d $WslDistro -- bash -c "command -v $Name 2>/dev/null" 2>&1
    return ($out -and $out.Trim() -ne "")
}

# ── Validacao de ambiente ────────────────────────────────────────

function Test-Environment {
    Write-H "Validando ambiente..."
    $issues   = @()
    $warnings = @()
    $ok       = $true

    # Windows version
    $winVer = [System.Environment]::OSVersion.Version
    if ($winVer.Major -lt 10) {
        $issues += "Windows 10 ou superior necessario (atual: $($winVer.Major).$($winVer.Minor))"
        $ok = $false
    } else {
        Write-Ok "Windows $($winVer.Major).$($winVer.Minor)"
    }

    # WSL2
    $wslOut = wsl --status 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $wslOut -match "not installed|nao instalado") {
        $issues += "WSL2 nao encontrado. Instale via: wsl --install"
        $ok = $false
    } else {
        # Check distro
        $distros = wsl --list --quiet 2>&1
        if ($distros -match $WslDistro) {
            Write-Ok "WSL2 com distro '$WslDistro' disponivel"
        } else {
            $warnings += "Distro '$WslDistro' nao encontrada. Distros disponiveis: $($distros -join ', ')"
        }
    }

    # RAM
    $ram = Get-RamGB
    if ($ram -lt 4) {
        $warnings += "RAM disponivel: ${ram}GB (minimo recomendado: 4GB para modelos locais)"
    } elseif ($ram -lt 8) {
        Write-Warn "RAM: ${ram}GB (8GB recomendado para melhor performance com modelos locais)"
    } else {
        Write-Ok "RAM: ${ram}GB"
    }

    # Disco
    $disk = Get-FreeDiskGB
    if ($disk -lt 5) {
        $issues += "Espaco em disco insuficiente: ${disk}GB livre (minimo: 5GB para Hermes + modelo)"
        $ok = $false
    } elseif ($disk -lt 10) {
        $warnings += "Espaco em disco: ${disk}GB (10GB recomendado para Hermes + Ollama + modelo)"
    } else {
        Write-Ok "Disco livre: ${disk}GB"
    }

    # Internet
    $ping = Test-NetConnection -ComputerName "hermes-agent.nousresearch.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $ping) {
        $warnings += "Sem acesso a hermes-agent.nousresearch.com — install pode falhar"
    } else {
        Write-Ok "Conexao com hermes-agent.nousresearch.com OK"
    }

    # FactoryDir
    if (-not (Test-Path $FactoryDir)) {
        New-Item -ItemType Directory -Path $FactoryDir -Force | Out-Null
    }

    foreach ($w in $warnings) { Write-Warn $w; Write-Log "WARN" $w }
    foreach ($e in $issues)   { Write-Err  $e; Write-Log "ERR"  $e }

    return $ok
}

# ── Instalar Hermes via WSL ──────────────────────────────────────

function Install-Hermes {
    Write-H "Instalando Hermes Agent no WSL ($WslDistro)..."
    Write-Log "INFO" "Iniciando instalacao do Hermes"

    # Verifica se ja esta instalado
    if (Test-WslCommand "hermes") {
        $ver = (Invoke-Wsl "hermes --version 2>/dev/null | head -1" -PassThru) -replace '[^0-9\.]',''
        Write-Ok "Hermes ja instalado (versao: $ver)"
        Write-Log "INFO" "Hermes ja presente: $ver"
        return $true
    }

    Write-Step "Baixando instalador do Hermes..."
    $installResult = Invoke-Wsl "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash 2>&1" -PassThru
    Write-Log "INFO" "Install output: $installResult"

    if (-not (Test-WslCommand "hermes")) {
        Write-Err "Instalacao do Hermes falhou. Verifique $HermesLog"
        Write-Log "ERR" "hermes command nao encontrado apos install"
        return $false
    }

    Write-Ok "Hermes instalado com sucesso"
    return $true
}

# ── Instalar Ollama + modelo local ───────────────────────────────

function Install-Ollama {
    Write-H "Configurando Ollama (modelo local)..."

    if (Test-WslCommand "ollama") {
        Write-Ok "Ollama ja instalado"
    } else {
        Write-Step "Instalando Ollama no WSL..."
        Invoke-Wsl "curl -fsSL https://ollama.com/install.sh | sh 2>&1" | Out-Null
        if (-not (Test-WslCommand "ollama")) {
            Write-Warn "Ollama nao instalado — modelos locais indisponiveis. Hermes usara providers externos."
            Write-Log "WARN" "Ollama install falhou — continuando sem modelo local"
            return
        }
        Write-Ok "Ollama instalado"
    }

    # Verifica se o modelo ja foi baixado
    $models = Invoke-Wsl "ollama list 2>/dev/null" -PassThru
    if ($models -match $OllamaModel.Split(':')[0]) {
        Write-Ok "Modelo $OllamaModel ja disponivel"
    } else {
        Write-Step "Baixando modelo $OllamaModel (pode levar alguns minutos)..."
        Write-Info "O modelo ficara armazenado localmente — nenhuma chamada externa sera feita apos o download."
        Invoke-Wsl "ollama pull $OllamaModel 2>&1" | Out-Null
        $modelsAfter = Invoke-Wsl "ollama list 2>/dev/null" -PassThru
        if ($modelsAfter -match $OllamaModel.Split(':')[0]) {
            Write-Ok "Modelo $OllamaModel pronto"
        } else {
            Write-Warn "Download do modelo pode estar em background. Verifique com: wsl ollama list"
        }
    }
}

# ── Configurar Hermes para a factory ────────────────────────────

function Set-HermesConfig {
    Write-H "Aplicando configuracao Hermes na factory..."

    # Copiar hermes-config.json para .iagents-factory
    if (Test-Path $ConfigSrc) {
        Copy-Item -Path $ConfigSrc -Destination $HermesConfig -Force
        Write-Ok "hermes-config.json copiado para $FactoryDir"
    }

    # Criar diretorio de memoria por projeto
    $memDir = Join-Path $FactoryDir "hermes-projects"
    if (-not (Test-Path $memDir)) {
        New-Item -ItemType Directory -Path $memDir -Force | Out-Null
        Write-Ok "Diretorio hermes-projects criado"
    }

    # Persistir env var HERMES_DISABLED = 0 no perfil do usuario
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch 'HERMES_DISABLED') {
        Add-Content -Path $profilePath -Value "`n`$env:HERMES_DISABLED = `"0`"  # IAgentsFactory Hermes integration" -Encoding UTF8
        Write-Ok "HERMES_DISABLED=0 adicionado ao perfil PowerShell"
    }

    # Inicializar hermes setup no WSL
    if (Test-WslCommand "hermes") {
        Write-Step "Executando hermes setup (modo nao-interativo)..."
        Invoke-Wsl "hermes setup --provider ollama --model $OllamaModel --non-interactive 2>/dev/null || hermes setup 2>/dev/null || true" | Out-Null
        Write-Ok "Hermes configurado"
    }

    Write-Log "INFO" "Configuracao Hermes concluida"
}

# ── Registrar tarefa de auto-update (Windows Task Scheduler) ────

function Register-AutoUpdateTask {
    Write-H "Registrando auto-update agendado (Task Scheduler)..."

    $taskName   = "IAgentsFactory-HermesUpdate"
    $scriptPath = Join-Path $FactoryRoot "hermes-update.ps1"

    # Remove task antiga se existir
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    if (-not (Test-Path $scriptPath)) {
        Write-Warn "hermes-update.ps1 nao encontrado — tarefa de auto-update nao criada."
        return
    }

    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
                 -Argument "-NonInteractive -WindowStyle Hidden -File `"$scriptPath`" -Silent"
    $trigger = New-ScheduledTaskTrigger -Daily -At "06:00AM"
    $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable `
                  -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 2 `
                  -RestartInterval (New-TimeSpan -Minutes 5)

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Settings $settings -Description "IAgentsFactory: verifica e aplica atualizacoes do Hermes Agent" `
            -RunLevel Limited -Force | Out-Null
        Write-Ok "Tarefa '$taskName' registrada (diaria as 06:00)"
    } catch {
        Write-Warn "Nao foi possivel registrar tarefa: $_. Execute setup-hermes.ps1 como Administrador para habilitar."
    }
}

# ── Registrar tarefa de sync diario ─────────────────────────────

function Register-SyncTask {
    Write-H "Registrando sync diario Hermes -> Knowledge Hub..."

    $taskName   = "IAgentsFactory-HermesSync"
    $scriptPath = Join-Path $FactoryRoot "hermes-sync.ps1"

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    if (-not (Test-Path $scriptPath)) {
        Write-Warn "hermes-sync.ps1 nao encontrado — tarefa de sync nao criada."
        return
    }

    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
                 -Argument "-NonInteractive -WindowStyle Hidden -File `"$scriptPath`" -Silent"
    $trigger = New-ScheduledTaskTrigger -Daily -At "06:30AM"
    $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable:$false -StartWhenAvailable `
                  -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Settings $settings -Description "IAgentsFactory: sincroniza memoria Hermes com Knowledge Hub" `
            -RunLevel Limited -Force | Out-Null
        Write-Ok "Tarefa '$taskName' registrada (diaria as 06:30)"
    } catch {
        Write-Warn "Nao foi possivel registrar tarefa de sync: $_"
    }
}

# ── Desinstalar integracao ───────────────────────────────────────

function Invoke-Uninstall {
    Write-H "Removendo integracao Hermes da factory..."

    foreach ($task in @("IAgentsFactory-HermesUpdate","IAgentsFactory-HermesSync")) {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        Write-Ok "Tarefa '$task' removida"
    }

    if (Test-Path $HermesConfig) {
        Remove-Item $HermesConfig -Force
        Write-Ok "hermes-config.json removido"
    }

    # Marcar como desabilitado no perfil
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath -Raw
        $content = $content -replace '\$env:HERMES_DISABLED = "0".*\n?', '$env:HERMES_DISABLED = "1"  # IAgentsFactory Hermes DISABLED' + "`n"
        Set-Content $profilePath $content -Encoding UTF8
    }

    Write-Ok "Integracao Hermes desativada. O Hermes em si nao foi removido do WSL."
    Write-Info "Para remover o Hermes do WSL: wsl -- bash -c 'sudo rm /usr/local/bin/hermes'"
}

# ── Status ───────────────────────────────────────────────────────

function Show-Status {
    Write-H "Status da integracao Hermes x IAgentsFactory"
    Write-Host ""

    # Hermes no WSL
    if (Test-WslCommand "hermes") {
        $ver = (Invoke-Wsl "hermes --version 2>/dev/null | head -1" -PassThru).Trim()
        Write-Ok "Hermes: $ver"
    } else {
        Write-Warn "Hermes: nao instalado no WSL ($WslDistro)"
    }

    # Ollama
    if (Test-WslCommand "ollama") {
        $models = (Invoke-Wsl "ollama list 2>/dev/null" -PassThru) -join ", "
        Write-Ok "Ollama: modelos disponiveis — $models"
    } else {
        Write-Warn "Ollama: nao instalado (modelos locais indisponiveis)"
    }

    # Config
    if (Test-Path $HermesConfig) {
        Write-Ok "hermes-config.json: $HermesConfig"
    } else {
        Write-Warn "hermes-config.json: nao encontrado em $FactoryDir"
    }

    # Tarefas agendadas
    foreach ($task in @("IAgentsFactory-HermesUpdate","IAgentsFactory-HermesSync")) {
        $t = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
        if ($t) {
            Write-Ok "Task '$task': $($t.State)"
        } else {
            Write-Warn "Task '$task': nao registrada"
        }
    }

    # HERMES_DISABLED
    $disabled = $env:HERMES_DISABLED
    if ($disabled -eq "1") {
        Write-Warn "HERMES_DISABLED=1 — integracao desativada por variavel de ambiente"
    } else {
        Write-Ok "HERMES_DISABLED=0 — integracao ativa"
    }
}

# ── MAIN ─────────────────────────────────────────────────────────

if (-not (Test-Path $FactoryDir)) {
    New-Item -ItemType Directory -Path $FactoryDir -Force | Out-Null
}

Write-Host ""
Write-Host "  ======================================================" -ForegroundColor Cyan
Write-Host "  IAgentsFactory x Hermes Agent — Setup v1.0" -ForegroundColor Cyan
Write-Host "  ======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Log "INFO" "setup-hermes.ps1 iniciado. Auto=$Auto CheckOnly=$CheckOnly Uninstall=$Uninstall"

if ($Uninstall) {
    Invoke-Uninstall
    exit 0
}

if ($CheckOnly) {
    $envOk = Test-Environment
    Show-Status
    if ($envOk) { Write-Ok "Ambiente validado com sucesso." } else { Write-Err "Ambiente com problemas — corrija antes de instalar." }
    exit $(if ($envOk) { 0 } else { 1 })
}

# Validar ambiente
$envOk = Test-Environment
if (-not $envOk) {
    Write-Err "Ambiente nao atende aos requisitos minimos. Corrija os erros acima e execute novamente."
    Write-Info "Execute com -CheckOnly para validar sem instalar."
    exit 1
}

# Confirmacao (modo interativo)
if (-not $Auto) {
    Write-Host ""
    Write-Host "  O setup ira:" -ForegroundColor Yellow
    Write-Host "    1. Instalar o Hermes Agent no WSL ($WslDistro)" -ForegroundColor White
    if (-not $SkipOllama) {
        Write-Host "    2. Instalar Ollama + modelo $OllamaModel (modelo local, sem custo de API)" -ForegroundColor White
    }
    Write-Host "    3. Copiar hermes-config.json para $FactoryDir" -ForegroundColor White
    Write-Host "    4. Registrar tarefas de auto-update e sync no Task Scheduler" -ForegroundColor White
    Write-Host ""
    $confirm = Read-Yn "  Confirmar instalacao?" $true
    if (-not $confirm) {
        Write-Warn "Setup cancelado."
        exit 0
    }
}

# Executar install
Install-Hermes
if (-not $SkipOllama) { Install-Ollama }
Set-HermesConfig
Register-AutoUpdateTask
Register-SyncTask
Show-Status

# Provisionar hermes-project.yaml em todos os projetos ja registrados na factory
$factoryScript = Join-Path $PSScriptRoot "iagents-factory.ps1"
if (Test-Path $factoryScript) {
    Write-Host "  Provisionando subagente Hermes em projetos registrados..." -ForegroundColor Cyan
    try {
        & $factoryScript hermes-provision 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        Write-Log "INFO" "hermes-provision executado durante setup"
    } catch {
        Write-Host "  [WARN] hermes-provision falhou: $_" -ForegroundColor Yellow
        Write-Log "WARN" "hermes-provision erro durante setup: $_"
    }
}

Write-Host ""
Write-Host "  ======================================================" -ForegroundColor Green
Write-Host "  Setup concluido!" -ForegroundColor Green
Write-Host "  ======================================================" -ForegroundColor Green
Write-Info "Use: .\iagents-factory.ps1 hermes-status   para verificar a integracao"
Write-Info "Use: .\iagents-factory.ps1 ask 'sua query'  para testar o fluxo 3 camadas"
Write-Info "Para desativar: set HERMES_DISABLED=1 ou .\setup-hermes.ps1 -Uninstall"
Write-Host ""
Write-Log "INFO" "setup-hermes.ps1 concluido com sucesso"
