# ===============================================================
# IAgentsFactory - New Project Wizard
#
# Bootstrap greenfield/existing projects from business context,
# suggest stack and architecture, apply the factory kit, scaffold
# a starter structure, and initialize SPEC artifacts.
# ===============================================================

param(
    [ValidateSet('new','existing','')]
    [string]$ProjectMode = '',
    [string]$ProjectName = '',
    [string]$ProjectPath = '',
    [string]$ProjectType = 'microservice-api',
    [string]$ProblemStatement = '',
    [string]$InputDescription = '',
    [string]$OutputDescription = '',
    [string]$Constraints = '',
    [string]$StackPreference = '',
    [string]$SelectedStack = '',
    [switch]$AutoSuggest,
    [switch]$Auto
)

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {
}

$FactoryRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FactoryScript = Join-Path $FactoryRoot 'iagents-factory.ps1'
$SetupScript = Join-Path $FactoryRoot 'setup-ia-squad.ps1'
$DefaultProjectsRoot = Split-Path $FactoryRoot -Parent

function Write-Title { param([string]$Text) Write-Host "`n  $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "  [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  [WARN] $Text" -ForegroundColor Yellow }
function Write-Err { param([string]$Text) Write-Host "  [ERR] $Text" -ForegroundColor Red }
function Write-Info { param([string]$Text) Write-Host "  $Text" -ForegroundColor DarkGray }

function Convert-ToSlug {
    param([string]$Text)

    $normalized = $Text.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '[^a-z0-9]+', '-')
    $normalized = $normalized.Trim('-')
    if (-not $normalized) {
        return 'project'
    }

    return $normalized
}

function Convert-ToIdentifier {
    param([string]$Text)

    $clean = [regex]::Replace($Text, '[^a-zA-Z0-9]+', ' ')
    $parts = @($clean -split '\s+' | Where-Object { $_ })
    if ($parts.Count -eq 0) {
        return 'Project'
    }

    return (($parts | ForEach-Object { $_.Substring(0,1).ToUpperInvariant() + $_.Substring(1).ToLowerInvariant() }) -join '')
}

function Convert-ToPackageName {
    param([string]$Text)

    $slug = (Convert-ToSlug $Text) -replace '-', ''
    if (-not $slug) {
        $slug = 'project'
    }

    return "com.iagentsfactory.$slug"
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$ValidOptions,
        [string]$Default = ''
    )

    while ($true) {
        $suffix = if ($Default) { " [$Default]" } else { '' }
        $value = Read-Host "$Prompt$suffix"
        if ([string]::IsNullOrWhiteSpace($value) -and $Default) {
            return $Default
        }

        if ($ValidOptions -contains $value.ToLowerInvariant()) {
            return $value.ToLowerInvariant()
        }

        Write-Warn ("Opcao invalida. Use: {0}" -f ($ValidOptions -join ', '))
    }
}

function Read-Value {
    param(
        [string]$Prompt,
        [string]$Default = ''
    )

    $suffix = if ($Default) { " [$Default]" } else { '' }
    $value = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value.Trim()
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )

    $defaultText = if ($Default) { 's' } else { 'n' }
    $value = Read-Choice -Prompt $Prompt -ValidOptions @('s','n','y','yes','no') -Default $defaultText
    return @('s','y','yes') -contains $value
}

function Get-LocalKnowledgeMatches {
    param([string]$Text)

    $dbPath = Join-Path (Join-Path $env:USERPROFILE '.iagents-factory') 'knowledge.db'
    if (-not (Test-Path $dbPath)) {
        return @()
    }

    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite) {
        return @()
    }

    $tokens = @([regex]::Matches($Text, '[\p{L}\p{Nd}]{4,}') | ForEach-Object { $_.Value.ToLowerInvariant() } | Select-Object -Unique)
    if ($tokens.Count -eq 0) {
        return @()
    }

    $conditions = foreach ($token in $tokens[0..([Math]::Min($tokens.Count, 4) - 1)]) {
        $safeToken = $token.Replace("'", "''")
        "(lower(solution_summary) LIKE '%$safeToken%' OR lower(tags) LIKE '%$safeToken%' OR lower(pattern) LIKE '%$safeToken%' OR lower(domain) LIKE '%$safeToken%')"
    }

    $query = @(
        'SELECT domain, pattern, source_project, REPLACE(REPLACE(solution_summary, char(10), '' ''), char(13), '' '') AS summary'
        'FROM learned_solutions'
        'WHERE is_deprecated = 0'
        "AND (" + ($conditions -join ' OR ') + ')'
        'ORDER BY usage_count DESC, quality_score DESC, created_at DESC'
        'LIMIT 5;'
    ) -join "`n"

    $rows = @(& $sqlite.Source -separator '|' $dbPath $query 2>$null)
    $matches = @()
    foreach ($row in $rows) {
        if (-not $row) { continue }
        $cols = [string]$row -split '\|', 4
        if ($cols.Count -lt 4) { continue }
        $matches += [pscustomobject]@{
            Domain = $cols[0]
            Pattern = $cols[1]
            SourceProject = $cols[2]
            Summary = $cols[3]
        }
    }

    return $matches
}

