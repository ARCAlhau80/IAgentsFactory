# ===============================================================
# IAgentsFactory - Hermes Bridge (Fluxo 3 Camadas)
#
# Orquestra o fluxo de resolucao:
#   Camada 1: Knowledge Hub local (SQLite, 0 tokens)
#   Camada 2: Ollama Windows nativo (HTTP localhost:11434, 0 custo externo)
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

# -- Helpers -----------------------------------------------------

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
        local_model = [PSCustomObject]@{ provider = "ollama"; model = "gpt-oss:20b"; embed_model = "nomic-embed-text"; ollama_url = "http://localhost:11434"; mode = "windows-native" }
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

# -- Embedding helpers -------------------------------------

function Get-EmbeddingFromOllama {
    param([string]$Text, [string]$Url, [string]$EmbedModel)
    $body = @{ model = $EmbedModel; prompt = $Text } | ConvertTo-Json -Compress
    try {
        $resp = Invoke-RestMethod -Uri "$Url/api/embeddings" `
                    -Method POST -Body $body -ContentType "application/json" `
                    -TimeoutSec 20 -ErrorAction Stop
        return [double[]]$resp.embedding
    } catch {
        Write-Log "WARN" "Embedding falhou: $_"
        return $null
    }
}

function Get-CosineSimilarity {
    param([double[]]$A, [double[]]$B)
    $n = [Math]::Min($A.Length, $B.Length)
    $dot = 0.0; $magA = 0.0; $magB = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $dot  += $A[$i] * $B[$i]
        $magA += $A[$i] * $A[$i]
        $magB += $B[$i] * $B[$i]
    }
    if ($magA -le 0 -or $magB -le 0) { return 0.0 }
    return $dot / ([Math]::Sqrt($magA) * [Math]::Sqrt($magB))
}

function Search-VectorHub {
    param([string]$QueryText, [string]$EmbedModel, [string]$OllamaUrl, [double]$Threshold)

    $sqlite = Get-SqliteCmd
    if (-not $sqlite -or -not (Test-Path $DB_PATH)) { return $null }

    # Verificar se tabela existe e tem dados
    $count = & $sqlite $DB_PATH "SELECT COUNT(*) FROM solution_embeddings;" 2>$null
    if (-not $count -or [int]$count -eq 0) { return $null }

    # Gerar embedding da query
    $queryEmb = Get-EmbeddingFromOllama -Text $QueryText -Url $OllamaUrl -EmbedModel $EmbedModel
    if (-not $queryEmb) { return $null }

    # Carregar embeddings do Hub (max 500, melhores scores)
    $sql = @"
SELECT se.solution_id, se.embedding,
       ls.domain, ls.pattern, ls.language, ls.framework,
       REPLACE(REPLACE(COALESCE(ls.solution_summary,''),char(13),''),char(10),' '),
       REPLACE(REPLACE(COALESCE(ls.solution_content,''),char(13),''),char(10),' '),
       ls.quality_score,
       ls.source_agent, ls.source_project
FROM solution_embeddings se
JOIN learned_solutions ls ON ls.id = se.solution_id
WHERE ls.is_deprecated = 0
ORDER BY ls.quality_score DESC
LIMIT 500;
"@

    $rows = & $sqlite -separator "|VSEP|" $DB_PATH $sql 2>$null
    if (-not $rows) { return $null }

    $bestScore  = 0.0
    $bestResult = $null

    foreach ($row in @($rows)) {
        $cols = [string]$row -split '\|VSEP\|', 11
        if ($cols.Count -lt 9) { continue }

        $embJson = $cols[1].Trim()
        if (-not $embJson -or $embJson.Length -lt 5) { continue }

        try {
            $storedEmb = [double[]]($embJson | ConvertFrom-Json)
        } catch { continue }

        $sim = Get-CosineSimilarity -A $queryEmb -B $storedEmb
        if ($sim -gt $bestScore) {
            $bestScore = $sim
            $bestResult = [PSCustomObject]@{
                Id            = $cols[0]
                Domain        = $cols[2]
                Pattern       = $cols[3]
                Language      = $cols[4]
                Framework     = $cols[5]
                Summary       = $cols[6]
                Content       = $cols[7]
                QualityScore  = [double]($cols[8])
                SourceAgent   = $cols[9]
                SourceProject = $cols[10]
                Similarity    = $sim
                Layer         = 1
                ResolvedBy    = "vector-hub"
            }
        }
    }

    if ($bestResult -and $bestScore -ge $Threshold) {
        return $bestResult
    }
    return $null
}

# -- Camada 1: Knowledge Hub local -------------------------------

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

