# ===============================================================
# IAgentsFactory - Hermes Bridge (Fluxo 3 Camadas)
#
# Orquestra o fluxo de resolucao:
#   Camada 1: Knowledge Hub local (SQLite, 0 tokens)
#   Camada 2: Hermes + modelo Ollama local (0 custo externo)
#   Camada 3: Provider externo (Claude/GPT, custo medido)
#
# Todo resultado das camadas 2 e 3 e capturado automaticamente
# no Knowledge Hub para eliminar chamadas redundantes no futuro.
#
# USO:
#   .\hermes-bridge.ps1 -Query "como implementar jwt em fastapi"
#   .\hermes-bridge.ps1 -Query "..." -Domain auth -Project meu-projeto
#   .\hermes-bridge.ps1 -Query "..." -ForceLayer 2
#   .\hermes-bridge.ps1 -Query "..." -DryRun
# ===============================================================

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Query,

    [string]$Domain       = "",
    [string]$Project      = "",
    [string]$Language     = "",
    [string]$Framework    = "",
    [ValidateRange(1,3)]
    [int]$ForceLayer      = 0,
    [switch]$DryRun,
    [switch]$Silent,
    [switch]$JsonOutput
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding  = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {}

$FactoryRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$FactoryDir    = Join-Path $env:USERPROFILE ".iagents-factory"
$DB_PATH       = Join-Path $FactoryDir "knowledge.db"
$HermesConfig  = Join-Path $FactoryDir "hermes-config.json"
$BridgeLog     = Join-Path $FactoryDir "bridge.log"

# ── Helpers ─────────────────────────────────────────────────────

function Write-B   { param([string]$T) if (-not $Silent) { Write-Host "  [BRIDGE] $T" -ForegroundColor Magenta } }
function Write-Ok  { param([string]$T) if (-not $Silent) { Write-Host "  [OK] $T" -ForegroundColor Green } }
function Write-Warn{ param([string]$T) if (-not $Silent) { Write-Host "  [WARN] $T" -ForegroundColor Yellow } }
function Write-Err { param([string]$T) if (-not $Silent) { Write-Host "  [ERR] $T" -ForegroundColor Red } }
function Write-Info{ param([string]$T) if (-not $Silent) { Write-Host "  $T" -ForegroundColor DarkGray } }

