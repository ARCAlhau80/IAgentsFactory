# ===============================================================
# IAgentsFactory — Knowledge Hub Manager
#
# Gerencia o Knowledge Hub local (SQLite + FTS5) para a
# Fábrica de Software com Memória Persistente de IA.
#
# COMANDOS:
#   .\iagents-factory.ps1 init                    -> Inicializa o Knowledge Hub
#   .\iagents-factory.ps1 register [path]         -> Registra projeto na fábrica
#   .\iagents-factory.ps1 constitution            -> Inicializa/atualiza a constituicao do projeto
#   .\iagents-factory.ps1 specify "desc"         -> Cria uma feature spec leve em specs/
#   .\iagents-factory.ps1 plan [context]          -> Gera plano tecnico da feature ativa
#   .\iagents-factory.ps1 tasks                   -> Gera tarefas e publica artefatos no Hub
#   .\iagents-factory.ps1 analyze                 -> Executa gate de validacao do workflow
#   .\iagents-factory.ps1 capture                 -> Captura solução interativamente
#   .\iagents-factory.ps1 search "query"          -> Busca soluções locais
#   .\iagents-factory.ps1 search-cross "query"    -> Busca cross-project
#   .\iagents-factory.ps1 stats                   -> Métricas de economia
#   .\iagents-factory.ps1 projects                -> Lista projetos registrados
#   .\iagents-factory.ps1 export                  -> Exporta knowledge para Git sync
#   .\iagents-factory.ps1 import [file]           -> Importa knowledge de outro dev
#   .\iagents-factory.ps1 cleanup                 -> Remove soluções stale
#   .\iagents-factory.ps1 dashboard               -> Abre dashboard MCP Graph
#   .\iagents-factory.ps1 update-pillars [path]   -> Aplica Engineering Pillars em projeto existente
#   .\iagents-factory.ps1 ask "pergunta"           -> Consulta 3 camadas: Hub local -> Hermes -> Externo
#   .\iagents-factory.ps1 hermes-status            -> Verifica status do Hermes Agent local
#   .\iagents-factory.ps1 hermes-update            -> Atualiza Hermes para a ultima versao
#   .\iagents-factory.ps1 hermes-provision [path]   -> Provisiona subagente Hermes em projetos existentes
#
# REQUER:
#   - Node.js (para MCP Graph Workflow)
#   - SQLite3 (opcional, para queries diretas)
# ===============================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("init","register","constitution","specify","plan","tasks","analyze","capture","search","search-cross","stats","projects","export","import","cleanup","dashboard","update-pillars","ask","hermes-status","hermes-update","hermes-provision","embed-index","help")]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Arg1 = "",

    [Parameter(Position=2)]
    [string]$Arg2 = "",

    [string]$Domain = "",
    [string]$Pattern = "",
    [string]$Language = "",
    [string]$Framework = "",
    [string]$DbType = "",
    [string]$Agent = "",
    [double]$Quality = 0.8,
    [string[]]$Tags = @(),
    [switch]$Force,
    [switch]$Json
)

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {
}

# --- GLOBALS -------------------------------------------------

$FACTORY_DIR = Join-Path $env:USERPROFILE ".iagents-factory"
$DB_PATH = Join-Path $FACTORY_DIR "knowledge.db"
$CONFIG_PATH = Join-Path $FACTORY_DIR "factory-config.json"
$EXPORT_DIR = Join-Path $FACTORY_DIR "exports"
$MCP_GRAPH_PATH = "C:\Users\AR CALHAU\source\repos\mcp-graph-workflow"
$DASHBOARD_CONFIG_PATH = Join-Path $PSScriptRoot "config\dashboard-config.json"
$FACTORY_DASHBOARD_SERVER = Join-Path $PSScriptRoot "tools\factory-dashboard\server.js"
$WORKFLOW_ROOT = (Get-Location).Path
$WORKFLOW_DIR = Join-Path $WORKFLOW_ROOT "specs"
$WORKFLOW_TEMPLATE_DIR = Join-Path $WORKFLOW_DIR "templates"
$WORKFLOW_MEMORY_DIR = Join-Path $WORKFLOW_DIR "memory"
$WORKFLOW_PRESET_DIR = Join-Path $WORKFLOW_DIR "presets"
$WORKFLOW_EXTENSION_DIR = Join-Path $WORKFLOW_DIR "extensions"
$ACTIVE_FEATURE_PATH = Join-Path $WORKFLOW_DIR "active-feature.json"
$ACTIVE_PRESET_PATH = Join-Path $WORKFLOW_PRESET_DIR "active-preset.json"
$EXTENSIONS_CONFIG_PATH = Join-Path $WORKFLOW_EXTENSION_DIR "extensions.json"

# --- COLORS --------------------------------------------------

function Write-Title { param([string]$Text) Write-Host "`n  $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "  [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  [WARN] $Text" -ForegroundColor Yellow }
function Write-Err { param([string]$Text) Write-Host "  [ERR] $Text" -ForegroundColor Red }
function Write-Info { param([string]$Text) Write-Host "  $Text" -ForegroundColor DarkGray }

# --- HELPERS -------------------------------------------------

function New-Id {
    return [guid]::NewGuid().ToString("N").Substring(0, 12)
}

function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

function Get-SHA256 {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha.ComputeHash($bytes)
    return [BitConverter]::ToString($hash).Replace("-","").ToLower()
}

function Convert-ToSqlLiteral {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return $Text.Replace("'", "''")
}

function New-FactoryDirectory {
    if (-not (Test-Path $FACTORY_DIR)) {
        New-Item -ItemType Directory -Path $FACTORY_DIR -Force | Out-Null
    }
    if (-not (Test-Path $EXPORT_DIR)) {
        New-Item -ItemType Directory -Path $EXPORT_DIR -Force | Out-Null
    }
}

function Get-Config {
    if (Test-Path $CONFIG_PATH) {
        return Get-Content $CONFIG_PATH -Raw | ConvertFrom-Json
    }
    return @{
        version = "1.0.0"
        created = (Get-Timestamp)
        similarity_threshold = 0.75
        default_ttl_months = 12
        auto_capture = $true
        projects = @()
    }
}

function Save-Config {
    param($Config)

    $Config | ConvertTo-Json -Depth 10 | Set-Content $CONFIG_PATH -Encoding UTF8
}

function Ensure-WorkflowStructure {
    $dirs = @(
        $WORKFLOW_DIR,
        $WORKFLOW_TEMPLATE_DIR,
        $WORKFLOW_MEMORY_DIR,
        $WORKFLOW_PRESET_DIR,
        $WORKFLOW_EXTENSION_DIR
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    if (-not (Test-Path $ACTIVE_PRESET_PATH)) {
        @{ activePreset = '' } | ConvertTo-Json | Set-Content $ACTIVE_PRESET_PATH -Encoding UTF8
    }

    if (-not (Test-Path $EXTENSIONS_CONFIG_PATH)) {
        @{ extensions = @() } | ConvertTo-Json -Depth 10 | Set-Content $EXTENSIONS_CONFIG_PATH -Encoding UTF8
    }
}

function Get-ProjectNameForWorkflow {
    $projectContext = Get-CurrentProjectContext
    if ($projectContext -and -not [string]::IsNullOrWhiteSpace([string]$projectContext.name)) {
        return [string]$projectContext.name
    }

    return (Get-Item $WORKFLOW_ROOT).Name
}

function Convert-ToFeatureSlug {
    param([string]$Text)

    $normalized = $Text.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '[^a-z0-9]+', '-')
    $normalized = $normalized.Trim('-')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return 'feature'
    }

    if ($normalized.Length -gt 48) {
        $normalized = $normalized.Substring(0, 48).Trim('-')
    }

    return $normalized
}

function Get-FeatureDirectories {
    if (-not (Test-Path $WORKFLOW_DIR)) {
        return @()
    }

    return @(Get-ChildItem -Path $WORKFLOW_DIR -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{3,}-' })
}

function Get-NextFeatureNumber {
    $maxNumber = 0
    foreach ($dir in (Get-FeatureDirectories)) {
        if ($dir.Name -match '^(\d{3,})-') {
            $value = [int]$Matches[1]
            if ($value -gt $maxNumber) {
                $maxNumber = $value
            }
        }
    }

    return ('{0:D3}' -f ($maxNumber + 1))
}

function Set-ActiveFeature {
    param([string]$FeatureDir)

    $payload = @{ activeFeature = (Resolve-Path $FeatureDir).Path }
    $payload | ConvertTo-Json | Set-Content $ACTIVE_FEATURE_PATH -Encoding UTF8
}

function Get-FeatureDirectory {
    param([string]$FeatureSelector)

    Ensure-WorkflowStructure

    if ($FeatureSelector) {
        if (Test-Path $FeatureSelector) {
            return (Resolve-Path $FeatureSelector).Path
        }

        $directPath = Join-Path $WORKFLOW_DIR $FeatureSelector
        if (Test-Path $directPath) {
            return (Resolve-Path $directPath).Path
        }

        $matches = @(Get-FeatureDirectories | Where-Object {
            $_.Name -eq $FeatureSelector -or $_.Name -like ("$FeatureSelector*")
        })

        if ($matches.Count -eq 1) {
            return $matches[0].FullName
        }
    }

    if (Test-Path $ACTIVE_FEATURE_PATH) {
        try {
            $active = Get-Content $ACTIVE_FEATURE_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($active.activeFeature -and (Test-Path $active.activeFeature)) {
                return (Resolve-Path $active.activeFeature).Path
            }
        } catch {
        }
    }

    return $null
}

function Get-ActivePresetId {
    Ensure-WorkflowStructure

    if (-not (Test-Path $ACTIVE_PRESET_PATH)) {
        return ''
    }

    try {
        $activePreset = Get-Content $ACTIVE_PRESET_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
        return [string]$activePreset.activePreset
    } catch {
        return ''
    }
}

function Resolve-WorkflowTemplatePath {
    param([string]$TemplateName)

    $presetId = Get-ActivePresetId
    if ($presetId) {
        $presetTemplate = Join-Path $WORKFLOW_PRESET_DIR (Join-Path $presetId (Join-Path 'templates' $TemplateName))
        if (Test-Path $presetTemplate) {
            return $presetTemplate
        }
    }

    $defaultTemplate = Join-Path $WORKFLOW_TEMPLATE_DIR $TemplateName
    if (-not (Test-Path $defaultTemplate)) {
        throw "Template nao encontrado: $TemplateName"
    }

    return $defaultTemplate
}

function Write-FileFromTemplate {
    param(
        [string]$TemplateName,
        [string]$DestinationPath,
        [hashtable]$Replacements
    )

    $templatePath = Resolve-WorkflowTemplatePath -TemplateName $TemplateName
    $content = Get-Content $templatePath -Raw -Encoding UTF8
    foreach ($key in $Replacements.Keys) {
        $content = $content.Replace("[$key]", [string]$Replacements[$key])
    }

    Set-Content -Path $DestinationPath -Value $content -Encoding UTF8
}

function Get-FeatureTitleFromSpec {
    param([string]$SpecPath)

    if (-not (Test-Path $SpecPath)) {
        return ''
    }

    $firstLine = Get-Content $SpecPath -Encoding UTF8 | Select-Object -First 1
    if ($firstLine -match '^#\s+(.+)$') {
        return $Matches[1].Trim()
    }

    return ''
}

function Get-FeatureSummaryFromSpec {
    param([string]$SpecPath)

    if (-not (Test-Path $SpecPath)) {
        return ''
    }

    $lines = Get-Content $SpecPath -Encoding UTF8
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed.StartsWith('#')) { continue }
        return $trimmed
    }

    return ''
}

