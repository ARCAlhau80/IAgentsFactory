# ===============================================================
# IAgentsFactory - Hermes Memory Sync
#
# Sincroniza a memoria do Hermes Agent com o Knowledge Hub SQLite.
# Executado automaticamente via Task Scheduler (diario 06:30).
#
# USO:
#   .\hermes-sync.ps1              -> Sync bidirecional
#   .\hermes-sync.ps1 -ToHub       -> Apenas Hermes -> Hub
#   .\hermes-sync.ps1 -ToHermes    -> Apenas Hub -> Hermes (contexto)
#   .\hermes-sync.ps1 -Silent      -> Sem output (para Task Scheduler)
#   .\hermes-sync.ps1 -DryRun      -> Mostra o que faria sem executar
# ===============================================================

param(
    [switch]$ToHub,
    [switch]$ToHermes,
    [switch]$Silent,
    [switch]$DryRun
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding  = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {}

$FactoryDir   = Join-Path $env:USERPROFILE ".iagents-factory"
$DB_PATH      = Join-Path $FactoryDir "knowledge.db"
$HermesConfig = Join-Path $FactoryDir "hermes-config.json"
$SyncLog      = Join-Path $FactoryDir "hermes-sync.log"
$SyncState    = Join-Path $FactoryDir "hermes-sync-state.json"
$MemDir       = Join-Path $FactoryDir "hermes-projects"

function Write-S   { param([string]$T) if (-not $Silent) { Write-Host "  [SYNC] $T" -ForegroundColor Cyan } }
function Write-Ok  { param([string]$T) if (-not $Silent) { Write-Host "  [OK] $T" -ForegroundColor Green } }
function Write-Warn{ param([string]$T) if (-not $Silent) { Write-Host "  [WARN] $T" -ForegroundColor Yellow } }
function Write-Info{ param([string]$T) if (-not $Silent) { Write-Host "  $T" -ForegroundColor DarkGray } }

function Write-Log {
    param([string]$Level, [string]$Msg)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $SyncLog -Value "[$ts][$Level] $Msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-SqliteCmd {
    $c = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

function Get-LastSyncTime {
    if (Test-Path $SyncState) {
        try {
            $s = Get-Content $SyncState -Raw | ConvertFrom-Json
            return [datetime]$s.last_sync
        } catch {}
    }
    return [datetime]"2000-01-01"
}

function Save-SyncState {
    param([int]$Exported, [int]$Imported)
    $state = [PSCustomObject]@{
        last_sync      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        exported_count = $Exported
        imported_count = $Imported
    }
    $state | ConvertTo-Json | Set-Content $SyncState -Encoding UTF8
}

function Test-WslHermes {
    if ($env:HERMES_DISABLED -eq "1") { return $false }
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return $false }
    $out = wsl -d Ubuntu -- bash -c "command -v hermes 2>/dev/null" 2>$null
    return ($out -and $out.Trim() -ne "")
}

# ── Sync Hermes memory -> Knowledge Hub ─────────────────────────

function Sync-HermesToHub {
    Write-S "Exportando memoria do Hermes -> Knowledge Hub..."

    if (-not (Test-WslHermes)) {
        Write-Warn "Hermes nao disponivel — sync ignorado"
        return 0
    }

    $sqlite = Get-SqliteCmd
    if (-not $sqlite) {
        Write-Warn "sqlite3 nao disponivel — sync ignorado"
        return 0
    }

    # Exportar memoria do Hermes como JSON
    $exportPath = "/tmp/hermes_memory_export.json"
    $winExportPath = wsl -d Ubuntu -- bash -c "wslpath -w '$exportPath'" 2>$null
    
    $exportCmd = "hermes memory export --format json --output '$exportPath' 2>/dev/null || hermes export --json > '$exportPath' 2>/dev/null || echo '[]' > '$exportPath'"
    wsl -d Ubuntu -- bash -c $exportCmd 2>$null | Out-Null

    if (-not $winExportPath -or -not (Test-Path $winExportPath -ErrorAction SilentlyContinue)) {
        # Tentar caminho alternativo
        $winExportPath = "\\wsl$\Ubuntu\tmp\hermes_memory_export.json"
    }

    if (-not (Test-Path $winExportPath -ErrorAction SilentlyContinue)) {
        Write-Warn "Arquivo de export do Hermes nao encontrado — memoria pode estar vazia"
        Write-Log "WARN" "Export path nao encontrado: $winExportPath"
        return 0
    }

    $imported = 0
    try {
        $memories = Get-Content $winExportPath -Raw | ConvertFrom-Json
        $lastSync = Get-LastSyncTime

        foreach ($mem in $memories) {
            # Filtrar apenas memories novas desde o ultimo sync
            $memDate = try { [datetime]$mem.created_at } catch { [datetime]"2000-01-01" }
            if ($memDate -le $lastSync) { continue }

            if ($DryRun) {
                Write-Info "[DRY] Importaria: $($mem.summary ?? $mem.content.Substring(0,[Math]::Min(80,$mem.content.Length)))"
                $imported++
                continue
            }

            $content = [string]($mem.content ?? $mem.response ?? "")
            $summary = [string]($mem.summary ?? ($content -replace '[\r\n]+',' ').Substring(0,[Math]::Min(200,$content.Length)))
            $domain  = [string]($mem.domain  ?? "general")
            $lang    = [string]($mem.language ?? "")
            $agent   = "hermes-memory-sync"
            $project = [string]($mem.project  ?? "")

            if ($content.Length -lt 10) { continue }

            $sha  = [System.Security.Cryptography.SHA256]::Create()
            $hash = [BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content))).Replace('-','').ToLowerInvariant()

            $id     = [System.Guid]::NewGuid().ToString("N").Substring(0,16)
            $safeC  = $content.Replace("'","''")
            $safeS  = $summary.Replace("'","''")
            $safeH  = $hash
            $safeDom = $domain.Replace("'","''")
            $safeLang = $lang.Replace("'","''")
            $safePrj  = $project.Replace("'","''")

            $sql = "INSERT OR IGNORE INTO learned_solutions (id,domain,pattern,language,source_project,source_agent,solution_content,solution_summary,content_hash,quality_score,tags) VALUES ('$id','$safeDom','auto-capture','$safeLang','$safePrj','$agent','$safeC','$safeS','$safeH',0.75,'[\"hermes-sync\"]');"
            & $sqlite $DB_PATH $sql 2>$null | Out-Null

            if ($LASTEXITCODE -eq 0) { $imported++ }
        }
    } catch {
        Write-Log "ERR" "Erro ao processar memories do Hermes: $_"
    }

    Write-Ok "Importados $imported novos registros do Hermes para o Knowledge Hub"
    Write-Log "INFO" "Sync Hermes->Hub: $imported importados"
    return $imported
}