function Get-ProjectRecommendations {
    param(
        [string]$ProjectName,
        [string]$ProjectType,
        [string]$ProblemStatement,
        [string]$InputDescription,
        [string]$OutputDescription,
        [string]$Constraints,
        [string]$StackPreference
    )

    $context = (($ProjectType, $ProblemStatement, $InputDescription, $OutputDescription, $Constraints, $StackPreference) -join ' ').ToLowerInvariant()
    $stackProfiles = @{
        'fastapi' = @{
            Key = 'fastapi'
            Label = 'FastAPI (Python)'
            Language = 'Python'
            Framework = 'FastAPI'
            BuildCmd = 'pip install -r requirements.txt'
            TestCmd = 'pytest'
            RunCmd = 'uvicorn src.<module>.main:app --reload'
            DbType = 'SQLite'
            Reason = 'Melhor opcao para MVP de microservico JSON com entrega rapida e baixo atrito.'
        }
        'spring-boot' = @{
            Key = 'spring-boot'
            Label = 'Spring Boot (Java)'
            Language = 'Java'
            Framework = 'Spring Boot'
            BuildCmd = 'mvn clean package -DskipTests'
            TestCmd = 'mvn test'
            RunCmd = 'mvn spring-boot:run'
            DbType = 'PostgreSQL'
            Reason = 'Melhor opcao para contexto corporativo, contratos mais rigidos e escala operacional.'
        }
        'express' = @{
            Key = 'express'
            Label = 'Express (Node.js)'
            Language = 'JavaScript'
            Framework = 'Express'
            BuildCmd = 'npm install'
            TestCmd = 'npm test'
            RunCmd = 'npm start'
            DbType = 'SQLite'
            Reason = 'Boa opcao para API enxuta com stack Node simples e facil evolucao incremental.'
        }
        'aspnet' = @{
            Key = 'aspnet'
            Label = 'ASP.NET Core (.NET)'
            Language = 'C#'
            Framework = 'ASP.NET Core'
            BuildCmd = 'dotnet build'
            TestCmd = 'dotnet test'
            RunCmd = 'dotnet run'
            DbType = 'PostgreSQL'
            Reason = 'Boa opcao quando o ambiente operacional e ecossistema .NET sao prioridade.'
        }
    }

    # --- Detectar tipo de projeto para recomendar arquitetura adequada ---
    $detectedProjectType = 'api'
    if ($context -match '\bcli\b|command.line|linha.de.comando|\bscript\b|automacao|automation|\bcron\b|agendado|scheduled|batch') {
        $detectedProjectType = 'cli'
    } elseif ($context -match '\betl\b|pipeline|ingestao|ingestion|data.lake|data.warehouse|spark|airflow') {
        $detectedProjectType = 'data-pipeline'
    } elseif ($context -match '\bml\b|machine.learning|\bia\b|\bai\b|modelo.de|treinamento|inferencia|inference|predicao|prediction|\bnlp\b|\bllm\b|\bgpt\b|\bllama\b|langchain|crewai|autogen|agente.autonom|autonom\w*.agente|\bnpc\b|nao.jogavel|personagem.controlado|\bvoz\b|\bvoice\b|reconhecimento.de.voz|speech.recogni|mestre.da.partida|game.?master|\brpg\b.*agente|agente.*\brpg\b|interpretacao.de.papel|agente.inteligente|agente.ia|ia.agente') {
        $detectedProjectType = 'ml'
    } elseif ($context -match 'dashboard|relatorio|report|frontend|\bspa\b|\breact\b|\bangular\b|\bvue\b') {
        $detectedProjectType = 'frontend'
    }

    $architectureByType = @{
        'api'           = 'Layered REST API + Controller + Service + Repository + DTO'
        'cli'           = 'CLI + Command Handler + Service Layer + Output Formatter'
        'data-pipeline' = 'Batch Pipeline + Source Connector + Transform + Sink + Observability'
        'ml'            = 'ML Pipeline + Feature Engineering + Model Wrapper + Inference Endpoint'
        'frontend'      = 'Component Layer + State Management + API Client + View Layer'
    }
    $patternsByType = @{
        'api'           = @('controller-pattern', 'service-pattern', 'dto-pattern', 'repository-pattern', 'adapter/provider boundary')
        'cli'           = @('command-pattern', 'service-pattern', 'strategy-pattern')
        'data-pipeline' = @('pipeline-pattern', 'adapter/provider boundary', 'observer-pattern')
        'ml'            = @('pipeline-pattern', 'strategy-pattern', 'adapter/provider boundary')
        'frontend'      = @('component-pattern', 'observer-pattern', 'factory-pattern')
    }
    $risksByType = @{
        'api'           = @('Validacao de payload', 'Autenticacao e autorizacao', 'Rate limiting', 'Observabilidade de requests', 'Versionamento de API')
        'cli'           = @('Validacao de argumentos', 'Tratamento de erros e exit codes', 'Logging estruturado', 'Compatibilidade de SO')
        'data-pipeline' = @('Idempotencia das etapas', 'Reprocessamento parcial', 'Schema evolution', 'Monitoramento de lag', 'Volume de dados')
        'ml'            = @('Drift de dados/modelo', 'Latencia de inferencia', 'Reproducibilidade de treino', 'Versionamento de modelo', 'Fairness e bias')
        'frontend'      = @('XSS e injection', 'Gerenciamento de estado', 'Performance de bundle', 'Acessibilidade', 'Compatibilidade de browsers')
    }

    $effectiveArch     = $architectureByType[$detectedProjectType]
    $effectivePatterns = $patternsByType[$detectedProjectType]
    $effectiveRisks    = $risksByType[$detectedProjectType]

    # --- Recomendar stack com base em contexto ---
    $recommendedKey = ''
    if ($context -match '\bjava\b|\bspring\b') {
        $recommendedKey = 'spring-boot'
    } elseif ($context -match '\bc#\b|csharp|\bdotnet\b|\.net\b|\basp\.net\b') {
        $recommendedKey = 'aspnet'
    } elseif ($context -match '\bnode\b|nodejs|\btypescript\b|\bjavascript\b|\bexpress\b|\bnest\b') {
        $recommendedKey = 'express'
    } elseif ($context -match '\bpython\b|\bfastapi\b|\bdjango\b|\bflask\b|\buvicorn\b|langchain|crewai|autogen|\bpandas\b|\bnumpy\b|\bscikit\b|\btorch\b|\btensorflow\b') {
        $recommendedKey = 'fastapi'
    } elseif ($context -match 'robustez corporativa|enterprise|high.throughput|governanca.rigida|escala operacional') {
        $recommendedKey = 'spring-boot'
    }

    # Projetos ML/IA/Voz sem linguagem explicita: sugerir Python (fastapi)
    # mas sinalizar que a stack de orquestracao precisa ser definida
    $needsCustomStack = $false
    if (-not $recommendedKey) {
        if ($detectedProjectType -eq 'ml') {
            $recommendedKey = 'fastapi'
            $needsCustomStack = $true   # sinaliza que o usuario deve revisar
        } elseif ($detectedProjectType -in @('cli', 'data-pipeline')) {
            $recommendedKey = 'fastapi'
            $needsCustomStack = $true
        } else {
            $recommendedKey = 'fastapi'  # default para API generica
        }
    }

    # Ajustar reason do FastAPI para contextos ML/IA/Voz
    if ($detectedProjectType -eq 'ml' -and $recommendedKey -eq 'fastapi') {
        $stackProfiles['fastapi'].Reason = 'Python e ideal para IA/ML. FastAPI serve como camada de API/inferencia. Adicione LangChain, OpenAI SDK, SpeechRecognition, CrewAI etc. conforme necessidade do agente.'
    }

    if ($StackPreference -and $StackPreference -notmatch '^\s*$|aberto|sugest') {
        $preference = $StackPreference.ToLowerInvariant()
        foreach ($key in $stackProfiles.Keys) {
            if ($preference -match [regex]::Escape($key) -or $preference -match [regex]::Escape($stackProfiles[$key].Framework.ToLowerInvariant()) -or $preference -match [regex]::Escape($stackProfiles[$key].Language.ToLowerInvariant())) {
                $recommendedKey = $key
                break
            }
        }
    }

    return [pscustomobject]@{
        RecommendedStack  = $stackProfiles[$recommendedKey]
        AvailableStacks   = @($stackProfiles['fastapi'], $stackProfiles['spring-boot'], $stackProfiles['express'], $stackProfiles['aspnet'])
        Architecture      = $effectiveArch
        Patterns          = $effectivePatterns
        Risks             = $effectiveRisks
        Agents            = @('ARCHITECT', 'BACKEND', 'QA', 'OBSERVABILITY', 'KNOWLEDGE')
        DetectedType      = $detectedProjectType
        NeedsCustomStack  = $needsCustomStack
    }
}

