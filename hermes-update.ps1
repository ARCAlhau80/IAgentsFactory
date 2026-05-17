# ===============================================================
# IAgentsFactory - Hermes Auto-Update
#
# Verifica e aplica atualizacoes do Hermes Agent automaticamente.
# Executado diariamente via Task Scheduler (06:00).
#
# USO:
#   .\hermes-update.ps1            -> Verificar e atualizar se necessario
#   .\hermes-update.ps1 -CheckOnly -> Apenas verifica versao
#   .\hermes-update.ps1 -Force     -> Atualiza sem perguntar
#   .\hermes-update.ps1 -Silent    -> Sem output (Task Scheduler)
#   .\hermes-update.ps1 -Rollback  -> Restaura backup anterior
# ===============================================================

param(
    [switch]$CheckOnly,
    [switch]$Force,
    [switch]$Silent,
    [switch]$Rollback
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding  = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {}

$FactoryDir    = Join-Path $env:USERPROFILE ".iagents-factory"
$HermesConfig  = Join-Path $FactoryDir "hermes-config.json"
$UpdateLog     = Join-Path $FactoryDir "hermes-update.log"
$UpdateState   = Join-Path $FactoryDir "hermes-update-state.json"
$BackupDir     = Join-Path $FactoryDir "hermes-backups"
$WslDistro     = "Ubuntu"

function Write-U   { param([string]$T) if (-not $Silent) { Write-Host "  [UPDATE] $T" -ForegroundColor Cyan } }
function Write-Ok  { param([string]$T) if (-not $Silent) { Write-Host "  [OK] $T" -ForegroundColor Green } }
function Write-Warn{ param([string]$T) if (-not $Silent) { Write-Host "  [WARN] $T" -ForegroundColor Yellow } }
function Write-Err { param([string]$T) if (-not $Silent) { Write-Host "  [ERR] $T" -ForegroundColor Red } }
function Write-Info{ param([string]$T) if (-not $Silent) { Write-Host "  $T" -ForegroundColor DarkGray } }

function Write-Log {
    param([string]$Level, [string]$Msg)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $UpdateLog -Value "[$ts][$Level] $Msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-Config {
    if (Test-Path $HermesConfig) {
        return Get-Content $HermesConfig -Raw | ConvertFrom-Json
    }
    return [PSCustomObject]@{
        hermes = [PSCustomObject]@{
            auto_update      = $true
            backup_before_update = $true
            update_check_interval_hours = 24
        }
    }
}

function Get-LastCheckTime {
    if (Test-Path $UpdateState) {
        try {
            $s = Get-Content $UpdateState -Raw | ConvertFrom-Json
            return [datetime]$s.last_check
        } catch {}
    }
    return [datetime]"2000-01-01"
}

function Save-UpdateState {
    param([string]$CurrentVersion, [string]$LatestVersion, [bool]$Updated)
    $state = [PSCustomObject]@{
        last_check      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        current_version = $CurrentVersion
        latest_version  = $LatestVersion
        last_update     = if ($Updated) { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
    }
    $state | ConvertTo-Json | Set-Content $UpdateState -Encoding UTF8
}

function Invoke-Wsl {
    param([string]$Cmd)
    $out = wsl -d $WslDistro -- bash -c $Cmd 2>&1
    return [PSCustomObject]@{ Output = ($out -join "`n"); Success = ($LASTEXITCODE -eq 0) }
}

function Test-WslHermes {
    if ($env:HERMES_DISABLED -eq "1") { return $false }
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return $false }
    $out = wsl -d $WslDistro -- bash -c "command -v hermes 2>/dev/null" 2>$null
    return ($out -and $out.Trim() -ne "")
}

function Get-InstalledVersion {
    $r = Invoke-Wsl "hermes --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1"
    if ($r.Success -and $r.Output.Trim()) {
        return $r.Output.Trim()
    }
    return "0.0.0"
}

function Get-LatestVersion {
    # Tenta via API do GitHub (Nous Research)
    try {
        $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/NousResearch/hermes-agent/releases/latest" `
                    -Headers @{ "User-Agent" = "IAgentsFactory-Updater" } -TimeoutSec 10 -ErrorAction Stop
        return $resp.tag_name -replace '^v',''
    } catch {}

    # Fallback: tenta via install script header
    try {
        $script = Invoke-WebRequest -Uri "https://hermes-agent.nousresearch.com/install.sh" `
                      -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        $match = [regex]::Match($script.Content, 'VERSION[=:]\s*["\x27]?(\d+\.\d+\.\d+)')
        if ($match.Success) { return $match.Groups[1].Value }
    } catch {}

    return $null
}

function Compare-Versions {
    param([string]$Current, [string]$Latest)
    try {
        $c = [version]$Current
        $l = [version]$Latest
        return $l -gt $c
    } catch {
        return $false
    }
}

function Backup-HermesConfig {
    Write-U "Fazendo backup da configuracao atual..."
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $backupFile = Join-Path $BackupDir "hermes-config-$timestamp.json"

    if (Test-Path $HermesConfig) {
        Copy-Item $HermesConfig $backupFile -Force
        Write-Ok "Backup: $backupFile"
        Write-Log "INFO" "Backup criado: $backupFile"
    }

    # Exportar memoria do Hermes como backup
    $memBackup = Join-Path $BackupDir "hermes-memory-$timestamp.json"
    $wslPath = "/tmp/hermes_backup_$timestamp.json"
    Invoke-Wsl "hermes memory export --format json --output '$wslPath' 2>/dev/null || echo '{}' > '$wslPath'" | Out-Null
    $winPath = "\\wsl$\Ubuntu\tmp\hermes_backup_$timestamp.json"
    if (Test-Path $winPath -ErrorAction SilentlyContinue) {
        Copy-Item $winPath $memBackup -Force
        Write-Ok "Backup de memoria: $memBackup"
    }

    # Manter apenas os 5 backups mais recentes
    $backups = Get-ChildItem $BackupDir -Filter "hermes-config-*.json" | Sort-Object CreationTime -Descending
    if ($backups.Count -gt 5) {
        $backups | Select-Object -Skip 5 | Remove-Item -Force
    }

    return $backupFile
}

function Restore-Backup {
    Write-U "Restaurando backup anterior..."
    $backups = Get-ChildItem $BackupDir -Filter "hermes-config-*.json" -ErrorAction SilentlyContinue |
               Sort-Object CreationTime -Descending
    if (-not $backups) {
        Write-Err "Nenhum backup encontrado em $BackupDir"
        return
    }
    $latest = $backups | Select-Object -First 1
    Copy-Item $latest.FullName $HermesConfig -Force
    Write-Ok "Backup restaurado: $($latest.Name)"
    Write-Log "INFO" "Rollback: $($latest.FullName)"
}

function Update-Hermes {
    param([string]$CurrentVersion)

    Write-U "Atualizando Hermes $CurrentVersion -> ultima versao..."
    Write-Log "INFO" "Iniciando update do Hermes"

    $cfg = Get-Config
    if ([bool]$cfg.hermes.backup_before_update) {
        Backup-HermesConfig | Out-Null
    }

    # Executar o instalador oficial (idempotente — atualiza se ja instalado)
    $result = Invoke-Wsl "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash 2>&1"
    Write-Log "INFO" "Update output: $($result.Output.Substring(0,[Math]::Min(300,$result.Output.Length)))"

    $newVersion = Get-InstalledVersion
    if ($newVersion -ne $CurrentVersion) {
        Write-Ok "Hermes atualizado: $CurrentVersion -> $newVersion"
        Write-Log "INFO" "Update bem-sucedido: $CurrentVersion -> $newVersion"
        return $newVersion
    } else {
        Write-Warn "Versao nao alterada apos update — pode ja estar na ultima versao"
        Write-Log "WARN" "Versao igual apos update: $newVersion"
        return $newVersion
    }
}

function Send-Notification {
    param([string]$Message)
    # Notificacao via Windows Toast
    try {
        $notify = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
        $template = [Windows.UI.Notifications.ToastTemplateType]::ToastText01
        $toastXml = $notify::GetTemplateContent($template)
        $toastXml.GetElementsByTagName("text").Item(0).AppendChild($toastXml.CreateTextNode($Message)) | Out-Null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
        $notify::CreateToastNotifier("IAgentsFactory").Show($toast)
    } catch {}

    # Fallback: log apenas
    Write-Log "NOTIFY" $Message
}

# ── MAIN ─────────────────────────────────────────────────────────

Write-Log "INFO" "hermes-update.ps1 iniciado. CheckOnly=$CheckOnly Force=$Force Rollback=$Rollback"

if ($Rollback) {
    Restore-Backup
    exit 0
}

if (-not (Test-WslHermes)) {
    if (-not $CheckOnly) {
        Write-Warn "Hermes nao instalado ou desabilitado (HERMES_DISABLED=$($env:HERMES_DISABLED))"
        Write-Info "Execute: .\setup-hermes.ps1 para instalar"
    }
    Write-Log "WARN" "Hermes nao disponivel — update ignorado"
    exit 1
}

# Verificar intervalo de checagem
$cfg = Get-Config
$intervalHours = [int]($cfg.hermes.update_check_interval_hours ?? 24)
$lastCheck = Get-LastCheckTime
$hoursSince = ((Get-Date) - $lastCheck).TotalHours

if (-not $Force -and -not $CheckOnly -and $hoursSince -lt $intervalHours) {
    Write-Info "Ultima verificacao ha $([Math]::Round($hoursSince,1))h — intervalo configurado: ${intervalHours}h. Pulando."
    Write-Log "INFO" "Dentro do intervalo — update ignorado"
    exit 0
}

# Checar versoes
$currentVersion = Get-InstalledVersion
Write-U "Versao atual: $currentVersion"
Write-Log "INFO" "Versao atual: $currentVersion"

$latestVersion = Get-LatestVersion
if (-not $latestVersion) {
    Write-Warn "Nao foi possivel verificar a ultima versao (sem acesso a internet ou API indisponivel)"
    Write-Log "WARN" "Impossivel obter ultima versao — verificar conexao"
    Save-UpdateState -CurrentVersion $currentVersion -LatestVersion "unknown" -Updated $false
    exit 1
}

Write-U "Ultima versao disponivel: $latestVersion"

$needsUpdate = Compare-Versions -Current $currentVersion -Latest $latestVersion

if ($CheckOnly) {
    if ($needsUpdate) {
        Write-Warn "Atualizacao disponivel: $currentVersion -> $latestVersion"
        Write-Info "Execute: .\hermes-update.ps1 para atualizar"
    } else {
        Write-Ok "Hermes esta na versao mais recente ($currentVersion)"
    }
    Save-UpdateState -CurrentVersion $currentVersion -LatestVersion $latestVersion -Updated $false
    exit 0
}

if (-not $needsUpdate) {
    Write-Ok "Hermes ja esta na versao mais recente ($currentVersion)"
    Save-UpdateState -CurrentVersion $currentVersion -LatestVersion $latestVersion -Updated $false
    exit 0
}

# Auto-update
$autoUpdate = [bool]($cfg.hermes.auto_update ?? $true)
if (-not $autoUpdate -and -not $Force) {
    Write-Warn "Atualizacao disponivel ($currentVersion -> $latestVersion) mas auto_update=false"
    Write-Info "Execute: .\hermes-update.ps1 -Force para atualizar manualmente"
    Send-Notification "IAgentsFactory: Hermes $latestVersion disponivel. Execute hermes-update.ps1 -Force"
    Save-UpdateState -CurrentVersion $currentVersion -LatestVersion $latestVersion -Updated $false
    exit 0
}

# Executar update
$newVersion = Update-Hermes -CurrentVersion $currentVersion
Save-UpdateState -CurrentVersion $newVersion -LatestVersion $latestVersion -Updated $true
Send-Notification "IAgentsFactory: Hermes atualizado para $newVersion"

Write-Ok "Update concluido. Versao ativa: $newVersion"
Write-Log "INFO" "Update concluido: $newVersion"