function Get-WorkflowExtensions {
    Ensure-WorkflowStructure

    if (-not (Test-Path $EXTENSIONS_CONFIG_PATH)) {
        return @()
    }

    try {
        $extensionsConfig = Get-Content $EXTENSIONS_CONFIG_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($extensionsConfig.extensions) {
            return @($extensionsConfig.extensions | Where-Object { $_.enabled -ne $false })
        }
    } catch {
        Write-Warn 'Nao foi possivel ler specs/extensions/extensions.json. Seguindo com regras padrao.'
    }

    return @()
}

function Test-PlaceholderContent {
    param([string]$Content)

    return [regex]::IsMatch($Content, '\[[A-Z][A-Z0-9_ -]{2,}\]')
}

function Save-KnowledgeArtifact {
    param(
        [string]$ArtifactPath,
        [string]$PatternName,
        [string]$Summary,
        [string[]]$ArtifactTags
    )

    if (-not (Test-Path $ArtifactPath)) {
        return
    }

    if (-not (Test-Path $DB_PATH)) {
        Write-Warn 'Knowledge Hub nao inicializado. Execute .\iagents-factory.ps1 init antes de publicar artefatos.'
        return
    }

    $content = Get-Content -Path $ArtifactPath -Raw -Encoding UTF8
    $contentHash = Get-SHA256 -Text $content
    $existing = Invoke-Sql -Query "SELECT id FROM learned_solutions WHERE content_hash = '$contentHash';"
    if ($existing) {
        Write-Info ("Artefato ja conhecido no Hub: {0}" -f (Split-Path $ArtifactPath -Leaf))
        return
    }

    $projectName = Get-ProjectNameForWorkflow
    $tagsJson = '[' + (($ArtifactTags | ForEach-Object { '"' + ($_ -replace '"', '\\"') + '"' }) -join ',') + ']'
    $artifactId = New-Id
    $promptText = "Workflow artifact generated from $(Split-Path $ArtifactPath -Leaf)"
    $tokensInput = [math]::Ceiling($promptText.Length / 4)
    $tokensOutput = [math]::Ceiling($content.Length / 4)

    $sql = @"
INSERT INTO learned_solutions
    (id, domain, pattern, language, framework, source_project, source_agent,
     prompt_used, solution_content, solution_summary, content_hash,
     quality_score, tokens_input, tokens_output, tags)
VALUES
    ('$artifactId',
     'factory-governance',
     '$(Convert-ToSqlLiteral $PatternName)',
     'markdown',
     'spec-workflow',
     '$(Convert-ToSqlLiteral $projectName)',
     'iagentsfactory-workflow',
     '$(Convert-ToSqlLiteral $promptText)',
     '$(Convert-ToSqlLiteral $content)',
     '$(Convert-ToSqlLiteral $Summary)',
     '$contentHash',
     0.86,
     $tokensInput,
     $tokensOutput,
     '$(Convert-ToSqlLiteral $tagsJson)');
"@

    Invoke-Sql -Query $sql | Out-Null
    Write-Ok ("Artefato publicado no Knowledge Hub: {0}" -f (Split-Path $ArtifactPath -Leaf))
}

function Invoke-AnalyzeFeature {
    param(
        [string]$FeatureSelector,
        [switch]$Quiet
    )

    Ensure-WorkflowStructure

    $featureDir = Get-FeatureDirectory -FeatureSelector $FeatureSelector
    if (-not $featureDir) {
        if (-not $Quiet) {
            Write-Err 'Nenhuma feature ativa encontrada. Execute primero .\iagents-factory.ps1 specify "descricao".'
        }
        return $false
    }

    $checks = @()
    $defaultRequiredSections = @{
        'constitution.md' = @('## Purpose', '## Core Principles', '## Delivery Rules')
        'spec.md' = @('## Overview', '## Goals', '## User Stories', '## Functional Requirements', '## Success Criteria')
        'plan.md' = @('## Summary', '## Technical Context', '## Implementation Slices', '## Validation Gate')
        'tasks.md' = @('## Phase 1', '## Phase 2', '## Phase 3')
    }
    $requiredFiles = @(
        (Join-Path $WORKFLOW_MEMORY_DIR 'constitution.md'),
        (Join-Path $featureDir 'spec.md'),
        (Join-Path $featureDir 'plan.md'),
        (Join-Path $featureDir 'tasks.md')
    )

    foreach ($extension in (Get-WorkflowExtensions)) {
        foreach ($artifact in @($extension.requiredArtifacts)) {
            $candidate = if ([System.IO.Path]::IsPathRooted([string]$artifact)) { [string]$artifact } else { Join-Path $featureDir ([string]$artifact) }
            if ($requiredFiles -notcontains $candidate) {
                $requiredFiles += $candidate
            }
        }

        if ($extension.requiredSections) {
            foreach ($property in $extension.requiredSections.PSObject.Properties) {
                $fileKey = [string]$property.Name
                $values = @($property.Value)
                if (-not $defaultRequiredSections.ContainsKey($fileKey)) {
                    $defaultRequiredSections[$fileKey] = @()
                }
                $defaultRequiredSections[$fileKey] += $values
            }
        }
    }

    foreach ($filePath in $requiredFiles) {
        $leaf = Split-Path $filePath -Leaf
        if (-not (Test-Path $filePath)) {
            $checks += [pscustomobject]@{ Status = 'FAIL'; Message = "Arquivo obrigatorio ausente: $leaf" }
            continue
        }

        $content = Get-Content $filePath -Raw -Encoding UTF8
        if (Test-PlaceholderContent -Content $content) {
            $checks += [pscustomobject]@{ Status = 'FAIL'; Message = "Placeholders ainda presentes em: $leaf" }
        } else {
            $checks += [pscustomobject]@{ Status = 'PASS'; Message = "Sem placeholders pendentes em: $leaf" }
        }

        if ($defaultRequiredSections.ContainsKey($leaf)) {
            foreach ($section in @($defaultRequiredSections[$leaf] | Select-Object -Unique)) {
                if ($content -notmatch [regex]::Escape($section)) {
                    $checks += [pscustomobject]@{ Status = 'FAIL'; Message = "Secao ausente em ${leaf}: $section" }
                }
            }
        }

        if ($leaf -eq 'tasks.md' -and $content -notmatch '\- \[ \] T\d{3}') {
            $checks += [pscustomobject]@{ Status = 'FAIL'; Message = 'tasks.md nao contem tarefas no formato checklist.' }
        }
    }

    $hasFailures = @($checks | Where-Object { $_.Status -eq 'FAIL' }).Count -gt 0
    if (-not $Quiet) {
        Write-Title 'Gate de Analise do Workflow'
        Write-Info ("Feature: {0}" -f (Split-Path $featureDir -Leaf))
        foreach ($check in $checks) {
            if ($check.Status -eq 'PASS') {
                Write-Ok $check.Message
            } else {
                Write-Warn $check.Message
            }
        }

        if ($hasFailures) {
            Write-Warn 'Gate reprovado. Corrija os artefatos antes de implementar ou capturar.'
        } else {
            Write-Ok 'Gate aprovado. A feature esta pronta para implementacao e publicacao no Hub.'
        }
    }

    return (-not $hasFailures)
}

function Publish-WorkflowArtifacts {
    param([string]$FeatureDir)

    if (-not (Invoke-AnalyzeFeature -FeatureSelector $FeatureDir -Quiet)) {
        Write-Warn 'Publicacao no Knowledge Hub cancelada porque o gate de analise falhou.'
        return
    }

    $featureName = Split-Path $FeatureDir -Leaf
    Save-KnowledgeArtifact -ArtifactPath (Join-Path $WORKFLOW_MEMORY_DIR 'constitution.md') -PatternName 'workflow-constitution' -Summary 'Constituicao do projeto com principios e regras de execucao da factory.' -ArtifactTags @('workflow','constitution','governance')
    Save-KnowledgeArtifact -ArtifactPath (Join-Path $FeatureDir 'spec.md') -PatternName 'workflow-spec' -Summary ("Spec funcional da feature $featureName") -ArtifactTags @('workflow','spec',$featureName)
    Save-KnowledgeArtifact -ArtifactPath (Join-Path $FeatureDir 'plan.md') -PatternName 'workflow-plan' -Summary ("Plano tecnico da feature $featureName") -ArtifactTags @('workflow','plan',$featureName)
    Save-KnowledgeArtifact -ArtifactPath (Join-Path $FeatureDir 'tasks.md') -PatternName 'workflow-tasks' -Summary ("Quebra de execucao da feature $featureName") -ArtifactTags @('workflow','tasks',$featureName)
}

function Invoke-Constitution {
    Ensure-WorkflowStructure

    $constitutionPath = Join-Path $WORKFLOW_MEMORY_DIR 'constitution.md'
    if (-not (Test-Path $constitutionPath)) {
        Write-Err 'Constitution nao encontrada em specs/memory/constitution.md.'
        return
    }

    if ($Arg1) {
        $content = Get-Content $constitutionPath -Raw -Encoding UTF8
        $focusBlock = "## Current Focus`n`n- $Arg1`n"
        if ($content -match '(?s)## Current Focus.*?(?=(\r?\n## |\z))') {
            $content = [regex]::Replace($content, '(?s)## Current Focus.*?(?=(\r?\n## |\z))', $focusBlock)
        } else {
            $content = ($content.TrimEnd() + "`n`n" + $focusBlock + "`n")
        }
        Set-Content -Path $constitutionPath -Value $content -Encoding UTF8
        Write-Ok 'Constituicao atualizada com foco atual.'
    }

    Write-Info ("Constituicao ativa: {0}" -f $constitutionPath)
}

function Invoke-Specify {
    param([string]$Description)

    Ensure-WorkflowStructure

    if (-not $Description) {
        Write-Err 'Uso: .\iagents-factory.ps1 specify "descricao da feature"'
        return
    }

    $projectName = Get-ProjectNameForWorkflow
    $title = (($Description -split '[\.!\?]')[0]).Trim()
    if (-not $title) {
        $title = $Description.Trim()
    }

    $slug = Convert-ToFeatureSlug -Text $title
    $featureNumber = Get-NextFeatureNumber
    $featureDir = Join-Path $WORKFLOW_DIR ("{0}-{1}" -f $featureNumber, $slug)
    $contractsDir = Join-Path $featureDir 'contracts'

    if (Test-Path $featureDir) {
        Write-Warn "Feature ja existe: $featureDir"
        Set-ActiveFeature -FeatureDir $featureDir
        return
    }

    New-Item -ItemType Directory -Path $featureDir -Force | Out-Null
    New-Item -ItemType Directory -Path $contractsDir -Force | Out-Null

    $replacements = @{
        PROJECT_NAME = $projectName
        FEATURE_TITLE = $title
        FEATURE_KEY = (Split-Path $featureDir -Leaf)
        FEATURE_DATE = (Get-Date).ToString('yyyy-MM-dd')
        FEATURE_DESCRIPTION = $Description.Trim()
        FEATURE_DIR = (Split-Path $featureDir -Leaf)
    }

    Write-FileFromTemplate -TemplateName 'spec-template.md' -DestinationPath (Join-Path $featureDir 'spec.md') -Replacements $replacements
    Set-ActiveFeature -FeatureDir $featureDir

    Write-Title 'Feature especificada'
    Write-Ok ("Spec criada em: {0}" -f (Join-Path $featureDir 'spec.md'))
    Write-Info 'Proximo passo: .\iagents-factory.ps1 plan "stack e restricoes tecnicas"'
}