function Select-StackProfile {
    param(
        $Recommendations,
        [string]$ForcedKey,
        [bool]$AutoMode
    )

    if ($ForcedKey) {
        $match = $Recommendations.AvailableStacks | Where-Object { $_.Key -eq $ForcedKey }
        if ($match) {
            return $match
        }
    }

    if ($AutoMode) {
        return $Recommendations.RecommendedStack
    }

    Write-Title 'Sugestao da Factory'
    Write-Host ("  Tipo de projeto detectado : {0}" -f $Recommendations.DetectedType.ToUpper()) -ForegroundColor Cyan
    Write-Host ("  Arquitetura recomendada   : {0}" -f $Recommendations.Architecture) -ForegroundColor Cyan
    Write-Host ''

    # Aviso especial para projetos que nao sao simples APIs REST
    if ($Recommendations.NeedsCustomStack) {
        Write-Host '  [ATENCAO] Nenhuma linguagem/framework explicito foi detectado no contexto.' -ForegroundColor Yellow
        Write-Host '  A opcao abaixo e uma sugestao de ponto de partida para a camada de API.' -ForegroundColor Yellow
        Write-Host '  Para o core do projeto (orquestracao, voz, IA, pipeline...) voce precisa' -ForegroundColor Yellow
        Write-Host '  adicionar as bibliotecas e ferramentas especificas manualmente.' -ForegroundColor Yellow
        Write-Host '  Considere a opcao [5] Outro/N/A se quiser definir tudo do zero.' -ForegroundColor Yellow
        Write-Host ''
    }

    if ($Recommendations.DetectedType -eq 'ml') {
        Write-Host '  Sugestoes de bibliotecas para projetos ML/IA/Voz:' -ForegroundColor DarkGray
        Write-Host '    LangChain / LangGraph  -> orquestracao de agentes LLM' -ForegroundColor DarkGray
        Write-Host '    CrewAI / AutoGen       -> multi-agente autonomo' -ForegroundColor DarkGray
        Write-Host '    OpenAI / Ollama SDK    -> modelos de linguagem' -ForegroundColor DarkGray
        Write-Host '    SpeechRecognition / Whisper -> reconhecimento de voz' -ForegroundColor DarkGray
        Write-Host '    pyttsx3 / gTTS         -> sintese de voz (TTS)' -ForegroundColor DarkGray
        Write-Host '    FastAPI                -> camada HTTP/WebSocket para expor o agente' -ForegroundColor DarkGray
        Write-Host ''
    }

    Write-Info ("Stack recomendada : {0}" -f $Recommendations.RecommendedStack.Label)
    Write-Info ("Motivo            : {0}" -f $Recommendations.RecommendedStack.Reason)
    Write-Info ("Patterns          : {0}" -f ($Recommendations.Patterns -join ', '))
    Write-Info ("Riscos            : {0}" -f ($Recommendations.Risks -join '; '))
    Write-Host ''

    # Calcular o indice default com base na stack recomendada
    $keyToIdx = @{ 'fastapi' = 1; 'spring-boot' = 2; 'express' = 3; 'aspnet' = 4 }
    $recIdx = if ($keyToIdx.ContainsKey($Recommendations.RecommendedStack.Key)) { $keyToIdx[$Recommendations.RecommendedStack.Key] } else { 5 }
    # Para projetos nao-API sem linguagem clara, sugerir N/A como default
    $defaultIdx = if ($Recommendations.NeedsCustomStack) { '5' } else { [string]$recIdx }

    Write-Host '  Opcoes de stack:' -ForegroundColor Yellow
    $index = 1
    foreach ($stack in $Recommendations.AvailableStacks) {
        $marker = if ($index -eq $recIdx -and -not $Recommendations.NeedsCustomStack) { ' <-- SUGERIDA' } else { '' }
        $color  = if ($index -eq $recIdx -and -not $Recommendations.NeedsCustomStack) { 'Green' } else { 'White' }
        Write-Host ("    [{0}] {1}{2}" -f $index, $stack.Label, $marker) -ForegroundColor $color
        $index++
    }
    $na5Marker = if ($Recommendations.NeedsCustomStack) { ' <-- SUGERIDA para este tipo de projeto' } else { '' }
    $na5Color  = if ($Recommendations.NeedsCustomStack) { 'Green' } else { 'White' }
    Write-Host ("    [5] Outro / N/A (definir manualmente){0}" -f $na5Marker) -ForegroundColor $na5Color
    Write-Host ''

    $choice = Read-Choice -Prompt "  Escolha a stack (default: [$defaultIdx])" -ValidOptions @('1','2','3','4','5') -Default $defaultIdx

    if ($choice -eq '5') {
        $customLang      = Read-Value -Prompt '  Linguagem (ex: Python, Go, Rust, Bash; deixe vazio para N/A)' -Default 'N/A'
        $customFramework = Read-Value -Prompt '  Framework (ex: Django, Gin; deixe vazio para N/A)' -Default 'N/A'
        $customBuild     = Read-Value -Prompt '  Comando de build' -Default 'N/A'
        $customTest      = Read-Value -Prompt '  Comando de test' -Default 'N/A'
        $customRun       = Read-Value -Prompt '  Comando de run/start' -Default 'N/A'
        $customLabel     = if ($customFramework -and $customFramework -ne 'N/A') { "$customFramework ($customLang)" } else { $customLang }
        return [pscustomobject]@{
            Key       = 'custom'
            Label     = $customLabel
            Language  = $customLang
            Framework = $customFramework
            BuildCmd  = $customBuild
            TestCmd   = $customTest
            RunCmd    = $customRun
            DbType    = 'N/A'
            Reason    = 'Stack definida manualmente pelo usuario.'
        }
    }

    return $Recommendations.AvailableStacks[[int]$choice - 1]
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Set-TextFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        Ensure-Directory $parent
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Ensure-GitIgnoreEntries {
    param(
        [string]$ProjectDir,
        [string[]]$Entries
    )

    $gitIgnorePath = Join-Path $ProjectDir '.gitignore'
    $existing = @()
    if (Test-Path $gitIgnorePath) {
        $existing = @(Get-Content $gitIgnorePath -Encoding UTF8)
    }

    foreach ($entry in $Entries) {
        if ($existing -notcontains $entry) {
            $existing += $entry
        }
    }

    Set-Content -Path $gitIgnorePath -Value ($existing -join "`r`n") -Encoding UTF8
}

function Initialize-FastApiScaffold {
    param($Context)

    $module = ($Context.ProjectName -replace '[^a-zA-Z0-9]+', '_').ToLowerInvariant()
    if (-not $module) { $module = 'app' }
    $Context.RunCmd = "uvicorn src.$module.main:app --reload"

    Ensure-Directory (Join-Path $Context.ProjectDir "src\$module")
    Ensure-Directory (Join-Path $Context.ProjectDir 'tests')

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'requirements.txt') -Content @"
fastapi==0.116.1
uvicorn[standard]==0.35.0
pydantic==2.11.0
pytest==8.3.5
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir "src\$module\main.py") -Content @"
from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Any