# -- Camada 2: Ollama Windows nativo (HTTP) -----------------------

function Invoke-HermesLocal {
    param([string]$QueryText, [string]$ProjectCtx, [int]$TimeoutSec)

    if ($env:HERMES_DISABLED -eq "1") {
        Write-B "Ollama desabilitado (HERMES_DISABLED=1)"
        return $null
    }

    $cfg         = Get-Config
    $ollamaUrl   = if ($cfg.local_model.ollama_url) { $cfg.local_model.ollama_url } else { "http://localhost:11434" }
    $ollamaModel = if ($cfg.local_model.model)      { $cfg.local_model.model }      else { "gpt-oss:20b" }

    # Verificar se Ollama esta rodando
    try {
        Invoke-RestMethod -Uri "$ollamaUrl/api/tags" -TimeoutSec 3 -ErrorAction Stop | Out-Null
    } catch {
        Write-B "Ollama nao disponivel em $ollamaUrl  -  pulando Layer 2"
        Write-Log "WARN" "Ollama inacessivel: $_"
        return $null
    }

    Write-B "Consultando Ollama Windows ($ollamaModel)..."
    Write-Log "INFO" "Ollama query: $QueryText"

    $ctxNote = if ($ProjectCtx) { " Contexto do projeto: $ProjectCtx." } else { "" }
    $prompt  = "Responda em portugues ou no idioma da pergunta.$ctxNote Pergunta: $QueryText"

    $body = @{
        model  = $ollamaModel
        prompt = $prompt
        stream = $false
    } | ConvertTo-Json -Compress

    try {
        $resp = Invoke-RestMethod -Uri "$ollamaUrl/api/generate" `
                    -Method POST -Body $body -ContentType "application/json" `
                    -TimeoutSec $TimeoutSec -ErrorAction Stop

        $content = [string]$resp.response
        if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 20) {
            Write-B "Ollama retornou resposta muito curta  -  escalando"
            return $null
        }

        Write-Log "INFO" "Ollama respondeu: $($content.Substring(0,[Math]::Min(100,$content.Length)))..."

        return [PSCustomObject]@{
            Content     = $content.Trim()
            SourceAgent = "ollama-windows"
            Layer       = 2
            ResolvedBy  = "ollama-windows"
        }
    } catch {
        Write-Warn "Ollama erro: $_  -  escalando para Layer 3"
        Write-Log "WARN" "Ollama erro: $_"
        return $null
    }
}

# -- Auto-captura no Knowledge Hub -------------------------------

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
        Write-Warn "sqlite3 nao disponivel  -  captura automatica ignorada"
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

        # Auto-gerar embedding da solucao capturada (se Ollama disponivel)
        $cfg2 = Get-Config
        $eUrl   = if ($cfg2.local_model.ollama_url)  { $cfg2.local_model.ollama_url }  else { "http://localhost:11434" }
        $eModel = if ($cfg2.local_model.embed_model) { $cfg2.local_model.embed_model } else { "nomic-embed-text" }
        try {
            $textForEmbed = "$QueryText $($ResponseContent.Substring(0,[Math]::Min(500,$ResponseContent.Length)))"
            $emb = Get-EmbeddingFromOllama -Text $textForEmbed -Url $eUrl -EmbedModel $eModel
            if ($emb) {
                $embJson  = ($emb | ConvertTo-Json -Compress).Replace("'","''")
                $safeEMod = $eModel.Replace("'","''")
                & $sqlite $DB_PATH "INSERT OR REPLACE INTO solution_embeddings (solution_id, model, embedding, dimensions) VALUES ('$id','$safeEMod','$embJson',$($emb.Count));" 2>$null | Out-Null
                Write-Log "INFO" "Embedding auto-gerado: id=$id dims=$($emb.Count)"
            }
        } catch {
            Write-Log "WARN" "Auto-embed falhou (nao critico): $_"
        }
    } else {
        if ($result -match "UNIQUE constraint") {
            Write-Info "Resposta ja existe no Knowledge Hub (hash duplicado)"
        } else {
            Write-Log "WARN" "Erro ao capturar: $result"
        }
    }
}

# -- MAIN ---------------------------------------------------------

$cfg = Get-Config
$threshold      = [double]$cfg.resolution_flow.local_hub_threshold
$vecThreshold   = if ($cfg.resolution_flow.vector_hub_threshold) { [double]$cfg.resolution_flow.vector_hub_threshold } else { 0.72 }
$hermesTimeout  = [int]$cfg.resolution_flow.hermes_local_timeout_seconds
$autoCaptureHermes   = [bool]$cfg.resolution_flow.auto_capture_hermes_responses
$autoCaptureExternal = [bool]$cfg.resolution_flow.auto_capture_external_responses
$ollamaUrl   = if ($cfg.local_model.ollama_url) { $cfg.local_model.ollama_url } else { "http://localhost:11434" }
$embedModel  = if ($cfg.local_model.embed_model) { $cfg.local_model.embed_model } else { "nomic-embed-text" }

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