function Invoke-Plan {
    param([string]$PlanContext)

    Ensure-WorkflowStructure

    $featureDir = Get-FeatureDirectory -FeatureSelector ''
    if (-not $featureDir) {
        Write-Err 'Nenhuma feature ativa encontrada. Execute .\iagents-factory.ps1 specify primeiro.'
        return
    }

    $specPath = Join-Path $featureDir 'spec.md'
    if (-not (Test-Path $specPath)) {
        Write-Err 'spec.md ausente para a feature ativa.'
        return
    }

    $featureTitle = Get-FeatureTitleFromSpec -SpecPath $specPath
    $featureSummary = Get-FeatureSummaryFromSpec -SpecPath $specPath
    $planNotes = if ($PlanContext) { $PlanContext } else { 'Manter desenho local-first, knowledge-first, multiprojeto e com baixa complexidade acidental.' }
    $commonReplacements = @{
        PROJECT_NAME = (Get-ProjectNameForWorkflow)
        FEATURE_TITLE = $featureTitle
        FEATURE_KEY = (Split-Path $featureDir -Leaf)
        FEATURE_DATE = (Get-Date).ToString('yyyy-MM-dd')
        FEATURE_DESCRIPTION = $featureSummary
        TECH_CONTEXT = $planNotes
    }

    Write-FileFromTemplate -TemplateName 'plan-template.md' -DestinationPath (Join-Path $featureDir 'plan.md') -Replacements $commonReplacements
    Write-FileFromTemplate -TemplateName 'research-template.md' -DestinationPath (Join-Path $featureDir 'research.md') -Replacements $commonReplacements
    Write-FileFromTemplate -TemplateName 'data-model-template.md' -DestinationPath (Join-Path $featureDir 'data-model.md') -Replacements $commonReplacements
    Write-FileFromTemplate -TemplateName 'quickstart-template.md' -DestinationPath (Join-Path $featureDir 'quickstart.md') -Replacements $commonReplacements
    Write-FileFromTemplate -TemplateName 'contracts-template.md' -DestinationPath (Join-Path (Join-Path $featureDir 'contracts') 'README.md') -Replacements $commonReplacements

    Write-Title 'Plano tecnico gerado'
    Write-Ok ("Plan criado em: {0}" -f (Join-Path $featureDir 'plan.md'))
    Write-Info 'Proximo passo: .\iagents-factory.ps1 tasks'
}

function Invoke-Tasks {
    Ensure-WorkflowStructure

    $featureDir = Get-FeatureDirectory -FeatureSelector ''
    if (-not $featureDir) {
        Write-Err 'Nenhuma feature ativa encontrada. Execute .\iagents-factory.ps1 specify primeiro.'
        return
    }

    $specPath = Join-Path $featureDir 'spec.md'
    $planPath = Join-Path $featureDir 'plan.md'
    if ((-not (Test-Path $specPath)) -or (-not (Test-Path $planPath))) {
        Write-Err 'spec.md e plan.md sao obrigatorios antes de gerar tasks.'
        return
    }

    $featureTitle = Get-FeatureTitleFromSpec -SpecPath $specPath
    $featureSummary = Get-FeatureSummaryFromSpec -SpecPath $specPath
    $replacements = @{
        PROJECT_NAME = (Get-ProjectNameForWorkflow)
        FEATURE_TITLE = $featureTitle
        FEATURE_KEY = (Split-Path $featureDir -Leaf)
        FEATURE_DATE = (Get-Date).ToString('yyyy-MM-dd')
        FEATURE_DESCRIPTION = $featureSummary
    }

    Write-FileFromTemplate -TemplateName 'tasks-template.md' -DestinationPath (Join-Path $featureDir 'tasks.md') -Replacements $replacements

    Write-Title 'Tarefas geradas'
    Write-Ok ("Tasks criadas em: {0}" -f (Join-Path $featureDir 'tasks.md'))

    if (Invoke-AnalyzeFeature -FeatureSelector $featureDir -Quiet) {
        Write-Ok 'Gate aprovado. Publicando artefatos do workflow no Knowledge Hub...'
        Publish-WorkflowArtifacts -FeatureDir $featureDir
    } else {
        Write-Warn 'Gate reprovado. Os artefatos nao foram publicados no Knowledge Hub.'
    }
}

function Invoke-Analyze {
    Invoke-AnalyzeFeature -FeatureSelector $Arg1 | Out-Null
}

function Get-CurrentProjectContext {
    $currentPath = (Get-Location).Path
    $safePath = Convert-ToSqlLiteral $currentPath
    $query = @(
        'SELECT id, name, path, language, framework, total_solutions_used, total_tokens_saved'
        'FROM factory_projects'
        "WHERE is_active = 1 AND '$safePath' LIKE path || '%'"
        'ORDER BY length(path) DESC'
        'LIMIT 1;'
    ) -join "`n"

    $resultJson = Invoke-SqlJson -Query $query
    if (-not $resultJson) {
        return $null
    }

    $rows = $resultJson | ConvertFrom-Json
    foreach ($row in @($rows)) {
        if ($null -ne $row) {
            return $row
        }
    }

    return $null
}

function Register-Reuse {
    param(
        $Solution,
        $ProjectContext,
        [double]$MatchScore = 1.0
    )

    if ($null -eq $Solution -or [string]::IsNullOrWhiteSpace([string]$Solution.id)) {
        return
    }

    $solutionId = Convert-ToSqlLiteral ([string]$Solution.id)
    $projectId = if ($null -ne $ProjectContext -and -not [string]::IsNullOrWhiteSpace([string]$ProjectContext.id)) {
        Convert-ToSqlLiteral ([string]$ProjectContext.id)
    } else {
        ''
    }
    $tokensSaved = if ($null -ne $Solution.tokens_output) { [int]$Solution.tokens_output } else { 0 }
    $reuseId = New-Id

    $statements = @(
        "UPDATE learned_solutions SET usage_count = usage_count + 1, tokens_saved = tokens_saved + $tokensSaved, last_used_at = datetime('now','localtime') WHERE id = '$solutionId';"
    )

    if ($projectId) {
        $statements += "INSERT INTO reuse_log (id, solution_id, project_id, match_score, tokens_saved, adapted) VALUES ('$reuseId', '$solutionId', '$projectId', $MatchScore, $tokensSaved, 0);"
        $statements += "UPDATE factory_projects SET total_solutions_used = total_solutions_used + 1, total_tokens_saved = total_tokens_saved + $tokensSaved, last_active_at = datetime('now','localtime') WHERE id = '$projectId';"
    }

    Invoke-Sql -Query ($statements -join "`n") | Out-Null
}

# --- DATABASE ------------------------------------------------

function Get-SqliteCmd {
    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($sqlite) {
        return $sqlite.Source
    }

    $nodeSqlite = Join-Path $MCP_GRAPH_PATH "node_modules\better-sqlite3\build\Release\sqlite3.exe"
    if (Test-Path $nodeSqlite) {
        return $nodeSqlite
    }

    return $null
}

function Invoke-Sql {
    param(
        [string]$Query,
        [switch]$Headers
    )

    $sqliteCmd = Get-SqliteCmd
    if (-not $sqliteCmd) {
        return Invoke-SqlViaNode -Query $Query
    }

    $commandOutput = Write-Output $Query | & $sqliteCmd $(if ($Headers) { "-header" }) -separator "|" $DB_PATH 2>&1
    return $commandOutput
}