class InputPayload(BaseModel):
    data: dict[str, Any] = Field(default_factory=dict, description='Dados de entrada do servico')


class OutputPayload(BaseModel):
    status: str = 'ok'
    result: dict[str, Any] = Field(default_factory=dict, description='Resultado processado')


app = FastAPI(
    title='$($Context.ProjectName)',
    version='0.1.0',
    description='$($Context.ProjectDescription)'
)


@app.get('/health')
def health() -> dict:
    return {'status': 'ok', 'service': '$($Context.ProjectName)'}


@app.post('/process', response_model=OutputPayload)
def process(payload: InputPayload) -> OutputPayload:
    # TODO: implementar logica de negocio aqui
    return OutputPayload(status='ok', result={'message': 'placeholder - implemente a logica de negocio'})
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'tests\test_health.py') -Content @"
from fastapi.testclient import TestClient

from src.$module.main import app


client = TestClient(app)


def test_health() -> None:
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json()['status'] == 'ok'


def test_process_placeholder() -> None:
    response = client.post('/process', json={'data': {}})
    assert response.status_code == 200
    assert response.json()['status'] == 'ok'
"@

    Ensure-GitIgnoreEntries -ProjectDir $Context.ProjectDir -Entries @('__pycache__/', '.pytest_cache/', '.venv/', '*.pyc')
}

