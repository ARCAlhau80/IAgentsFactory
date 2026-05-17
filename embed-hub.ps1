# ===============================================================
# IAgentsFactory - Embedding Indexer
#
# Gera e armazena embeddings vetoriais para as solucoes do
# Knowledge Hub usando a API de embeddings do Ollama local.
# Permite busca semantica (Layer 1b) - encontra "jwt" quando
# a query diz "autenticacao por token".
#
# USO:
#   .\embed-hub.ps1                     -> indexa solucoes sem embedding
#   .\embed-hub.ps1 -All                -> re-indexa tudo (force)
#   .\embed-hub.ps1 -Model nomic-embed-text
#   .\embed-hub.ps1 -DryRun             -> mostra o que seria indexado
#   .\embed-hub.ps1 -Silent             -> para Task Scheduler
# ===============================================================

param(
    [switch]$All,
    [string]$Model  = "",
    [switch]$DryRun,
    [switch]$Silent
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
$ConfigPath   = Join-Path $FactoryDir "hermes-config.json"
$EmbedLog     = Join-Path $FactoryDir "embed-hub.log"

function Write-E   { param([string]$T) if (-not $Silent) { Write-Host "  [EMBED] $T" -ForegroundColor Cyan } }
function Write-Ok  { param([string]$T) if (-not $Silent) { Write-Host "  [OK] $T"    -ForegroundColor Green } }
function Write-Warn{ param([string]$T) if (-not $Silent) { Write-Host "  [WARN] $T"  -ForegroundColor Yellow } }
function Write-Err { param([string]$T) if (-not $Silent) { Write-Host "  [ERR] $T"   -ForegroundColor Red } }
function Write-Info{ param([string]$T) if (-not $Silent) { Write-Host "  $T"         -ForegroundColor DarkGray } }

function Write-Log {
    param([string]$Level, [string]$Msg)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $EmbedLog -Value "[$ts][$Level] $Msg" -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Get-SqliteCmd {
    $cmd = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-OllamaUrl {
    if (Test-Path $ConfigPath) {
        try {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($cfg.local_model.ollama_url) { return $cfg.local_model.ollama_url }
        } catch {}
    }
    return "http://localhost:11434"
}

function Get-EmbedModel {
    if ($Model) { return $Model }
    if (Test-Path $ConfigPath) {
        try {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            if ($cfg.local_model.embed_model) { return $cfg.local_model.embed_model }
        } catch {}
    }
    return "nomic-embed-text"
}

function Test-OllamaAvailable {
    param([string]$Url, [string]$EmbedModel)
    try {
        $tags = Invoke-RestMethod -Uri "$Url/api/tags" -TimeoutSec 4 -ErrorAction Stop
        $names = $tags.models | ForEach-Object { $_.name }
        $found = $names | Where-Object { $_ -eq $EmbedModel -or $_ -like "$EmbedModel`:*" }
        if (-not $found) {
            Write-Warn "Modelo '$EmbedModel' nao encontrado no Ollama."
            Write-Info "Instale com: ollama pull $EmbedModel"
            Write-Info "Modelos disponiveis: $($names -join ', ')"
            return $false
        }
        return $true
    } catch {
        Write-Err "Ollama nao acessivel em $Url : $_"
        return $false
    }
}

function Get-Embedding {
    param([string]$Text, [string]$Url, [string]$EmbedModel)
    $body = @{ model = $EmbedModel; prompt = $Text } | ConvertTo-Json -Compress
    try {
        $resp = Invoke-RestMethod -Uri "$Url/api/embeddings" `
                    -Method POST -Body $body -ContentType "application/json" `
                    -TimeoutSec 30 -ErrorAction Stop
        return $resp.embedding
    } catch {
        Write-Log "WARN" "Embedding falhou: $_"
        return $null
    }
}

# -- MAIN ---------------------------------------------------------

if (-not $Silent) {
    Write-Host ""
    Write-Host "  IAgentsFactory - Embedding Indexer" -ForegroundColor Cyan
    Write-Host "  ----------------------------------" -ForegroundColor DarkGray
}

$sqlite = Get-SqliteCmd
if (-not $sqlite) {
    Write-Err "sqlite3 nao encontrado. Instale via: winget install sqlite.sqlite"
    exit 1
}
if (-not (Test-Path $DB_PATH)) {
    Write-Err "Knowledge Hub nao encontrado: $DB_PATH"
    Write-Info "Execute primeiro: .\iagents-factory.ps1 init"
    exit 1
}

$ollamaUrl  = Get-OllamaUrl
$embedModel = Get-EmbedModel

Write-E "Modelo de embedding: $embedModel"
Write-E "Ollama URL: $ollamaUrl"

if (-not (Test-OllamaAvailable -Url $ollamaUrl -EmbedModel $embedModel)) {
    exit 1
}

# Garantir que a tabela solution_embeddings existe
$createTable = 'CREATE TABLE IF NOT EXISTS solution_embeddings (' +
    'solution_id TEXT PRIMARY KEY,' +
    'model TEXT NOT NULL,' +
    'embedding TEXT NOT NULL,' +
    'dimensions INTEGER,' +
    "created_at TEXT DEFAULT (datetime('now','localtime'))" +
    ');'
& $sqlite $DB_PATH $createTable 2>$null | Out-Null

# Buscar solucoes para indexar
if ($All) {
    $selectSql = 'SELECT id, solution_summary, solution_content, prompt_used FROM learned_solutions WHERE is_deprecated = 0 ORDER BY quality_score DESC;'
    Write-E "Modo: re-indexar TODAS as solucoes"
} else {
    $selectSql = 'SELECT ls.id, ls.solution_summary, ls.solution_content, ls.prompt_used ' +
                 'FROM learned_solutions ls ' +
                 'LEFT JOIN solution_embeddings se ON se.solution_id = ls.id ' +
                 'WHERE ls.is_deprecated = 0 AND se.solution_id IS NULL ' +
                 'ORDER BY ls.quality_score DESC;'
    Write-E "Modo: indexar apenas novas solucoes (sem embedding)"
}

$rows = & $sqlite -separator "|SEP|" $DB_PATH $selectSql 2>$null
if (-not $rows) {
    Write-Ok "Nenhuma solucao nova para indexar. Hub ja esta atualizado."
    exit 0
}

$rowList = @($rows)
Write-E "Solucoes para indexar: $($rowList.Count)"
Write-Log "INFO" "Iniciando indexacao: modelo=$embedModel total=$($rowList.Count) all=$All"

if ($DryRun) {
    Write-Warn "[DRY RUN] $($rowList.Count) solucoes seriam indexadas. Nenhuma alteracao feita."
    exit 0
}

$done  = 0
$erros = 0

foreach ($row in $rowList) {
    $cols    = [string]$row -split '\|SEP\|', 4
    $id      = $cols[0].Trim()
    $summary = $cols[1].Trim()
    $content = $cols[2].Trim()
    $prompt  = if ($cols.Count -gt 3) { $cols[3].Trim() } else { "" }

    if (-not $id) { continue }

    # Texto para embedding: summary + primeiros 500 chars do content
    $textForEmbed = "$summary $($content.Substring(0, [Math]::Min(500, $content.Length)))"
    if ($prompt) { $textForEmbed = "$prompt $textForEmbed" }

    Write-E "[$($done+1)/$($rowList.Count)] $id ..."

    $embedding = Get-Embedding -Text $textForEmbed -Url $ollamaUrl -EmbedModel $embedModel
    if (-not $embedding) {
        Write-Warn "Embedding falhou para $id - pulando"
        $erros++
        continue
    }

    $dims       = $embedding.Count
    $embJson    = ($embedding | ConvertTo-Json -Compress)
    $safeJson   = $embJson.Replace("'", "''")
    $safeModel  = $embedModel.Replace("'", "''")

    $insertSql = "INSERT OR REPLACE INTO solution_embeddings (solution_id, model, embedding, dimensions) VALUES ('$id', '$safeModel', '$safeJson', $dims);"
    & $sqlite $DB_PATH $insertSql 2>$null | Out-Null

    $done++
}

Write-Host ""
Write-Ok "Indexacao concluida. Indexados: $done | Erros: $erros"
Write-Info "Total no indice: $(& $sqlite $DB_PATH 'SELECT COUNT(*) FROM solution_embeddings;' 2>$null)"
Write-Log "INFO" "Indexacao concluida: done=$done erros=$erros"

if ($done -gt 0) {
    Write-Host ""
    Write-Host "  Busca semantica ativa. Teste com:" -ForegroundColor Yellow
    Write-Host "    .\iagents-factory.ps1 ask 'sua consulta'" -ForegroundColor White
    Write-Host "  Layer 1b responde mesmo com palavras diferentes." -ForegroundColor DarkGray
}