function Invoke-SqlViaNode {
    param([string]$Query)

    $escapedDbPath = $DB_PATH.Replace('\', '\\').Replace("'", "\\'")
    $escapedQuery = $Query.Replace('\', '\\').Replace("'", "\\'").Replace("`r", '').Replace("`n", '\n')
    $nodeScript = @'
const Database = require('better-sqlite3');
const db = new Database('{0}');
const query = '{1}';
db.pragma('journal_mode = WAL');
try {{
    if (query.trim().toUpperCase().startsWith('SELECT')) {{
        const rows = db.prepare(query).all();
        rows.forEach(r => console.log(Object.values(r).join('|')));
    }} else {{
        const info = db.prepare(query).run();
        console.log('changes:' + info.changes);
    }}
}} catch (e) {{
    console.error(e.message);
}}
db.close();
'@
    $nodeScript = $nodeScript -f $escapedDbPath, $escapedQuery
    
    $tempScript = Join-Path $env:TEMP "iagents-query-$(New-Id).js"
    Set-Content $tempScript $nodeScript -Encoding UTF8
    
    try {
        $result = & node $tempScript 2>&1
        return $result
    } finally {
        Remove-Item $tempScript -ErrorAction SilentlyContinue
    }
}

function Invoke-SqlJson {
    param([string]$Query)

    $sqliteCmd = Get-SqliteCmd
    if ($sqliteCmd) {
        $output = & $sqliteCmd -json $DB_PATH $Query 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw (("sqlite3 json query failed: {0}" -f ($output | Out-String).Trim()).Trim())
        }

        return ($output | Out-String).Trim()
    }

    $escapedDbPath = $DB_PATH.Replace('\', '\\').Replace("'", "\\'")
    $escapedQuery = $Query.Replace('\', '\\').Replace("'", "\\'").Replace("`r", '').Replace("`n", '\n')
    $nodeScript = @'
const Database = require('better-sqlite3');
const db = new Database('{0}');
const query = '{1}';
db.pragma('journal_mode = WAL');
try {{
    const rows = db.prepare(query).all();
    console.log(JSON.stringify(rows));
}} catch (e) {{
    console.error(e.message);
    process.exit(1);
}}
db.close();
'@
    $nodeScript = $nodeScript -f $escapedDbPath, $escapedQuery

    $tempScript = Join-Path $env:TEMP ("iagents-json-{0}.js" -f (New-Id))
    Set-Content -Path $tempScript -Value $nodeScript -Encoding UTF8
    try {
        $result = & node $tempScript 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw (("node json query failed: {0}" -f ($result | Out-String).Trim()).Trim())
        }

        return ($result | Out-String).Trim()
    } finally {
        Remove-Item -Path $tempScript -ErrorAction SilentlyContinue
    }
}

# --- INIT COMMAND --------------------------------------------

function Invoke-Init {
    Write-Title "Inicializando IAgentsFactory Knowledge Hub..."
    
    New-FactoryDirectory
    Ensure-WorkflowStructure
    
    # Create SQLite database with schema
    $schema = @"
-- IAgentsFactory Knowledge Hub Schema v1.0
-- SQLite + WAL + FTS5

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- Soluções aprendidas com agentes externos
CREATE TABLE IF NOT EXISTS learned_solutions (
    id TEXT PRIMARY KEY,
    domain TEXT NOT NULL,
    pattern TEXT NOT NULL,
    language TEXT DEFAULT '',
    framework TEXT DEFAULT '',
    source_project TEXT DEFAULT '',
    source_agent TEXT DEFAULT '',
    prompt_used TEXT DEFAULT '',
    solution_content TEXT NOT NULL,
    solution_summary TEXT DEFAULT '',
    content_hash TEXT UNIQUE,
    quality_score REAL DEFAULT 0.8,
    usage_count INTEGER DEFAULT 0,
    tokens_input INTEGER DEFAULT 0,
    tokens_output INTEGER DEFAULT 0,
    tokens_saved INTEGER DEFAULT 0,
    tags TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now','localtime')),
    updated_at TEXT DEFAULT (datetime('now','localtime')),
    last_used_at TEXT,
    expires_at TEXT,
    is_validated INTEGER DEFAULT 0,
    is_deprecated INTEGER DEFAULT 0
);

-- FTS5 para busca textual eficiente
CREATE VIRTUAL TABLE IF NOT EXISTS solutions_fts USING fts5(
    domain, pattern, solution_summary, tags, solution_content,
    content=learned_solutions,
    content_rowid=rowid
);

-- Triggers para manter FTS5 sincronizado
CREATE TRIGGER IF NOT EXISTS solutions_ai AFTER INSERT ON learned_solutions BEGIN
    INSERT INTO solutions_fts(rowid, domain, pattern, solution_summary, tags, solution_content)
    VALUES (new.rowid, new.domain, new.pattern, new.solution_summary, new.tags, new.solution_content);
END;

CREATE TRIGGER IF NOT EXISTS solutions_ad AFTER DELETE ON learned_solutions BEGIN
    INSERT INTO solutions_fts(solutions_fts, rowid, domain, pattern, solution_summary, tags, solution_content)
    VALUES ('delete', old.rowid, old.domain, old.pattern, old.solution_summary, old.tags, old.solution_content);
END;

CREATE TRIGGER IF NOT EXISTS solutions_au AFTER UPDATE ON learned_solutions BEGIN
    INSERT INTO solutions_fts(solutions_fts, rowid, domain, pattern, solution_summary, tags, solution_content)
    VALUES ('delete', old.rowid, old.domain, old.pattern, old.solution_summary, old.tags, old.solution_content);
    INSERT INTO solutions_fts(rowid, domain, pattern, solution_summary, tags, solution_content)
    VALUES (new.rowid, new.domain, new.pattern, new.solution_summary, new.tags, new.solution_content);
END;

-- Registro de projetos da fábrica
CREATE TABLE IF NOT EXISTS factory_projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    path TEXT NOT NULL,
    language TEXT DEFAULT '',
    framework TEXT DEFAULT '',
    db_type TEXT DEFAULT '',
    description TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now','localtime')),
    last_active_at TEXT DEFAULT (datetime('now','localtime')),
    total_solutions_used INTEGER DEFAULT 0,
    total_tokens_saved INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1
);

-- Sessões de aprendizado
CREATE TABLE IF NOT EXISTS learning_sessions (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES factory_projects(id),
    agent TEXT NOT NULL,
    model TEXT DEFAULT '',
    started_at TEXT DEFAULT (datetime('now','localtime')),
    ended_at TEXT,
    total_tokens_used INTEGER DEFAULT 0,
    solutions_captured INTEGER DEFAULT 0,
    solutions_reused INTEGER DEFAULT 0,
    summary TEXT DEFAULT ''
);

-- Log de reuso (para métricas)
CREATE TABLE IF NOT EXISTS reuse_log (
    id TEXT PRIMARY KEY,
    solution_id TEXT REFERENCES learned_solutions(id),
    project_id TEXT REFERENCES factory_projects(id),
    reused_at TEXT DEFAULT (datetime('now','localtime')),
    match_score REAL DEFAULT 0,
    tokens_saved INTEGER DEFAULT 0,
    adapted INTEGER DEFAULT 0,
    feedback_score REAL
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_solutions_domain ON learned_solutions(domain);
CREATE INDEX IF NOT EXISTS idx_solutions_pattern ON learned_solutions(pattern);
CREATE INDEX IF NOT EXISTS idx_solutions_language ON learned_solutions(language);
CREATE INDEX IF NOT EXISTS idx_solutions_project ON learned_solutions(source_project);
CREATE INDEX IF NOT EXISTS idx_solutions_quality ON learned_solutions(quality_score DESC);
CREATE INDEX IF NOT EXISTS idx_solutions_hash ON learned_solutions(content_hash);
CREATE INDEX IF NOT EXISTS idx_reuse_solution ON reuse_log(solution_id);
CREATE INDEX IF NOT EXISTS idx_reuse_project ON reuse_log(project_id);
CREATE INDEX IF NOT EXISTS idx_sessions_project ON learning_sessions(project_id);

-- Tabela de sessoes do Hermes Agent (integracao local)
CREATE TABLE IF NOT EXISTS hermes_sessions (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES factory_projects(id),
    query TEXT NOT NULL,
    resolved_by TEXT DEFAULT 'unknown',
    layer_used INTEGER DEFAULT 3,
    response_content TEXT DEFAULT '',
    elapsed_sec REAL DEFAULT 0,
    tokens_saved INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now','localtime'))
);

-- Escalacoes para provider externo (para metricas de economia)
CREATE TABLE IF NOT EXISTS hermes_escalations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT NOT NULL,
    project TEXT DEFAULT '',
    escalated_at TEXT DEFAULT (datetime('now','localtime')),
    UNIQUE(query, project)
);

CREATE TABLE IF NOT EXISTS solution_embeddings (
    solution_id TEXT PRIMARY KEY,
    model       TEXT NOT NULL,
    embedding   TEXT NOT NULL,
    dimensions  INTEGER,
    created_at  TEXT DEFAULT (datetime('now','localtime'))
);

-- Indice para hermes_sessions
CREATE INDEX IF NOT EXISTS idx_hermes_sessions_project ON hermes_sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_hermes_sessions_layer ON hermes_sessions(layer_used);
CREATE INDEX IF NOT EXISTS idx_hermes_sessions_date ON hermes_sessions(created_at);
"@

    $schemaPath = Join-Path $FACTORY_DIR "schema.sql"
    Set-Content $schemaPath $schema -Encoding UTF8
    
    # Try to init with sqlite3
    $sqliteCmd = Get-SqliteCmd
    if ($sqliteCmd) {
        Get-Content $schemaPath | & $sqliteCmd $DB_PATH
        Write-Ok "Knowledge Hub criado em: $DB_PATH"
    } else {
        # Init via Node.js
        $escapedPackagePath = ($MCP_GRAPH_PATH -replace '\\', '/').Replace("'", "\\'")
        $escapedInitDbPath = ($DB_PATH -replace '\\', '/').Replace("'", "\\'")
        $escapedSchemaPath = ($schemaPath -replace '\\', '/').Replace("'", "\\'")
        $initScript = @'
const Database = require('{0}/node_modules/better-sqlite3');
const fs = require('fs');
const db = new Database('{1}');
const schema = fs.readFileSync('{2}', 'utf8');
db.exec(schema);
db.close();
console.log('OK');
'@
        $initScript = $initScript -f $escapedPackagePath, $escapedInitDbPath, $escapedSchemaPath
        $tempInit = Join-Path $env:TEMP "iagents-init-$(New-Id).js"
        Set-Content $tempInit $initScript -Encoding UTF8
        $result = & node $tempInit 2>&1
        Remove-Item $tempInit -ErrorAction SilentlyContinue
        
        if ($result -match "OK") {
            Write-Ok "Knowledge Hub criado em: $DB_PATH"
        } else {
            Write-Err "Erro ao inicializar: $result"
            return
        }
    }
    
    # Save config
    $config = Get-Config
    $config.version = "1.0.0"
    $config.created = Get-Timestamp
    Save-Config $config
    
    Write-Ok "Config salva em: $CONFIG_PATH"
    Write-Info "Schema: $schemaPath"
    Write-Host ""
    Write-Host "  Próximos passos:" -ForegroundColor Yellow
    Write-Host "    1. .\iagents-factory.ps1 register <caminho-do-projeto>" -ForegroundColor White
    Write-Host "    2. .\iagents-factory.ps1 capture (para salvar primeira solução)" -ForegroundColor White
    Write-Host "    3. .\iagents-factory.ps1 search 'sua query'" -ForegroundColor White
    Write-Host ""
}

# --- REGISTER COMMAND ----------------------------------------

function Get-ReadmeDescription {
    param([string]$ProjectPath)

    $readmePath = Join-Path $ProjectPath 'README.md'
    if (-not (Test-Path $readmePath)) {
        return ''
    }

    $lines = Get-Content $readmePath -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed.StartsWith('#')) { continue }
        return $trimmed
    }

    return ''
}

function Get-ProjectMetadata {
    param([string]$ProjectPath)

    $metadata = @{
        name = (Get-Item $ProjectPath).Name
        language = ''
        framework = ''
        dbType = ''
        description = Get-ReadmeDescription -ProjectPath $ProjectPath
    }

    $pomPath = Join-Path $ProjectPath 'pom.xml'
    $packageJsonPath = Join-Path $ProjectPath 'package.json'
    $requirementsPath = Join-Path $ProjectPath 'requirements.txt'
    $pyprojectPath = Join-Path $ProjectPath 'pyproject.toml'
    $pipfilePath = Join-Path $ProjectPath 'Pipfile'
    $readmePath = Join-Path $ProjectPath 'README.md'

    $pyprojFile = Get-ChildItem -Path $ProjectPath -Filter '*.pyproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $csprojFile = Get-ChildItem -Path $ProjectPath -Filter '*.csproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $pythonFile = Get-ChildItem -Path $ProjectPath -Filter '*.py' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $powershellFile = Get-ChildItem -Path $ProjectPath -Filter '*.ps1' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $javascriptFile = Get-ChildItem -Path $ProjectPath -Filter '*.js' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1

    if (Test-Path $pomPath) {
        $pomContent = Get-Content $pomPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $metadata.language = 'Java'
        if ($pomContent -match 'spring-boot') { $metadata.framework = 'Spring Boot' }
        if ($pomContent -match '<artifactId>([^<]+)</artifactId>') { $metadata.name = $Matches[1] }
        if ($pomContent -match '<description>([^<]+)</description>') { $metadata.description = $Matches[1] }
        if ($pomContent -match 'oracle|ojdbc') { $metadata.dbType = 'Oracle' }
        elseif ($pomContent -match 'postgresql') { $metadata.dbType = 'PostgreSQL' }
        elseif ($pomContent -match 'mysql') { $metadata.dbType = 'MySQL' }
        elseif ($pomContent -match 'sqlite') { $metadata.dbType = 'SQLite' }
        return $metadata
    }

    if (Test-Path $packageJsonPath) {
        $pkgContent = Get-Content $packageJsonPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $pkg = $pkgContent | ConvertFrom-Json -ErrorAction SilentlyContinue
        $metadata.language = if (Test-Path (Join-Path $ProjectPath 'tsconfig.json')) { 'TypeScript' } else { 'JavaScript' }
        if ($pkg -and $pkg.name) { $metadata.name = [string]$pkg.name }
        if ($pkg -and $pkg.description) { $metadata.description = [string]$pkg.description }
        if ($pkgContent -match '"@nestjs/core"') { $metadata.framework = 'NestJS' }
        elseif ($pkgContent -match '"next"') { $metadata.framework = 'Next.js' }
        elseif ($pkgContent -match '"react"') { $metadata.framework = 'React' }
        elseif ($pkgContent -match '"vue"') { $metadata.framework = 'Vue' }
        elseif ($pkgContent -match '"express"') { $metadata.framework = 'Express' }
        elseif ($pkgContent -match '"vite"') { $metadata.framework = 'Vite' }
        if ($pkgContent -match '"better-sqlite3"|"sqlite3"') { $metadata.dbType = 'SQLite' }
        elseif ($pkgContent -match '"pg"|"postgres"') { $metadata.dbType = 'PostgreSQL' }
        elseif ($pkgContent -match '"mysql"') { $metadata.dbType = 'MySQL' }
        elseif ($pkgContent -match '"oracledb"') { $metadata.dbType = 'Oracle' }
        return $metadata
    }

    if ($csprojFile) {
        $metadata.language = 'C#'
        $csprojContent = Get-Content $csprojFile.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($csprojContent -match '<AssemblyName>([^<]+)</AssemblyName>') {
            $metadata.name = $Matches[1]
        } elseif ($csprojContent -match '<RootNamespace>([^<]+)</RootNamespace>') {
            $metadata.name = $Matches[1]
        } else {
            $metadata.name = [System.IO.Path]::GetFileNameWithoutExtension($csprojFile.Name)
        }

        if ($csprojContent -match 'Microsoft.NET.Sdk.Web') {
            $metadata.framework = 'ASP.NET Core'
        } elseif ($csprojContent -match '<TargetFramework>([^<]+)</TargetFramework>') {
            $metadata.framework = '.NET ' + $Matches[1].Replace('net', '')
        } else {
            $metadata.framework = '.NET'
        }

        if ($csprojContent -match 'SqlClient') { $metadata.dbType = 'SQL Server' }
        elseif ($csprojContent -match 'Npgsql') { $metadata.dbType = 'PostgreSQL' }
        elseif ($csprojContent -match 'Sqlite') { $metadata.dbType = 'SQLite' }
        elseif ($csprojContent -match 'Oracle') { $metadata.dbType = 'Oracle' }
        return $metadata
    }

    if ((Test-Path $requirementsPath) -or (Test-Path $pyprojectPath) -or (Test-Path $pipfilePath) -or $pyprojFile -or $pythonFile) {
        $metadata.language = 'Python'

        $pythonSignals = @()
        foreach ($path in @($requirementsPath, $pyprojectPath, $pipfilePath, $readmePath)) {
            if (Test-Path $path) {
                $pythonSignals += Get-Content $path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            }
        }
        if ($pyprojFile) {
            $pythonSignals += Get-Content $pyprojFile.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            try {
                [xml]$pyprojXml = Get-Content $pyprojFile.FullName -Raw -Encoding UTF8 -ErrorAction Stop
                $pyprojNameNode = $pyprojXml.SelectSingleNode("//*[local-name()='Project']/*[local-name()='PropertyGroup']/*[local-name()='Name'][normalize-space(text())!='']")
                if ($pyprojNameNode -and -not [string]::IsNullOrWhiteSpace($pyprojNameNode.InnerText)) {
                    $metadata.name = $pyprojNameNode.InnerText.Trim()
                }
            } catch {
            }
        }

        $pythonSignalText = ($pythonSignals -join "`n")
        if ($pythonSignalText -match '(?i)fastapi') { $metadata.framework = 'FastAPI' }
        elseif ($pythonSignalText -match '(?i)django') { $metadata.framework = 'Django' }
        elseif ($pythonSignalText -match '(?i)flask') { $metadata.framework = 'Flask' }
        elseif ($pythonSignalText -match '(?i)streamlit') { $metadata.framework = 'Streamlit' }
        elseif ($pyprojFile) { $metadata.framework = 'Python Tools' }

        if ($pythonSignalText -match '(?i)sql server|sqlclient|pyodbc|pymssql') { $metadata.dbType = 'SQL Server' }
        elseif ($pythonSignalText -match '(?i)sqlite') { $metadata.dbType = 'SQLite' }
        elseif ($pythonSignalText -match '(?i)postgres|psycopg') { $metadata.dbType = 'PostgreSQL' }
        elseif ($pythonSignalText -match '(?i)oracle|cx_oracle') { $metadata.dbType = 'Oracle' }
        elseif (Get-ChildItem -Path $ProjectPath -Filter '*.db' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1) { $metadata.dbType = 'SQLite' }

        if (-not $metadata.description -and $pyprojFile) {
            $metadata.description = 'Projeto Python registrado a partir de arquivo .pyproj.'
        }

        return $metadata
    }

    if ($powershellFile) {
        $metadata.language = 'PowerShell'
        if ($javascriptFile) {
            $metadata.language = 'PowerShell + JavaScript'
        }

        if ((Test-Path (Join-Path $ProjectPath 'iagents-factory.ps1')) -or (Test-Path (Join-Path $ProjectPath 'isgt-factory.ps1'))) {
            $metadata.framework = 'Factory CLI'
        }

        if (Test-Path (Join-Path $ProjectPath 'tools\factory-dashboard\server.js')) {
            $metadata.framework = if ($metadata.framework) { "$($metadata.framework) + Node Dashboard" } else { 'Node Dashboard' }
            $metadata.dbType = 'SQLite'
        }

        if (-not $metadata.description) {
            $metadata.description = 'Projeto PowerShell com automacao local e suporte operacional da factory.'
        }

        return $metadata
    }

    return $metadata
}