# -- LAYER 1a: Knowledge Hub FTS5 --------------------------------
if ($ForceLayer -eq 0 -or $ForceLayer -eq 1) {
    Write-B "Layer 1a: buscando no Knowledge Hub (FTS5 keywords)..."
    $hubResult = Search-LocalHub -QueryText $Query -DomainFilter $Domain -LangFilter $Language

    if ($hubResult -and $hubResult.QualityScore -ge $threshold) {
        $layerUsed = 1
        $result = $hubResult
        Write-Ok "Resolucao FTS5 LOCAL (score=$([Math]::Round($hubResult.QualityScore,2)), agent=$($hubResult.SourceAgent))"
        Write-Log "INFO" "Layer 1a resolveu: id=$($hubResult.Id) score=$($hubResult.QualityScore)"
    } else {
        if ($hubResult) {
            Write-B "FTS5 abaixo do threshold ($([Math]::Round($hubResult.QualityScore,2)) < $threshold)  -  tentando busca vetorial"
        } else {
            Write-B "Sem match FTS5  -  tentando busca vetorial (semantica)"
        }
    }
}

# -- LAYER 1b: Knowledge Hub Vector Search ----------------------
if ($null -eq $result -and ($ForceLayer -eq 0 -or $ForceLayer -eq 1)) {
    Write-B "Layer 1b: busca vetorial (cosine similarity, threshold=$vecThreshold)..."
    $vecResult = Search-VectorHub -QueryText $Query -EmbedModel $embedModel `
                     -OllamaUrl $ollamaUrl -Threshold $vecThreshold

    if ($vecResult) {
        $layerUsed = 1
        $result = $vecResult
        Write-Ok "Resolucao VETORIAL LOCAL (sim=$([Math]::Round($vecResult.Similarity,3)), agent=$($vecResult.SourceAgent))"
        Write-Log "INFO" "Layer 1b resolveu via vector search: id=$($vecResult.Id) sim=$($vecResult.Similarity)"
    } else {
        Write-B "Sem match vetorial  -  escalando para Layer 2 (Ollama)"
    }
}

# -- LAYER 2: Ollama Windows nativo ------------------------------
if ($null -eq $result -and ($ForceLayer -eq 0 -or $ForceLayer -eq 2)) {
    Write-B "Layer 2: consultando Ollama Windows (local, sem custo externo)..."
    $hermesResult = Invoke-HermesLocal -QueryText $Query -ProjectCtx $Project -TimeoutSec $hermesTimeout

    if ($hermesResult) {
        $layerUsed = 2
        $result = $hermesResult
        Write-Ok "Resolucao OLLAMA LOCAL (sem custo externo)"
        Write-Log "INFO" "Layer 2 resolveu via Ollama Windows"

        if ($autoCaptureHermes -and -not $DryRun) {
            Save-ToHub -QueryText $Query -ResponseContent $hermesResult.Content `
                -SourceAgent "ollama-windows" -DomainHint $Domain -ProjectName $Project `
                -LangHint $Language -FwHint $Framework -Layer 2
        }
    } else {
        Write-B "Ollama nao resolveu  -  escalando para Layer 3 (provider externo)"
    }
}

# -- LAYER 3: Provider externo ------------------------------------
if ($null -eq $result -and ($ForceLayer -eq 0 -or $ForceLayer -eq 3)) {
    Write-B "Layer 3: encaminhando para provider externo..."
    Write-Warn "Esta consulta vai consumir tokens externos. Capture a resposta com:"
    Write-Info "  .\iagents-factory.ps1 capture"
    Write-Info "  ou use: .\capture-pipeline.ps1 -FromFile resposta.md"
    Write-Log "INFO" "Layer 3 acionado  -  nenhuma camada local resolveu"

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

# -- Output -------------------------------------------------------

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
        Write-Host "  --- Resposta (Layer $layerUsed) ------------------------------" -ForegroundColor Cyan
        Write-Host $result.Content -ForegroundColor White
        Write-Host "  ----------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        Write-Info "Resolucao: layer=$layerUsed  tempo=${elapsed}s  fonte=$($result.ResolvedBy)"
    }
}

exit $(if ($layerUsed -le 2) { 0 } else { 2 })