function Initialize-ExpressScaffold {
    param($Context)

    Ensure-Directory (Join-Path $Context.ProjectDir 'src\routes')
    Ensure-Directory (Join-Path $Context.ProjectDir 'src\services')
    Ensure-Directory (Join-Path $Context.ProjectDir 'src\adapters')
    Ensure-Directory (Join-Path $Context.ProjectDir 'tests')

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'package.json') -Content @"
{
  "name": "$(Convert-ToSlug $Context.ProjectName)",
  "version": "0.1.0",
  "description": "$($Context.ProjectDescription)",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "test": "node --test"
  },
  "dependencies": {
    "express": "^4.21.2"
  }
}
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'src\app.js') -Content @"
const express = require('express');

const app = express();
app.use(express.json());

app.get('/health', (request, response) => {
  response.json({ status: 'ok', service: '$($Context.ProjectName)' });
});

// TODO: implementar logica de negocio aqui
app.post('/process', (request, response) => {
  const { data } = request.body;
  response.json({ status: 'ok', result: { message: 'placeholder - implemente a logica de negocio', received: data } });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`$($Context.ProjectName) listening on port \${port}`);
});
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'tests\health.test.js') -Content @"
const test = require('node:test');
const assert = require('node:assert/strict');

test('placeholder health test', () => {
  assert.equal('ok', 'ok');
});

test('placeholder process test', () => {
  // TODO: adicionar testes de integracao para o endpoint /process
  assert.ok(true);
});
"@

    Ensure-GitIgnoreEntries -ProjectDir $Context.ProjectDir -Entries @('node_modules/', '.env')
}

function Initialize-SpringBootScaffold {
    param($Context)

    $packageName = Convert-ToPackageName $Context.ProjectName
    $packagePath = $packageName.Replace('.', '\\')
    $className = (Convert-ToIdentifier $Context.ProjectName) + 'Application'

    Ensure-Directory (Join-Path $Context.ProjectDir "src\main\java\$packagePath")
    Ensure-Directory (Join-Path $Context.ProjectDir "src\main\resources")
    Ensure-Directory (Join-Path $Context.ProjectDir "src\test\java\$packagePath")

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'pom.xml') -Content @"
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.iagentsfactory</groupId>
    <artifactId>$(Convert-ToSlug $Context.ProjectName)</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <name>$($Context.ProjectName)</name>
    <description>$($Context.ProjectDescription)</description>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.5.4</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>21</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir "src\main\java\$packagePath\$className.java") -Content @"