function Invoke-Register {
    param([string]$ProjectPath)
    
    if (-not $ProjectPath) {
        $ProjectPath = (Get-Location).Path
    }
    
    if (-not (Test-Path $ProjectPath)) {
        Write-Err "Caminho não encontrado: $ProjectPath"
        return
    }
    
    $ProjectPath = (Resolve-Path $ProjectPath).Path
    
    Write-Title "Registrando projeto na IAgentsFactory..."
    
    $metadata = Get-ProjectMetadata -ProjectPath $ProjectPath
    $projName = [string]$metadata.name
    $projLang = if ($Language) { $Language } else { [string]$metadata.language }
    $projFw = if ($Framework) { $Framework } else { [string]$metadata.framework }
    $projDb = if ($DbType) { $DbType } else { [string]$metadata.dbType }
    $projDesc = [string]$metadata.description
    
    $id = New-Id
    $sql = @"
INSERT INTO factory_projects (id, name, path, language, framework, db_type, description)
VALUES ('$id', '$(Convert-ToSqlLiteral $projName)', '$(Convert-ToSqlLiteral $ProjectPath)', '$(Convert-ToSqlLiteral $projLang)', '$(Convert-ToSqlLiteral $projFw)', '$(Convert-ToSqlLiteral $projDb)', '$(Convert-ToSqlLiteral $projDesc)')
ON CONFLICT(name) DO UPDATE SET
    path = excluded.path,
    language = excluded.language,
    framework = excluded.framework,
    db_type = excluded.db_type,
    description = excluded.description,
    is_active = 1,
    last_active_at = datetime('now','localtime');
"@
    
    Invoke-Sql -Query $sql | Out-Null
    
    Write-Ok "Projeto registrado: $projName"
    Write-Host ""
    Write-Host "  ID:         $id" -ForegroundColor White
    Write-Host "  Nome:       $projName" -ForegroundColor White
    Write-Host "  Path:       $ProjectPath" -ForegroundColor White
    Write-Host "  Linguagem:  $projLang" -ForegroundColor White
    Write-Host "  Framework:  $projFw" -ForegroundColor White
    Write-Host "  Database:   $projDb" -ForegroundColor White
    Write-Host ""
}

# --- CAPTURE COMMAND -----------------------------------------