function Write-Log {
    param([string]$Level, [string]$Msg)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $BridgeLog -Value "[$ts][$Level] $Msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

function New-BridgeId {
    return [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
}

function Get-Config {
    if (Test-Path $HermesConfig) {
        return Get-Content $HermesConfig -Raw | ConvertFrom-Json
    }
    # defaults
    return [PSCustomObject]@{
        resolution_flow = [PSCustomObject]@{
            local_hub_threshold          = 0.75
            hermes_local_timeout_seconds = 90
            auto_capture_hermes_responses    = $true
            auto_capture_external_responses  = $true
            min_quality_to_capture       = 0.7
        }
        hermes = [PSCustomObject]@{ enabled = $true }
        local_model = [PSCustomObject]@{ provider = "ollama"; model = "llama3.2:3b" }
    }
}

function Get-SqliteCmd {
    $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-SqlQuery {
    param([string]$Query)
    $sqlite = Get-SqliteCmd
    if (-not $sqlite) { return $null }
    return & $sqlite $DB_PATH $Query 2>$null
}

# ── Camada 1: Knowledge Hub local ───────────────────────────────

function Search-LocalHub {
    param([string]$QueryText, [string]$DomainFilter, [string]$LangFilter)

    $sqlite = Get-SqliteCmd
    if (-not $sqlite) { return $null }
    if (-not (Test-Path $DB_PATH)) { return $null }

    # Tokeniza a query para busca FTS
    $tokens = [regex]::Matches($QueryText, '[\p{L}\p{Nd}]{3,}') |
              ForEach-Object { $_.Value.ToLowerInvariant() } | Select-Object -Unique | Select-Object -First 6

    if ($tokens.Count -eq 0) { return $null }

    $ftsQuery = ($tokens | ForEach-Object { "$_*" }) -join " OR "
    $ftsQuery = $ftsQuery.Replace("'", "''")

    $whereExtra = ""
    if ($DomainFilter) { $whereExtra += " AND ls.domain = '$(($DomainFilter).Replace("'","''"))'" }
    if ($LangFilter)   { $whereExtra += " AND ls.language = '$(($LangFilter).Replace("'","''"))'" }

    $sql = @"
SELECT ls.id, ls.domain, ls.pattern, ls.language, ls.framework,
       ls.solution_summary, ls.solution_content, ls.quality_score,
       ls.source_agent, ls.source_project,
       rank AS fts_rank
FROM solutions_fts sf
JOIN learned_solutions ls ON ls.rowid = sf.rowid
WHERE solutions_fts MATCH '$ftsQuery'
  AND ls.is_deprecated = 0
  $whereExtra
ORDER BY ls.quality_score DESC, fts_rank
LIMIT 3;
"@

    $rows = & $sqlite -separator "|" $DB_PATH $sql 2>$null
    if (-not $rows) { return $null }

    $best = $rows | Select-Object -First 1
    if (-not $best) { return $null }

    $cols = [string]$best -split '\|', 11
    if ($cols.Count -lt 8) { return $null }

    return [PSCustomObject]@{
        Id             = $cols[0]
        Domain         = $cols[1]
        Pattern        = $cols[2]
        Language       = $cols[3]
        Framework      = $cols[4]
        Summary        = $cols[5]
        Content        = $cols[6]
        QualityScore   = [double]($cols[7])
        SourceAgent    = $cols[8]
        SourceProject  = $cols[9]
        Layer          = 1
        ResolvedBy     = "local-hub"
    }
}

# ── Camada 2: Hermes + Ollama local ─────────────────────────────

function Invoke-HermesLocal {
    param([string]$QueryText, [string]$ProjectCtx, [int]$TimeoutSec)

    # Verificar se Hermes esta disponivel e habilitado
    if ($env:HERMES_DISABLED -eq "1") {
        Write-B "Hermes desabilitado (HERMES_DISABLED=1)"
        return $null
    }

    $wslOk = $null -ne (Get-Command wsl -ErrorAction SilentlyContinue)
    if (-not $wslOk) {
        Write-B "WSL nao disponivel — pulando camada Hermes"
        return $null
    }

    $hermesPresent = (wsl -d Ubuntu -- bash -c "command -v hermes 2>/dev/null" 2>$null).Trim()
    if (-not $hermesPresent) {
        Write-B "Hermes nao instalado no WSL — execute setup-hermes.ps1"
        return $null
    }

    Write-B "Consultando Hermes (modelo local)..."
    Write-Log "INFO" "Hermes query: $QueryText"

    # Construir prompt com contexto da factory
    $ctxNote = if ($ProjectCtx) { " Contexto do projeto: $ProjectCtx." } else { "" }
    $safeQuery = $QueryText.Replace('"', '\"').Replace('`', '\`')
    $prompt = "Responda em portugues ou no idioma da pergunta.$ctxNote Pergunta: $safeQuery"

    # Chamada ao Hermes com timeout
    $job = Start-Job -ScriptBlock {
        param($distro, $p)
        wsl -d $distro -- bash -c "hermes ask `"$p`" 2>/dev/null" 2>&1
    } -ArgumentList @("Ubuntu", $prompt)

    $completed = Wait-Job -Job $job -Timeout $TimeoutSec
    if (-not $completed) {
        Remove-Job $job -Force
        Write-Warn "Hermes timeout (${TimeoutSec}s) — escalando para provider externo"
        Write-Log "WARN" "Hermes timeout apos ${TimeoutSec}s"
        return $null
    }

    $output = Receive-Job $job
    Remove-Job $job -Force

    if ([string]::IsNullOrWhiteSpace($output)) {
        Write-B "Hermes retornou resposta vazia"
        Write-Log "WARN" "Hermes retornou vazio"
        return $null
    }

    $outputStr = ($output -join "`n").Trim()
    if ($outputStr.Length -lt 20) {
        Write-B "Resposta do Hermes muito curta — escalando"
        return $null
    }

    Write-Log "INFO" "Hermes respondeu: $($outputStr.Substring(0, [Math]::Min(100,$outputStr.Length)))..."

    return [PSCustomObject]@{
        Content     = $outputStr
        SourceAgent = "hermes-local"
        Layer       = 2
        ResolvedBy  = "hermes-local"
    }
}

# ── Auto-captura no Knowledge Hub ───────────────────────────────

function Save-ToHub {
    param(
        [string]$QueryText,
        [string]$ResponseContent,
        [string]$SourceAgent,
        [string]$DomainHint,
        [string]$ProjectName,
        [string]$LangHint,
        [string]$FwHint,
        [int]$Layer
    )

    $sqlite = Get-SqliteCmd
    if (-not $sqlite) {
        Write-Warn "sqlite3 nao disponivel — captura automatica ignorada"
        return
    }
    if (-not (Test-Path $DB_PATH)) { return }

    # Inferir domain se nao fornecido
    $dom = if ($DomainHint) { $DomainHint } else { "general" }
    $pat = "auto-capture"
    $lang = if ($LangHint) { $LangHint } else { "" }
    $fw   = if ($FwHint)   { $FwHint }   else { "" }
    $proj = if ($ProjectName) { $ProjectName } else { "iagentsfactory" }

    # Summary: primeiros 250 chars da resposta
    $summary = ($ResponseContent -replace '[\r\n]+',' ').Trim()
    if ($summary.Length -gt 250) { $summary = $summary.Substring(0, 250) + "..." }

    # Hash para deduplicacao
    $hashInput = "$QueryText|$ResponseContent"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))).Replace('-','').ToLowerInvariant()

    # Tags automaticas baseadas em palavras da query
    $tagWords = [regex]::Matches($QueryText,'[\p{L}]{4,}') |
                ForEach-Object { $_.Value.ToLowerInvariant() } |
                Select-Object -Unique | Select-Object -First 5
    $tagsJson = '["' + ($tagWords -join '","') + '","layer' + $Layer + '"]'

    $id      = [System.Guid]::NewGuid().ToString("N").Substring(0,16)
    $safeQ   = $QueryText.Replace("'","''")
    $safeR   = $ResponseContent.Replace("'","''")
    $safeSumm = $summary.Replace("'","''")
    $safeTags = $tagsJson.Replace("'","''")
    $safeHash = $hash.Replace("'","''")

    $sql = @"
INSERT OR IGNORE INTO learned_solutions
  (id, domain, pattern, language, framework, source_project, source_agent,
   prompt_used, solution_content, solution_summary, content_hash,
   quality_score, is_validated, tags)
VALUES
  ('$id','$dom','$pat','$lang','$fw','$proj','$SourceAgent',
   '$safeQ','$safeR','$safeSumm','$safeHash',
   0.75, 0, '$safeTags');
"@

    $result = & $sqlite $DB_PATH $sql 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Resposta capturada no Knowledge Hub (layer=$Layer, agent=$SourceAgent)"
        Write-Log "INFO" "Capturado: id=$id domain=$dom agent=$SourceAgent layer=$Layer"
    } else {
        if ($result -match "UNIQUE constraint") {
            Write-Info "Resposta ja existe no Knowledge Hub (hash duplicado)"
        } else {
            Write-Log "WARN" "Erro ao capturar: $result"
        }
    }
}

# ── MAIN ─────────────────────────────────────────────────────────

$cfg = Get-Config
$threshold   = [double]$cfg.resolution_flow.local_hub_threshold
$hermesTimeout = [int]$cfg.resolution_flow.hermes_local_timeout_seconds
$autoCaptureHermes   = [bool]$cfg.resolution_flow.auto_capture_hermes_responses
$autoCaptureExternal = [bool]$cfg.resolution_flow.auto_capture_external_responses

Write-Log "INFO" "Bridge iniciado: query='$Query' domain='$Domain' project='$Project' forceLayer=$ForceLayer"

if ($DryRun) {
    Write-B "[DRY RUN] Consulta: '$Query'"
    Write-Info "Layer 1: buscaria no Knowledge Hub local"
    Write-Info "Layer 2: consultaria Hermes (Ollama local)"
    Write-Info "Layer 3: escalaria para provider externo"
    exit 0
}

$result = $null
$layerUsed = 0
$startTime = Get-Date

# ── LAYER 1: Knowledge Hub ───────────────────────────────────────
if ($ForceLayer -eq 0 -or $ForceLayer -eq 1) {
    Write-B "Layer 1: buscando no Knowledge Hub local..."
    $hubResult = Search-LocalHub -QueryText $Query -DomainFilter $Domain -LangFilter $Language

    if ($hubResult -and $hubResult.QualityScore -ge $threshold) {
        $layerUsed = 1
        $result = $hubResult
        Write-Ok "Resolucao LOCAL (score=$([Math]::Round($hubResult.QualityScore,2)), agent=$($hubResult.SourceAgent))"
        Write-Log "INFO" "Layer 1 resolveu: id=$($hubResult.Id) score=$($hubResult.QualityScore)"
    } else {
        if ($hubResult) {
            Write-B "Match local abaixo do threshold ($([Math]::Round($hubResult.QualityScore,2)) < $threshold) — escalando"
        } else {
            Write-B "Sem match local — escalando para Layer 2"
        }
    }
}

# ── LAYER 2: Hermes local ────────────────────────────────────────
if ($null -eq $result -and ($ForceLayer -eq 0 -or $ForceLayer -eq 2)) {
    Write-B "Layer 2: consultando Hermes Agent (local)..."
    $hermesResult = Invoke-HermesLocal -QueryText $Query -ProjectCtx $Project -TimeoutSec $hermesTimeout

    if ($hermesResult) {
        $layerUsed = 2
        $result = $hermesResult
        Write-Ok "Resolucao HERMES LOCAL (sem custo externo)"
        Write-Log "INFO" "Layer 2 resolveu via Hermes"

        if ($autoCaptureHermes -and -not $DryRun) {
            Save-ToHub -QueryText $Query -ResponseContent $hermesResult.Content `
                -SourceAgent "hermes-local" -DomainHint $Domain -ProjectName $Project `
                -LangHint $Language -FwHint $Framework -Layer 2
        }
    } else {
        Write-B "Hermes nao resolveu — escalando para Layer 3 (provider externo)"
    }
}

# ── LAYER 3: Provider externo ────────────────────────────────────
if ($null -eq $result -and ($ForceLayer -eq 0 -or $ForceLayer -eq 3)) {
    Write-B "Layer 3: encaminhando para provider externo..."
    Write-Warn "Esta consulta vai consumir tokens externos. Capture a resposta com:"
    Write-Info "  .\iagents-factory.ps1 capture"
    Write-Info "  ou use: .\capture-pipeline.ps1 -FromFile resposta.md"
    Write-Log "INFO" "Layer 3 acionado — nenhuma camada local resolveu"

    # Registra que precisou de external para essa query (para metricas)
    $sqlite = Get-SqliteCmd
    if ($sqlite -and (Test-Path $DB_PATH)) {
        $safeQ = $Query.Replace("'","''")
        & $sqlite $DB_PATH "INSERT INTO hermes_escalations (query, escalated_at, project) VALUES ('$safeQ', datetime('now','localtime'), '$(($Project).Replace("'","''"))') ON CONFLICT DO NOTHING;" 2>$null | Out-Null
    }

    $result = [PSCustomObject]@{
        Content    = "EXTERNAL_REQUIRED"
        Layer      = 3
        ResolvedBy = "external-provider"
    }
    $layerUsed = 3
}

# ── Output ───────────────────────────────────────────────────────

$elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

if ($JsonOutput) {
    $out = [PSCustomObject]@{
        query      = $Query
        layer_used = $layerUsed
        resolved_by = if ($result) { $result.ResolvedBy } else { "none" }
        content    = if ($result) { $result.Content } else { "" }
        elapsed_sec = $elapsed
    }
    $out | ConvertTo-Json -Depth 3
} else {
    if ($result -and $result.Content -ne "EXTERNAL_REQUIRED") {
        Write-Host ""
        Write-Host "  ─── Resposta (Layer $layerUsed) ──────────────────────────────" -ForegroundColor Cyan
        Write-Host $result.Content -ForegroundColor White
        Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host ""
        Write-Info "Resolucao: layer=$layerUsed  tempo=${elapsed}s  fonte=$($result.ResolvedBy)"
    }
}

exit $(if ($layerUsed -le 2) { 0 } else { 2 })