package $packageName;

import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
public class $className {

    public static void main(String[] args) {
        SpringApplication.run($className.class, args);
    }

    @RestController
    static class AppController {

        @GetMapping("/health")
        Map<String, String> health() {
            return Map.of("status", "ok", "service", "$($Context.ProjectName)");
        }

        // TODO: implementar logica de negocio aqui
        @PostMapping("/process")
        Map<String, Object> process(@RequestBody Map<String, Object> payload) {
            return Map.of(
                "status", "ok",
                "result", Map.of("message", "placeholder - implemente a logica de negocio")
            );
        }
    }
}
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'src\main\resources\application.yml') -Content @"
spring:
  application:
    name: $(Convert-ToSlug $Context.ProjectName)

server:
  port: 8080
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir "src\test\java\$packagePath\${className}Tests.java") -Content @"
package $packageName;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ${className}Tests {

    @Test
    void contextLoads() {
    }
}
"@

    Ensure-GitIgnoreEntries -ProjectDir $Context.ProjectDir -Entries @('target/', '.idea/', '*.class')
}

function Initialize-AspNetScaffold {
    param($Context)

    $projectFile = Join-Path $Context.ProjectDir ("{0}.csproj" -f (Convert-ToIdentifier $Context.ProjectName))
    Ensure-Directory (Join-Path $Context.ProjectDir 'Controllers')
    Ensure-Directory (Join-Path $Context.ProjectDir 'Tests')

    Set-TextFile -Path $projectFile -Content @"
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'Program.cs') -Content @"
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "$($Context.ProjectName)" }));

// TODO: implementar logica de negocio aqui
app.MapPost("/process", (ProcessRequest payload) =>
{
    return Results.Ok(new ProcessResponse("ok", new { message = "placeholder - implemente a logica de negocio" }));
});

app.Run();

public record ProcessRequest(object? Data);
public record ProcessResponse(string Status, object Result);
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'appsettings.json') -Content @"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'Tests\SmokeTests.md') -Content @"
# Smoke Tests

- GET /health retorna 200 com status=ok
- POST /process retorna 200 com status=ok
"@

    Ensure-GitIgnoreEntries -ProjectDir $Context.ProjectDir -Entries @('bin/', 'obj/', '.vs/')
}

function Initialize-ProjectScaffold {
    param($Context)

    switch ($Context.StackProfile.Key) {
        'fastapi' { Initialize-FastApiScaffold -Context $Context }
        'spring-boot' { Initialize-SpringBootScaffold -Context $Context }
        'express' { Initialize-ExpressScaffold -Context $Context }
        'aspnet' { Initialize-AspNetScaffold -Context $Context }
        default { Write-Warn 'Stack sem scaffold nativo. A factory aplicara apenas docs e SPEC.' }
    }
}

function New-ProjectContextDocs {
    param($Context)

    Ensure-Directory (Join-Path $Context.ProjectDir 'docs')

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'README.md') -Content @"
# $($Context.ProjectName)

**Tipo:** $($Context.ProjectType)

## Objetivo

$($Context.ProblemStatement)

## Entrada esperada

$($Context.InputDescription)

## Saida esperada

$($Context.OutputDescription)

## Stack inicial sugerida

- Linguagem: $($Context.StackProfile.Language)
- Framework: $($Context.StackProfile.Framework)
- Arquitetura: $($Context.Architecture)

## Comandos iniciais

- Build: $($Context.BuildCmd)
- Test: $($Context.TestCmd)
- Run: $($Context.RunCmd)

## Proximos passos

1. Revisar `specs/` e confirmar a feature inicial.
2. Rodar build/test da stack escolhida.
3. Pedir ao agente ARCHITECT revisao do desenho.
4. Pedir ao agente BACKEND o primeiro slice de implementacao.
"@

    Set-TextFile -Path (Join-Path $Context.ProjectDir 'docs\project-intake.md') -Content @"
# Project Intake - $($Context.ProjectName)

## Resumo do negocio

- Tipo: $($Context.ProjectType)
- Problema: $($Context.ProblemStatement)
- Entrada: $($Context.InputDescription)
- Saida: $($Context.OutputDescription)
- Restricoes: $($Context.Constraints)

## Recomendacao da Factory

- Stack recomendada: $($Context.StackProfile.Label)
- Motivo: $($Context.StackProfile.Reason)
- Arquitetura: $($Context.Architecture)
- Patterns: $($Context.Patterns -join ', ')
- Riscos: $($Context.Risks -join '; ')
- Agentes iniciais: $($Context.Agents -join ', ')

## Consulta local