function Invoke-Capture {
    Ensure-WorkflowStructure

    $activeFeature = Get-FeatureDirectory -FeatureSelector ''
    if ($activeFeature -and -not $Force) {
        if (-not (Invoke-AnalyzeFeature -FeatureSelector $activeFeature -Quiet)) {
            Write-Warn 'Gate de analise falhou para a feature ativa. Corrija spec/plan/tasks antes de capturar novas solucoes desta feature.'
            Write-Info 'Use -Force se quiser ignorar o gate conscientemente.'
            return
        }
    }

    Write-Title "Capturar Solução no Knowledge Hub"
    Write-Host ""
    
    # Collect info interactively
    if (-not $Domain) {
        Write-Host "  Domínios disponíveis:" -ForegroundColor DarkGray
        Write-Host "    financial, medical, crm, auth, ecommerce, messaging," -ForegroundColor DarkGray
        Write-Host "    reporting, integration, infrastructure, general" -ForegroundColor DarkGray
        $Domain = Read-Host "  Domínio"
    }
    
    if (-not $Pattern) {
        Write-Host "  Patterns disponíveis:" -ForegroundColor DarkGray
        Write-Host "    crud-api, calculation, data-transform, auth-flow," -ForegroundColor DarkGray
        Write-Host "    error-handling, testing, refactoring, design-pattern," -ForegroundColor DarkGray
        Write-Host "    query-optimization, configuration" -ForegroundColor DarkGray
        $Pattern = Read-Host "  Pattern"
    }
    
    if (-not $Language) { $Language = Read-Host "  Linguagem (java/typescript/python/csharp)" }
    if (-not $Framework) { $Framework = Read-Host "  Framework (spring-boot/nestjs/react/fastapi)" }
    if (-not $Agent) { $Agent = Read-Host "  Agente origem (claude-sonnet/gpt-4o/copilot/deepseek)" }
    
    $sourceProject = Read-Host "  Projeto de origem"
    
    Write-Host ""
    Write-Host "  Cole o PROMPT original (digite END em linha separada para terminar):" -ForegroundColor Yellow
    $promptLines = @()
    while ($true) {
        $line = Read-Host
        if ($line -eq "END") { break }
        $promptLines += $line
    }
    $promptText = $promptLines -join "`n"
    
    Write-Host ""
    Write-Host "  Cole a SOLUÇÃO do agente (digite END em linha separada para terminar):" -ForegroundColor Yellow
    $solutionLines = @()
    while ($true) {
        $line = Read-Host
        if ($line -eq "END") { break }
        $solutionLines += $line
    }
    $solutionText = $solutionLines -join "`n"
    
    Write-Host ""
    $summary = Read-Host "  Resumo em 1-2 linhas (para busca rápida)"
    
    if (-not $Tags -or $Tags.Count -eq 0) {
        $tagsInput = Read-Host "  Tags (separadas por vírgula)"
        $Tags = $tagsInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    
    # Calculate hash for dedup
    $contentHash = Get-SHA256 $solutionText
    
    # Check for duplicate
    $dupeCheck = Invoke-Sql -Query "SELECT id FROM learned_solutions WHERE content_hash = '$contentHash';"
    if ($dupeCheck) {
        Write-Warn "Solução idêntica já existe (hash: $($contentHash.Substring(0,16))...)"
        if (-not $Force) {
            Write-Info "Use -Force para salvar mesmo assim."
            return
        }
    }
    
    $id = New-Id
    $tagsJson = ($Tags | ForEach-Object { "`"$_`"" }) -join ","
    $tagsJson = "[$tagsJson]"
    
    # Estimate tokens (rough: 1 token ≈ 4 chars)
    $tokensInput = [math]::Ceiling($promptText.Length / 4)
    $tokensOutput = [math]::Ceiling($solutionText.Length / 4)
    
    # Escape single quotes for SQL
    $safeSolution = $solutionText -replace "'","''"
    $safePrompt = $promptText -replace "'","''"
    $safeSummary = $summary -replace "'","''"
    
    $sql = @"
INSERT INTO learned_solutions 
    (id, domain, pattern, language, framework, source_project, source_agent, 
     prompt_used, solution_content, solution_summary, content_hash, 
     quality_score, tokens_input, tokens_output, tags)
VALUES 
    ('$id', '$Domain', '$Pattern', '$Language', '$Framework', '$sourceProject', '$Agent',
     '$safePrompt', '$safeSolution', '$safeSummary', '$contentHash',
     $Quality, $tokensInput, $tokensOutput, '$tagsJson');
"@
    
    Invoke-Sql -Query $sql | Out-Null
    
    Write-Host ""
    Write-Ok "Solução capturada com sucesso!"
    Write-Host ""
    Write-Host "  ID:      $id" -ForegroundColor White
    Write-Host "  Domain:  $Domain" -ForegroundColor White
    Write-Host "  Pattern: $Pattern" -ForegroundColor White
    Write-Host "  Hash:    $($contentHash.Substring(0,16))..." -ForegroundColor DarkGray
    Write-Host "  Tokens:  ~$tokensInput input + ~$tokensOutput output" -ForegroundColor White
    Write-Host "  Economia futura estimada: ~$tokensOutput tokens por reuso" -ForegroundColor Green
    Write-Host ""
}

# --- SEARCH COMMAND ------------------------------------------

function Get-FtsQueryVariants {
    param([string]$Text)

    $tokens = @([regex]::Matches($Text, '[\p{L}\p{Nd}]+') | ForEach-Object { $_.Value.ToLowerInvariant() })
    if ($tokens.Count -eq 0) {
        $fallback = ($Text -replace "'", "''").Trim()
        if (-not $fallback) {
            return @()
        }

        return @($fallback)
    }

    $exactQuery = ($tokens | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $prefixQuery = ($tokens | ForEach-Object { '"' + $_ + '"*' }) -join ' OR '

    if ($exactQuery -eq $prefixQuery) {
        return @($exactQuery)
    }

    return @($exactQuery, $prefixQuery)
}

function Invoke-Search {
    param([string]$Query, [switch]$CrossProject)

    if (-not $Query) {
        Write-Err "Uso: .\iagents-factory.ps1 search 'sua query'"
        return
    }

    Write-Title "Buscando no Knowledge Hub..."
    Write-Info "Query: $Query"

    $projectContext = Get-CurrentProjectContext
    if ($projectContext) {
        Write-Info "Projeto atual: $($projectContext.name)"
    }

    if ($CrossProject -and -not $projectContext) {
        Write-Warn "Projeto atual nao registrado. search-cross vai buscar em todos os projetos."
    }

    if ($CrossProject -and $projectContext) {
        $safeCurrentProjectId = Convert-ToSqlLiteral ([string]$projectContext.id)
        $peerProjects = [int](Invoke-Sql -Query "SELECT COUNT(*) FROM factory_projects WHERE is_active = 1 AND id <> '$safeCurrentProjectId';")
        if ($peerProjects -le 0) {
            Write-Warn 'Nenhum projeto adicional registrado para busca cross-project.'
            Write-Info 'Registre outros projetos com: .\iagents-factory.ps1 register <caminho>'
            return
        }
    }

    $projectFilter = ''
    if ($CrossProject -and $projectContext) {
        $currentProjectName = Convert-ToSqlLiteral ([string]$projectContext.name)
        $projectFilter = "AND (ls.source_project = '' OR ls.source_project <> '$currentProjectName')"
    }

    $searchTemplate = @(
        "SELECT ls.id, ls.domain, ls.pattern, ls.language, ls.framework, ls.source_project, ls.source_agent, ls.quality_score, ls.usage_count, ls.tokens_output, REPLACE(REPLACE(ls.solution_summary, char(10), ' '), char(13), ' ') AS solution_summary, ls.created_at, bm25(solutions_fts) AS score"
        'FROM solutions_fts'
        'JOIN learned_solutions ls ON solutions_fts.rowid = ls.rowid'
        "WHERE solutions_fts MATCH '{0}'"
        'AND ls.is_deprecated = 0'
        '{1}'
        'ORDER BY score ASC, ls.quality_score DESC, ls.usage_count DESC'
        'LIMIT 10;'
    ) -join "`n"

    $results = @()
    foreach ($ftsQuery in (Get-FtsQueryVariants -Text $Query)) {
        $safeFtsQuery = Convert-ToSqlLiteral $ftsQuery
        $rawRows = @(Invoke-Sql -Query ($searchTemplate -f $safeFtsQuery, $projectFilter))
        $parsedRows = @()
        foreach ($rawRow in $rawRows) {
            if ([string]::IsNullOrWhiteSpace([string]$rawRow)) {
                continue
            }

            $cols = [string]$rawRow -split '\|', 13
            if ($cols.Count -lt 13) {
                continue
            }

            $parsedRows += [pscustomobject]@{
                id = $cols[0]
                domain = $cols[1]
                pattern = $cols[2]
                language = $cols[3]
                framework = $cols[4]
                source_project = $cols[5]
                source_agent = $cols[6]
                quality_score = $cols[7]
                usage_count = $cols[8]
                tokens_output = $cols[9]
                solution_summary = $cols[10]
                created_at = $cols[11]
                score = $cols[12]
            }
        }

        if ($parsedRows.Count -gt 0) {
            $results = $parsedRows
            break
        }
    }

    if ($results.Count -eq 0) {
        Write-Warn "Nenhuma solução encontrada para: '$Query'"
        Write-Info "Após resolver com agente externo, use: .\iagents-factory.ps1 capture"
        return
    }

    $index = 1
    foreach ($row in $results) {
        if ($null -ne $row) {
            $qualityText = ([double]$row.quality_score).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
            Write-Host ("  [{0}] {1}/{2} | {3} | q={4} | src={5}" -f $index, $row.domain, $row.pattern, $row.language, $qualityText, $row.source_project) -ForegroundColor White
            if ($row.solution_summary) {
                Write-Info "Resumo: $($row.solution_summary)"
            }
            $index++
        }
    }

    $topResult = $results | Select-Object -First 1
    if ($topResult) {
        Register-Reuse -Solution $topResult -ProjectContext $projectContext
        $savedTokens = if ($null -ne $topResult.tokens_output) { [int]$topResult.tokens_output } else { 0 }
        Write-Info "Reuso registrado para o melhor match (tokens estimados: $savedTokens)"
    }
}

# --- STATS COMMAND -------------------------------------------

function Invoke-Stats {
    Write-Title "IAgentsFactory - Metricas"

    $totalSolutions = Invoke-Sql -Query 'SELECT COUNT(*) FROM learned_solutions WHERE is_deprecated = 0;'
    $totalProjects = Invoke-Sql -Query 'SELECT COUNT(*) FROM factory_projects WHERE is_active = 1;'
    $totalReuses = Invoke-Sql -Query 'SELECT COALESCE(SUM(usage_count), 0) FROM learned_solutions;'
    $totalTokensSaved = Invoke-Sql -Query 'SELECT COALESCE(SUM(tokens_saved), 0) FROM learned_solutions;'
    $totalTokensUsed = Invoke-Sql -Query 'SELECT COALESCE(SUM(tokens_input + tokens_output), 0) FROM learned_solutions;'
    $avgQuality = Invoke-Sql -Query 'SELECT ROUND(COALESCE(AVG(quality_score), 0), 2) FROM learned_solutions WHERE is_deprecated = 0;'
    $costSaved = [math]::Round(([double]$totalTokensSaved / 1000000) * 3, 2)

    Write-Host "  Solucoes armazenadas : $totalSolutions" -ForegroundColor White
    Write-Host "  Projetos ativos      : $totalProjects" -ForegroundColor White
    Write-Host "  Reusos totais        : $totalReuses" -ForegroundColor White
    Write-Host "  Tokens consumidos    : $totalTokensUsed" -ForegroundColor White
    Write-Host "  Tokens economizados  : $totalTokensSaved" -ForegroundColor Green
    Write-Host "  Custo evitado (USD)  : $costSaved" -ForegroundColor Green
    Write-Host "  Qualidade media      : $avgQuality" -ForegroundColor White
}

# --- PROJECTS COMMAND ----------------------------------------

function Invoke-Projects {
    Write-Title "Projetos Registrados"

    $projects = Invoke-Sql -Query 'SELECT name, language, framework, path, total_solutions_used, total_tokens_saved FROM factory_projects WHERE is_active = 1 ORDER BY last_active_at DESC;'
    if (-not $projects) {
        Write-Warn 'Nenhum projeto registrado. Use: .\iagents-factory.ps1 register [caminho]'
        return
    }

    foreach ($row in $projects) {
        $cols = $row -split '\|'
        if ($cols.Count -ge 6) {
            Write-Host ("  - {0} | {1} | {2} | usados={3} | tokens={4}" -f $cols[0], $cols[1], $cols[2], $cols[4], $cols[5]) -ForegroundColor White
            Write-Info "Path: $($cols[3])"
        }
    }
}

# --- EXPORT COMMAND (Phase 5: Git Sync) ----------------------

function Invoke-Export {
    Write-Title "Exportando Knowledge Hub"

    New-FactoryDirectory
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $exportFile = Join-Path $EXPORT_DIR "knowledge-export-$timestamp.json"
    $exportQuery = @(
        'SELECT id, domain, pattern, language, framework, source_project, source_agent,'
        'prompt_used, solution_content, solution_summary, content_hash,'
        'quality_score, usage_count, tokens_input, tokens_output, tokens_saved,'
        'tags, created_at, is_validated'
        'FROM learned_solutions'
        'WHERE is_deprecated = 0 AND quality_score >= 0.5'
        'ORDER BY quality_score DESC, usage_count DESC;'
    ) -join "`n"

    $rowsJson = Invoke-SqlJson -Query $exportQuery
    $exportData = @{
        version = '1.0'
        exported_at = Get-Timestamp
        exported_by = $env:USERNAME
        machine = $env:COMPUTERNAME
        solutions = @()
    }

    if ($rowsJson) {
        $rows = $rowsJson | ConvertFrom-Json
        foreach ($row in @($rows)) {
            if ($null -ne $row) {
                $exportData.solutions += @{
                    id = [string]$row.id
                    domain = [string]$row.domain
                    pattern = [string]$row.pattern
                    language = [string]$row.language
                    framework = [string]$row.framework
                    source_project = [string]$row.source_project
                    source_agent = [string]$row.source_agent
                    prompt_used = [string]$row.prompt_used
                    solution_content = [string]$row.solution_content
                    solution_summary = [string]$row.solution_summary
                    content_hash = [string]$row.content_hash
                    quality_score = [double]$row.quality_score
                    usage_count = [int]$row.usage_count
                    tokens_input = [int]$row.tokens_input
                    tokens_output = [int]$row.tokens_output
                    tokens_saved = [int]$row.tokens_saved
                    tags = [string]$row.tags
                    created_at = [string]$row.created_at
                    is_validated = [int]$row.is_validated
                }
            }
        }
    }

    $exportData | ConvertTo-Json -Depth 10 | Set-Content $exportFile -Encoding UTF8
    Write-Ok "Exportado: $exportFile"
    Write-Info "Solucoes exportadas: $($exportData.solutions.Count)"
}

# --- IMPORT COMMAND (Phase 5: Git Sync) ----------------------

function Invoke-Import {
    param([string]$FilePath)

    if (-not $FilePath -or -not (Test-Path $FilePath)) {
        Write-Err "Arquivo não encontrado: $FilePath"
        Write-Info "Uso: .\iagents-factory.ps1 import [caminho-do-json]"
        return
    }

    Write-Title "Importando Knowledge"
    $importData = Get-Content $FilePath -Raw | ConvertFrom-Json
    $imported = 0
    $skipped = 0

    foreach ($sol in $importData.solutions) {
        $safeHash = Convert-ToSqlLiteral ([string]$sol.content_hash)
        $existing = Invoke-Sql -Query "SELECT id FROM learned_solutions WHERE content_hash = '$safeHash';"
        if ($existing) {
            $skipped++
            continue
        }

        $solutionId = New-Id
        $qualityScore = [double]$sol.quality_score
        $usageCount = if ($null -ne $sol.usage_count) { [int]$sol.usage_count } else { 0 }
        $tokensInput = if ($null -ne $sol.tokens_input) { [int]$sol.tokens_input } else { 0 }
        $tokensOutput = if ($null -ne $sol.tokens_output) { [int]$sol.tokens_output } else { 0 }
        $tokensSaved = if ($null -ne $sol.tokens_saved) { [int]$sol.tokens_saved } else { 0 }
        $createdAt = if ([string]::IsNullOrWhiteSpace([string]$sol.created_at)) { Get-Timestamp } else { [string]$sol.created_at }
        $isValidated = if ($null -ne $sol.is_validated) { [int]$sol.is_validated } else { 0 }
        $insertSql = @(
            'INSERT INTO learned_solutions (id, domain, pattern, language, framework, source_project, source_agent,'
            'prompt_used, solution_content, solution_summary, content_hash, quality_score, usage_count, tokens_input, tokens_output, tokens_saved, tags, created_at, is_validated)'
            "VALUES ('$solutionId', '$(Convert-ToSqlLiteral ([string]$sol.domain))', '$(Convert-ToSqlLiteral ([string]$sol.pattern))', '$(Convert-ToSqlLiteral ([string]$sol.language))', '$(Convert-ToSqlLiteral ([string]$sol.framework))', '$(Convert-ToSqlLiteral ([string]$sol.source_project))', '$(Convert-ToSqlLiteral ([string]$sol.source_agent))', '$(Convert-ToSqlLiteral ([string]$sol.prompt_used))', '$(Convert-ToSqlLiteral ([string]$sol.solution_content))', '$(Convert-ToSqlLiteral ([string]$sol.solution_summary))', '$safeHash', $qualityScore, $usageCount, $tokensInput, $tokensOutput, $tokensSaved, '$(Convert-ToSqlLiteral ([string]$sol.tags))', '$(Convert-ToSqlLiteral $createdAt)', $isValidated);"
        ) -join "`n"

        Invoke-Sql -Query $insertSql | Out-Null
        $imported++
    }

    Write-Ok 'Importacao concluida'
    Write-Info "Importadas: $imported"
    Write-Info "Ignoradas: $skipped"
}

# --- CLEANUP COMMAND -----------------------------------------

function Invoke-Cleanup {
    Write-Title 'Limpando Knowledge Hub'

    $lowQuality = Invoke-Sql -Query "UPDATE learned_solutions SET is_deprecated = 1 WHERE quality_score < 0.3 AND usage_count >= 3; SELECT changes();"
    $expired = Invoke-Sql -Query "UPDATE learned_solutions SET is_deprecated = 1 WHERE expires_at IS NOT NULL AND expires_at < datetime('now','localtime'); SELECT changes();"
    $stale = Invoke-Sql -Query "SELECT COUNT(*) FROM learned_solutions WHERE is_deprecated = 0 AND (last_used_at IS NULL OR last_used_at < datetime('now','localtime','-6 months')) AND created_at < datetime('now','localtime','-6 months');"

    Write-Ok 'Limpeza concluida'
    Write-Info "Deprecadas por qualidade: $lowQuality"
    Write-Info "Deprecadas por expirar: $expired"
    Write-Info "Stale sem uso: $stale"
}

# --- DASHBOARD COMMAND (Phase 4) ----------------------------

function Invoke-Dashboard {
    $dashboardMode = if ($Arg1) { $Arg1.ToLowerInvariant() } else { 'factory' }

    if ($dashboardMode -eq 'mcp') {
        Write-Title "Abrindo MCP Graph Dashboard..."

        $cliScript = Join-Path $MCP_GRAPH_PATH "dist\cli\index.js"
        $serverScript = Join-Path $MCP_GRAPH_PATH "dist\mcp\server.js"

        if (Test-Path $cliScript) {
            Write-Info "Iniciando em: http://localhost:3000"
            Write-Host "  Ctrl+C para parar" -ForegroundColor DarkGray
            & node $cliScript serve --port 3000
        } elseif (Test-Path $serverScript) {
            Write-Info "Iniciando em: http://localhost:3000"
            Write-Host "  Ctrl+C para parar" -ForegroundColor DarkGray
            & node $serverScript
        } else {
            Write-Warn "MCP Graph Workflow não encontrado em: $MCP_GRAPH_PATH"
            Write-Info "Verifique se o caminho está correto e o projeto está buildado"
            Write-Info "Execute: cd $MCP_GRAPH_PATH; npm run build"
        }
        return
    }

    Write-Title "Abrindo IAgentsFactory Knowledge Hub Dashboard..."
    if (-not (Test-Path $FACTORY_DASHBOARD_SERVER)) {
        Write-Warn "Servidor do dashboard da Factory não encontrado em: $FACTORY_DASHBOARD_SERVER"
        return
    }
    if (-not (Test-Path $DB_PATH)) {
        Write-Warn "Knowledge Hub não inicializado. Execute: .\iagents-factory.ps1 init"
        return
    }

    $dashboardConfig = Get-Content $DASHBOARD_CONFIG_PATH -Raw | ConvertFrom-Json
    $factoryDashboardPort = [int]$dashboardConfig.dashboard.port
    Write-Info "Iniciando em: http://localhost:$factoryDashboardPort"
    Write-Host "  Ctrl+C para parar" -ForegroundColor DarkGray
    $env:IAGENTSFACTORY_DB_PATH = $DB_PATH
    $env:IAGENTSFACTORY_DASHBOARD_CONFIG_PATH = $DASHBOARD_CONFIG_PATH
    $env:IAGENTSFACTORY_MCP_GRAPH_PATH = $MCP_GRAPH_PATH
    $env:IAGENTSFACTORY_DASHBOARD_PORT = [string]$factoryDashboardPort
    & node $FACTORY_DASHBOARD_SERVER
}

# --- HELP COMMAND --------------------------------------------

function Invoke-Help {
    Write-Host ''
    Write-Host '  ============================================' -ForegroundColor Cyan
    Write-Host '   IAgentsFactory - Knowledge Hub Manager v1.0' -ForegroundColor Cyan
    Write-Host '  ============================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  COMANDOS:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '    init                     Inicializa o Knowledge Hub (SQLite)' -ForegroundColor White
    Write-Host '    register [path]          Registra projeto na fabrica' -ForegroundColor White
    Write-Host '    constitution [foco]      Inicializa/atualiza a constituicao do projeto' -ForegroundColor White
    Write-Host '    specify "desc"           Cria uma feature spec leve em specs/' -ForegroundColor White
    Write-Host '    plan [contexto]          Gera plano tecnico da feature ativa' -ForegroundColor White
    Write-Host '    tasks                    Gera tarefas e publica artefatos no Hub' -ForegroundColor White
    Write-Host '    analyze [feature]        Executa gate de validacao do workflow' -ForegroundColor White
    Write-Host '    capture                  Captura solucao de agente externo' -ForegroundColor White
    Write-Host '    search "query"           Busca solucoes no Knowledge Hub' -ForegroundColor White
    Write-Host '    search-cross "query"     Busca cross-project' -ForegroundColor White
    Write-Host '    stats                    Metricas de economia e reuso' -ForegroundColor White
    Write-Host '    projects                 Lista projetos registrados' -ForegroundColor White
    Write-Host '    export                   Exporta knowledge para Git sync' -ForegroundColor White
    Write-Host '    import [file]            Importa knowledge de outro dev' -ForegroundColor White
    Write-Host '    cleanup                  Remove solucoes stale/depreciadas' -ForegroundColor White
    Write-Host '    dashboard [factory|mcp]  Abre dashboard da Factory (padrao) ou MCP Graph' -ForegroundColor White
    Write-Host '    update-pillars [path]    Aplica Engineering Pillars em projeto existente' -ForegroundColor White
    Write-Host '    ask "pergunta"           Consulta 3 camadas: Hub -> Hermes -> Externo' -ForegroundColor White
    Write-Host '    hermes-status            Verifica status do Hermes Agent local' -ForegroundColor White
    Write-Host '    hermes-update            Atualiza Hermes para a ultima versao' -ForegroundColor White
    Write-Host '    hermes-provision [path]  Provisiona subagente Hermes em projetos existentes' -ForegroundColor White
    Write-Host '    embed-index              Gera embeddings vetoriais para busca semantica (Layer 1b)' -ForegroundColor White
    Write-Host '    help                     Este menu' -ForegroundColor White
    Write-Host ''
    Write-Host '  FLAGS:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '    -Domain X                Dominio (financial, medical, crm, etc.)' -ForegroundColor White
    Write-Host '    -Pattern X               Pattern (crud-api, calculation, etc.)' -ForegroundColor White
    Write-Host '    -Language X              Linguagem (java, typescript, python)' -ForegroundColor White
    Write-Host '    -Framework X             Framework (spring-boot, nestjs, react)' -ForegroundColor White
    Write-Host '    -Agent X                 Agente origem (claude-sonnet, gpt-4o)' -ForegroundColor White
    Write-Host '    -Quality 0.8             Score de qualidade (0.0-1.0)' -ForegroundColor White
    Write-Host '    -Tags tag1,tag2          Tags para classificacao' -ForegroundColor White
    Write-Host '    -Force                   Forca operacao (ignora duplicatas)' -ForegroundColor White
    Write-Host '    -Json                    Output em JSON' -ForegroundColor White
    Write-Host ''
    Write-Host '  EXEMPLOS:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '    .\iagents-factory.ps1 init' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 register C:\projetos\meu-app' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 constitution "qualidade, simplicidade e reuso"' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 specify "Painel de intake de demandas com priorizacao"' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 plan "PowerShell + Node, SQLite, baixo acoplamento"' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 tasks' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 analyze' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 search "calculo roi"' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 capture -Domain financial -Pattern calculation' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 stats' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 dashboard' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 dashboard mcp' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 export' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 ask "como implementar jwt em fastapi"' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 ask "padrao de repositorio em java" -Domain backend -Language java' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 hermes-status' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 hermes-update' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 hermes-provision           # todos os projetos registrados' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 hermes-provision C:\meu-proj  # projeto especifico' -ForegroundColor DarkGray
    Write-Host ''
}

# --- UPDATE-PILLARS COMMAND ----------------------------------

function Invoke-UpdatePillars {
    param([string]$TargetPath)

    if (-not $TargetPath) {
        $TargetPath = (Get-Location).Path
    }

    if (-not (Test-Path $TargetPath)) {
        Write-Err "Caminho nao encontrado: $TargetPath"
        return
    }

    $TargetPath = (Resolve-Path $TargetPath).Path
    $FactoryRoot = $PSScriptRoot

    Write-Title "Aplicando Engineering Pillars em: $TargetPath"

    # 1. Copiar/atualizar skills/engineering-pillars.md
    $srcPillars = Join-Path $FactoryRoot "skills\engineering-pillars.md"
    if (Test-Path $srcPillars) {
        $dstSkills = Join-Path $TargetPath "skills"
        if (-not (Test-Path $dstSkills)) {
            New-Item -ItemType Directory -Path $dstSkills -Force | Out-Null
        }
        Copy-Item -Path $srcPillars -Destination (Join-Path $dstSkills "engineering-pillars.md") -Force
        Write-Ok "skills/engineering-pillars.md atualizado"
    } else {
        Write-Warn "skills/engineering-pillars.md nao encontrado na factory raiz — pulando copia de skill."
    }

    # 2. Copiar/atualizar prompts/code-generation.md
    $srcCodeGen = Join-Path $FactoryRoot "prompts\code-generation.md"
    if (Test-Path $srcCodeGen) {
        $dstPrompts = Join-Path $TargetPath "prompts"
        if (-not (Test-Path $dstPrompts)) {
            New-Item -ItemType Directory -Path $dstPrompts -Force | Out-Null
        }
        Copy-Item -Path $srcCodeGen -Destination (Join-Path $dstPrompts "code-generation.md") -Force
        Write-Ok "prompts/code-generation.md atualizado"
    }

    # 3. Copiar/atualizar templates de spec workflow
    $templateFiles = @("spec-template.md", "plan-template.md", "tasks-template.md")
    $srcTemplates = Join-Path $FactoryRoot "specs\templates"
    $dstTemplates = Join-Path $TargetPath "specs\templates"
    if (Test-Path $srcTemplates) {
        if (-not (Test-Path $dstTemplates)) {
            New-Item -ItemType Directory -Path $dstTemplates -Force | Out-Null
        }
        foreach ($tpl in $templateFiles) {
            $srcFile = Join-Path $srcTemplates $tpl
            if (Test-Path $srcFile) {
                Copy-Item -Path $srcFile -Destination (Join-Path $dstTemplates $tpl) -Force
            }
        }
        Write-Ok "specs/templates atualizados (spec, plan, tasks)"
    }

    # 4. Atualizar constitution.md se existir (adicionar pilares se ausentes)
    $constitutionPath = Join-Path $TargetPath "specs\memory\constitution.md"
    if (Test-Path $constitutionPath) {
        $content = Get-Content $constitutionPath -Raw -Encoding UTF8
        if ($content -notmatch 'Engineering Pillars') {
            $pillarsSection = @"

## Engineering Pillars (obrigatorio em todos os projetos)

### Pilar 1 — Security by Design
- Principio do Menor Privilegio: cada componente tem apenas as permissoes estritamente necessarias.
- Nunca confiar na entrada do usuario: validar e sanitizar todo input externo.
- Gestao de Segredos: jamais hardcodar senhas ou tokens; usar variaveis de ambiente ou vault.
- Criptografia: TLS para dados em transito; Argon2 ou BCrypt para senhas.

### Pilar 2 — Arquitetura e Design
- SOLID: seguir os cinco principios em codigo orientado a objetos.
- Clean Architecture: desacoplar regras de negocio de detalhes tecnicos.
- DRY: abstrair logica duplicada em funcoes/modulos reutilizaveis.
- KISS: preferir a solucao mais simples antes de super-otimizar.

### Pilar 3 — Qualidade do Codigo
- Nomes semanticos: variaveis e funcoes devem descrever claramente sua intencao.
- Testes automatizados (piramide): unitarios (70%), integracao (20%), E2E (10%).
- Code reviews: todo PR deve ter pelo menos uma revisao antes do merge.

### Pilar 4 — DevOps e Observabilidade
- CI/CD: automatizar builds, testes e deploys.
- Logs e Monitoramento: o sistema deve alertar antes que o cliente perceba falha.
- Infraestrutura como Codigo (IaC): servidores e containers definidos como codigo.
"@
            Add-Content -Path $constitutionPath -Value $pillarsSection -Encoding UTF8
            Write-Ok "specs/memory/constitution.md: Engineering Pillars adicionados"
        } else {
            Write-Info "specs/memory/constitution.md: Engineering Pillars ja presentes — sem alteracao"
        }
    } else {
        Write-Warn "specs/memory/constitution.md nao encontrado — pulando atualizacao de constitution."
    }

    # 5. Exibir checklist
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor DarkYellow
    Write-Host "  ENGINEERING PILLARS — Checklist obrigatorio antes do deploy" -ForegroundColor DarkYellow
    Write-Host "  ============================================================" -ForegroundColor DarkYellow
    Write-Host "  Ref: skills/engineering-pillars.md" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [SEGURANCA - Security by Design]" -ForegroundColor Red
    Write-Host "    [ ] Sem secrets/credenciais hardcoded no codigo" -ForegroundColor White
    Write-Host "    [ ] Todo input externo validado e sanitizado" -ForegroundColor White
    Write-Host "    [ ] Queries parametrizadas (sem concatenacao de strings)" -ForegroundColor White
    Write-Host "    [ ] Principio do menor privilegio aplicado" -ForegroundColor White
    Write-Host "    [ ] CORS com origens explicitas; erros sem stack trace em producao" -ForegroundColor White
    Write-Host ""
    Write-Host "  [ARQUITETURA - Clean Architecture + SOLID]" -ForegroundColor Cyan
    Write-Host "    [ ] Regras de negocio no service/use-case (nao no controller)" -ForegroundColor White
    Write-Host "    [ ] Entity nao exposta diretamente na API (usar DTO)" -ForegroundColor White
    Write-Host "    [ ] Dependencias injetadas via constructor (sem new direto)" -ForegroundColor White
    Write-Host "    [ ] Sem logica duplicada (DRY aplicado)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [QUALIDADE - Codigo e Testes]" -ForegroundColor Magenta
    Write-Host "    [ ] Variaveis e funcoes com nomes descritivos e semanticos" -ForegroundColor White
    Write-Host "    [ ] Testes unitarios para toda logica de negocio" -ForegroundColor White
    Write-Host "    [ ] Testes de integracao para fluxos criticos" -ForegroundColor White
    Write-Host "    [ ] Code review antes de merge" -ForegroundColor White
    Write-Host ""
    Write-Host "  [DEVOPS - CI/CD e Observabilidade]" -ForegroundColor Green
    Write-Host "    [ ] Pipeline CI configurado (.github/workflows/ci.yml)" -ForegroundColor White
    Write-Host "    [ ] Health check endpoint implementado (se API)" -ForegroundColor White
    Write-Host "    [ ] Logs estruturados com nivel e contexto" -ForegroundColor White
    Write-Host "    [ ] Configuracoes via variaveis de ambiente" -ForegroundColor White
    Write-Host "  ============================================================" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Ok "update-pillars concluido. Execute em cada projeto existente com:"
    Write-Info ("  .\iagents-factory.ps1 update-pillars <caminho-do-projeto>")
}

# --- ASK COMMAND (3-layer resolution) -------------------------

function Invoke-Ask {
    param([string]$QueryText)
    if (-not $QueryText) {
        Write-Warn "Uso: .\iagents-factory.ps1 ask 'sua pergunta'"
        return
    }
    $bridgePath = Join-Path $PSScriptRoot "hermes-bridge.ps1"
    if (-not (Test-Path $bridgePath)) {
        Write-Err "hermes-bridge.ps1 nao encontrado. Execute: git pull"
        return
    }
    $args = @("-Query", $QueryText)
    if ($Domain)    { $args += @("-Domain",    $Domain) }
    if ($Language)  { $args += @("-Language",  $Language) }
    if ($Framework) { $args += @("-Framework", $Framework) }
    # Injetar projeto ativo se disponivel
    $cfgNow = Get-Config
    if ($cfgNow.current_project) { $args += @("-Project", $cfgNow.current_project) }
    & $bridgePath @args
}

# --- HERMES-STATUS COMMAND ------------------------------------

function Invoke-HermesStatus {
    Write-Title "Status — Layer 2 (Ollama Windows)"

    $ollamaUrl = "http://localhost:11434"
    $cfg = $null
    $cfgPath = Join-Path $env:USERPROFILE ".iagents-factory\hermes-config.json"
    if (Test-Path $cfgPath) {
        try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json } catch {}
    }
    if ($cfg -and $cfg.local_model.ollama_url) { $ollamaUrl = $cfg.local_model.ollama_url }
    $model = if ($cfg -and $cfg.local_model.model) { $cfg.local_model.model } else { "gpt-oss:20b" }

    # Checar se Ollama esta rodando
    try {
        $tags = Invoke-RestMethod -Uri "$ollamaUrl/api/tags" -TimeoutSec 4 -ErrorAction Stop
        Write-Ok "Ollama rodando em $ollamaUrl"
        $modelNames = $tags.models | ForEach-Object { $_.name }
        Write-Info "Modelos instalados: $($modelNames -join ', ')"
        if ($modelNames -contains $model) {
            Write-Ok "Modelo ativo: $model"
        } else {
            Write-Warn "Modelo '$model' nao encontrado. Disponivel: $($modelNames -join ', ')"
            Write-Info "Para instalar: ollama pull $model"
        }
    } catch {
        Write-Err "Ollama nao acessivel em $ollamaUrl"
        Write-Info "Certifique-se de que o Ollama esta aberto na bandeja do sistema."
        Write-Info "Kill switch: `$env:HERMES_DISABLED = '1'  (desliga Layer 2)"
    }

    if ($env:HERMES_DISABLED -eq "1") {
        Write-Warn "HERMES_DISABLED=1 — Layer 2 esta desabilitado manualmente"
    }
}

# --- EMBED-INDEX COMMAND -------------------------------------

function Invoke-EmbedIndex {
    param([switch]$All)
    $embedScript = Join-Path $PSScriptRoot "embed-hub.ps1"
    if (-not (Test-Path $embedScript)) {
        Write-Err "embed-hub.ps1 nao encontrado. Execute: git pull"
        return
    }
    if ($All) {
        & $embedScript -All
    } else {
        & $embedScript
    }
}

# --- HERMES-PROVISION COMMAND --------------------------------

function Invoke-HermesProvision {
    param([string]$TargetPath)

    Write-Title "Hermes Provision — Subagentes por Projeto"

    $hermesProjectsDir = Join-Path $env:USERPROFILE ".iagents-factory\hermes-projects"
    if (-not (Test-Path $hermesProjectsDir)) {
        New-Item -ItemType Directory -Path $hermesProjectsDir -Force | Out-Null
    }

    $provisioned = 0
    $skipped     = 0

    # Modo: projeto especifico via path ou nome
    if ($TargetPath) {
        $rows = Invoke-Sql -Query "SELECT name, language, framework, path FROM factory_projects WHERE (path = '$($TargetPath.Replace("'","''"))' OR name = '$($TargetPath.Replace("'","''"))') AND is_active = 1 LIMIT 1;"
        if (-not $rows) {
            # Nao esta registrado — provisionar com dados do path
            $name = Split-Path -Leaf $TargetPath
            $rows = @("$name|||") # name sem lang/fw/path
        }
    } else {
        # Todos os projetos registrados na factory
        $rows = Invoke-Sql -Query 'SELECT name, language, framework, path FROM factory_projects WHERE is_active = 1 ORDER BY name;'
    }

    if (-not $rows) {
        Write-Warn "Nenhum projeto registrado. Use: .\iagents-factory.ps1 register [caminho]"
        return
    }

    foreach ($row in $rows) {
        $cols  = [string]$row -split '\|'
        $name  = $cols[0].Trim()
        $lang  = if ($cols.Count -gt 1) { $cols[1].Trim() } else { "" }
        $fw    = if ($cols.Count -gt 2) { $cols[2].Trim() } else { "" }
        $path  = if ($cols.Count -gt 3) { $cols[3].Trim() } else { $TargetPath }

        if (-not $name) { continue }

        # Slug: letras, numeros, hifen
        $slug = $name -replace '[^a-zA-Z0-9_-]','-'
        $projDir  = Join-Path $hermesProjectsDir $slug
        $yamlFile = Join-Path $projDir "hermes-project.yaml"

        if (Test-Path $yamlFile) {
            Write-Info "  [JA EXISTE] $name ($slug)"
            $skipped++
            continue
        }

        try {
            New-Item -ItemType Directory -Path $projDir -Force | Out-Null
            $yaml = @"
project: $name
slug: $slug
language: $lang
framework: $fw
path: $path
provisioned_at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
hermes_context: enabled
"@
            Set-Content -Path $yamlFile -Value $yaml -Encoding UTF8
            Write-Ok "  Provisionado: $name  ->  hermes-projects/$slug/"
            $provisioned++
        } catch {
            Write-Warn "  Erro ao provisionar $name : $_"
        }
    }

    Write-Host ""
    Write-Ok "Concluido. Provisionados: $provisioned | Ja existiam: $skipped"
    Write-Info "Diretorio: $hermesProjectsDir"

    if ($provisioned -gt 0) {
        Write-Host ""
        Write-Host "  Agora use:" -ForegroundColor Yellow
        Write-Host "    .\iagents-factory.ps1 ask 'sua pergunta'" -ForegroundColor White
        Write-Host "  O Hermes tera contexto especializado por projeto." -ForegroundColor DarkGray
    }
}

# --- HERMES-UPDATE COMMAND ------------------------------------

function Invoke-HermesUpdate {
    $updatePath = Join-Path $PSScriptRoot "hermes-update.ps1"
    if (-not (Test-Path $updatePath)) {
        Write-Err "hermes-update.ps1 nao encontrado. Execute: git pull"
        return
    }
    & $updatePath
}

# --- MAIN DISPATCHER ----------------------------------------

switch ($Command) {
    "init"         { Invoke-Init }
    "register"     { Invoke-Register -ProjectPath $Arg1 }
    "constitution" { Invoke-Constitution }
    "specify"      { Invoke-Specify -Description $Arg1 }
    "plan"         { Invoke-Plan -PlanContext $Arg1 }
    "tasks"        { Invoke-Tasks }
    "analyze"      { Invoke-Analyze }
    "capture"      { Invoke-Capture }
    "search"       { Invoke-Search -Query $Arg1 }
    "search-cross" { Invoke-Search -Query $Arg1 -CrossProject }
    "stats"        { Invoke-Stats }
    "projects"     { Invoke-Projects }
    "export"       { Invoke-Export }
    "import"       { Invoke-Import -FilePath $Arg1 }
    "cleanup"       { Invoke-Cleanup }
    "dashboard"     { Invoke-Dashboard }
    "update-pillars" { Invoke-UpdatePillars -TargetPath $Arg1 }
    "ask"            { Invoke-Ask -QueryText $Arg1 }
    "hermes-status"  { Invoke-HermesStatus }
    "hermes-update"    { Invoke-HermesUpdate }
    "hermes-provision" { Invoke-HermesProvision -TargetPath $Arg1 }
    "embed-index"      { Invoke-EmbedIndex }
    "help"             { Invoke-Help }
    default         { Invoke-Help }
}