# ── Sync Knowledge Hub -> Hermes context ────────────────────────

function Sync-HubToHermes {
    Write-S "Injetando top solucoes do Knowledge Hub no contexto Hermes..."

    if (-not (Test-WslHermes)) {
        Write-Warn "Hermes nao disponivel — sync ignorado"
        return 0
    }

    $sqlite = Get-SqliteCmd
    if (-not $sqlite -or -not (Test-Path $DB_PATH)) { return 0 }

    # Pegar top 50 solucoes mais usadas/qualidade
    $rows = & $sqlite -separator "|||" $DB_PATH @"
SELECT domain, pattern, solution_summary, quality_score
FROM learned_solutions
WHERE is_deprecated = 0 AND quality_score >= 0.7
ORDER BY usage_count DESC, quality_score DESC
LIMIT 50;
"@ 2>$null

    if (-not $rows) {
        Write-Info "Nenhuma solucao no Hub para injetar no Hermes"
        return 0
    }

    # Salvar como arquivo de contexto para o Hermes
    $contextFile = Join-Path $MemDir "factory-hub-context.md"
    if (-not (Test-Path $MemDir)) { New-Item -ItemType Directory -Path $MemDir -Force | Out-Null }

    $lines = @("# IAgentsFactory Knowledge Hub Context", "", "Top solucoes locais para reutilizacao:", "")
    foreach ($row in $rows) {
        $cols = [string]$row -split '\|\|\|'
        if ($cols.Count -ge 3) {
            $lines += "- [$($cols[0])/$($cols[1])] $($cols[2]) (score: $($cols[3]))"
        }
    }

    if (-not $DryRun) {
        $lines | Set-Content $contextFile -Encoding UTF8

        # Tentar injetar via hermes memory add (se suportado)
        $wslCtxPath = wsl -d Ubuntu -- bash -c "wslpath '$(($contextFile -replace '\\','/'))'  2>/dev/null" 2>$null
        if ($wslCtxPath) {
            wsl -d Ubuntu -- bash -c "hermes memory add --file '$wslCtxPath' 2>/dev/null || true" 2>$null | Out-Null
        }
    }

    Write-Ok "Contexto do Hub sincronizado para Hermes ($($rows.Count) solucoes)"
    Write-Log "INFO" "Sync Hub->Hermes: $($rows.Count) solucoes sincronizadas"
    return $rows.Count
}

# ── MAIN ─────────────────────────────────────────────────────────

Write-Log "INFO" "hermes-sync.ps1 iniciado. ToHub=$ToHub ToHermes=$ToHermes DryRun=$DryRun"

$exported = 0
$imported = 0

if ($ToHub -or (-not $ToHermes)) {
    $imported = Sync-HermesToHub
}

if ($ToHermes -or (-not $ToHub)) {
    $exported = Sync-HubToHermes
}

if (-not $DryRun) {
    Save-SyncState -Exported $exported -Imported $imported
}

Write-S "Sync concluido. Importados: $imported | Injetados no Hermes: $exported"
Write-Log "INFO" "Sync concluido. imported=$imported exported=$exported"