$($Context.LocalKnowledgeMarkdown)
"@
}

function Invoke-FactoryWorkflow {
    param($Context)

    Push-Location $Context.ProjectDir
    try {
        & $FactoryScript constitution $Context.ConstitutionFocus
        & $FactoryScript specify $Context.SpecDescription
        & $FactoryScript plan $Context.PlanContext
        & $FactoryScript tasks
    } finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host '======================================================' -ForegroundColor Cyan
Write-Host '  IAgentsFactory - New Project Wizard' -ForegroundColor Cyan
Write-Host '======================================================' -ForegroundColor Cyan

$autoMode = $Auto.IsPresent
$useAutoSuggestions = if ($AutoSuggest.IsPresent) { $true } elseif ($autoMode) { $true } else { $null }

if (-not $ProjectMode) {
    $ProjectMode = if ($autoMode) { 'new' } else { Read-Choice -Prompt '  Projeto novo ou existente? (new/existing)' -ValidOptions @('new','existing') -Default 'new' }
}

if (-not $ProjectName -and $ProjectMode -eq 'new') {
    $ProjectName = if ($autoMode) { 'NewProject' } else { Read-Value -Prompt '  Nome do produto' }
}

if (-not $ProjectPath) {
    if ($ProjectMode -eq 'new') {
        $defaultPath = Join-Path $DefaultProjectsRoot $ProjectName
        $ProjectPath = if ($autoMode) { $defaultPath } else { Read-Value -Prompt '  Pasta destino do projeto' -Default $defaultPath }
    } else {
        $ProjectPath = if ($autoMode) { (Get-Location).Path } else { Read-Value -Prompt '  Caminho do projeto existente' -Default (Get-Location).Path }
    }
}

if ($ProjectMode -eq 'existing' -and -not $ProjectName) {
    $ProjectName = (Get-Item $ProjectPath).Name
}

if (-not $ProblemStatement) {
    $ProblemStatement = if ($autoMode) { 'Microservico API inicializado pela factory.' } else { Read-Value -Prompt '  Qual problema ele resolve?' }
}

if (-not $InputDescription) {
    $InputDescription = if ($autoMode) { 'JSON com parametros de entrada.' } else { Read-Value -Prompt '  Entrada esperada' }
}

if (-not $OutputDescription) {
    $OutputDescription = if ($autoMode) { 'Resposta JSON com resultado processado.' } else { Read-Value -Prompt '  Saida esperada' }
}

if (-not $Constraints) {
    $Constraints = if ($autoMode) { 'Simplicidade, observabilidade e reuso multiprojeto.' } else { Read-Value -Prompt '  Restricoes' -Default 'Simplicidade, observabilidade e reuso multiprojeto' }
}

if (-not $StackPreference) {
    $StackPreference = if ($autoMode) { 'aberto a sugestao' } else { Read-Value -Prompt '  Preferencia de stack' -Default 'aberto a sugestao' }
}

if ($null -eq $useAutoSuggestions) {
    $useAutoSuggestions = Read-YesNo -Prompt '  Quer sugestoes automaticas da factory? (s/n)' -Default $true
}

$recommendations = Get-ProjectRecommendations -ProjectName $ProjectName -ProjectType $ProjectType -ProblemStatement $ProblemStatement -InputDescription $InputDescription -OutputDescription $OutputDescription -Constraints $Constraints -StackPreference $StackPreference
$localMatches = if ($useAutoSuggestions) { Get-LocalKnowledgeMatches -Text ($ProblemStatement + ' ' + $InputDescription + ' ' + $OutputDescription) } else { @() }

if ($localMatches.Count -gt 0) {
    Write-Title 'Base local consultada'
    $i = 1
    foreach ($match in $localMatches) {
        Write-Info ("[{0}] {1}/{2} | src={3} | {4}" -f $i, $match.Domain, $match.Pattern, $match.SourceProject, $match.Summary)
        $i++
    }
} elseif ($useAutoSuggestions) {
    Write-Info 'Nenhum match relevante encontrado na base local para o intake inicial.'
}

$stackProfile = if ($useAutoSuggestions) {
    Select-StackProfile -Recommendations $recommendations -ForcedKey $SelectedStack -AutoMode $autoMode
} else {
    Select-StackProfile -Recommendations $recommendations -ForcedKey $(if ($SelectedStack) { $SelectedStack } else { $recommendations.RecommendedStack.Key }) -AutoMode $true
}

$architecture = $recommendations.Architecture
$projectDir = $ProjectPath

$effectiveRunCmd = $stackProfile.RunCmd
if ($stackProfile.Key -eq 'fastapi') {
    $moduleName = ($ProjectName -replace '[^a-zA-Z0-9]+', '_').ToLowerInvariant()
    if (-not $moduleName) {
        $moduleName = 'app'
    }
    $effectiveRunCmd = "uvicorn src.$moduleName.main:app --reload"
}

if ($ProjectMode -eq 'new') {
    Ensure-Directory $projectDir
}

if (-not (Test-Path $projectDir)) {
    Write-Err "Pasta do projeto nao encontrada: $projectDir"
    exit 1
}

$projectDescription = if ($ProblemStatement) { $ProblemStatement } else { "$ProjectType bootstrapado pela factory." }
$runCmd = $stackProfile.RunCmd

$context = [pscustomobject]@{
    ProjectName = $ProjectName
    ProjectDir = (Resolve-Path $projectDir).Path
    ProjectType = $ProjectType
    ProjectDescription = $projectDescription
    ProblemStatement = $ProblemStatement
    InputDescription = $InputDescription
    OutputDescription = $OutputDescription
    Constraints = $Constraints
    StackProfile = $stackProfile
    Architecture = $architecture
    Patterns = $recommendations.Patterns
    Risks = $recommendations.Risks
    Agents = $recommendations.Agents
    BuildCmd = $stackProfile.BuildCmd
    TestCmd = $stackProfile.TestCmd
    RunCmd = $effectiveRunCmd
    ConstitutionFocus = $Constraints
    SpecDescription = $ProblemStatement
    PlanContext = "Stack: $($stackProfile.Label). Arquitetura: $architecture. Entrada: $InputDescription. Saida: $OutputDescription. Restricoes: $Constraints"
    LocalKnowledgeMarkdown = if ($localMatches.Count -gt 0) { ($localMatches | ForEach-Object { "- {0}/{1} | src={2} | {3}" -f $_.Domain, $_.Pattern, $_.SourceProject, $_.Summary }) -join "`n" } else { '- Nenhum match relevante encontrado no bootstrap inicial.' }
}

Write-Title 'Resumo do bootstrap'
Write-Info ("Projeto: {0}" -f $context.ProjectName)
Write-Info ("Modo: {0}" -f $ProjectMode)
Write-Info ("Destino: {0}" -f $context.ProjectDir)
Write-Info ("Stack: {0}" -f $stackProfile.Label)
Write-Info ("Arquitetura: {0}" -f $architecture)
Write-Info ("Agentes: {0}" -f ($context.Agents -join ', '))

if (-not $autoMode) {
    $confirm = Read-YesNo -Prompt '  Confirmar bootstrap do projeto? (s/n)' -Default $true
    if (-not $confirm) {
        Write-Warn 'Bootstrap cancelado.'
        exit 0
    }
}

Write-Title 'Gerando scaffold inicial'
Initialize-ProjectScaffold -Context $context

Write-Title 'Aplicando kit da factory'
Push-Location $context.ProjectDir
try {
    & $SetupScript -Auto -ProjectName $context.ProjectName -ProjectDesc $context.ProjectDescription -Language $stackProfile.Language -Framework $stackProfile.Framework -BuildCmd $context.BuildCmd -TestCmd $context.TestCmd -RunCmd $context.RunCmd -DbType $stackProfile.DbType -TemplatePath $FactoryRoot
} finally {
    Pop-Location
}

Write-Title 'Consolidando docs iniciais'
New-ProjectContextDocs -Context $context

Write-Title 'Inicializando workflow SPEC'
Invoke-FactoryWorkflow -Context $context

# --- Provisionar subagente Hermes para o novo projeto ----------
$slug = $context.ProjectName -replace '[^a-zA-Z0-9_-]','-'
$hermesProjectsDir = Join-Path $env:USERPROFILE ".iagents-factory\hermes-projects"
$hermesProjectDir  = Join-Path $hermesProjectsDir $slug

if (-not (Test-Path $hermesProjectDir)) {
    try {
        New-Item -ItemType Directory -Path $hermesProjectDir -Force | Out-Null
        $yamlContent = @"
project: $($context.ProjectName)
slug: $slug
language: $($context.Language)
framework: $($context.Framework)
description: $($context.Description)
created_at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
hermes_context: enabled
"@
        Set-Content -Path (Join-Path $hermesProjectDir "hermes-project.yaml") -Value $yamlContent -Encoding UTF8
        Write-Host ""
        Write-Host "  [HERMES] Subagente Hermes provisionado para: $($context.ProjectName)" -ForegroundColor DarkCyan
        Write-Host "  [HERMES] Use: .\iagents-factory.ps1 ask 'sua pergunta' para consultas com custo zero" -ForegroundColor DarkCyan
    } catch {
        # Hermes nao instalado  -  nao bloqueia o bootstrap
    }
}

Write-Ok 'Projeto bootstrapado com sucesso.'
Write-Info 'O projeto ja saiu registrado, com SPEC inicial, docs, scaffold tecnico e contexto para os agentes.'
Write-Info ("Proximo passo: abra a pasta {0} no VS Code e continue a feature a partir de specs/." -f $context.ProjectDir)

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor DarkYellow
Write-Host "  ENGINEERING PILLARS  -  Checklist obrigatorio antes do deploy" -ForegroundColor DarkYellow
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