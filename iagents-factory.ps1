# ===============================================================
# IAgentsFactory — Knowledge Hub Manager
#
# Gerencia o Knowledge Hub local (SQLite + FTS5) para a
# Fábrica de Software com Memória Persistente de IA.
#
# COMANDOS:
#   .\iagents-factory.ps1 init                    -> Inicializa o Knowledge Hub
#   .\iagents-factory.ps1 register [path]         -> Registra projeto na fábrica
#   .\iagents-factory.ps1 capture                 -> Captura solução interativamente
#   .\iagents-factory.ps1 search "query"          -> Busca soluções locais
#   .\iagents-factory.ps1 search-cross "query"    -> Busca cross-project
#   .\iagents-factory.ps1 stats                   -> Métricas de economia
#   .\iagents-factory.ps1 projects                -> Lista projetos registrados
#   .\iagents-factory.ps1 export                  -> Exporta knowledge para Git sync
#   .\iagents-factory.ps1 import [file]           -> Importa knowledge de outro dev
#   .\iagents-factory.ps1 cleanup                 -> Remove soluções stale
#   .\iagents-factory.ps1 dashboard               -> Abre dashboard MCP Graph
#
# REQUER:
#   - Node.js (para MCP Graph Workflow)
#   - SQLite3 (opcional, para queries diretas)
# ===============================================================

param(
    [Parameter(Position=0)]
    [ValidateSet("init","register","capture","search","search-cross","stats","projects","export","import","cleanup","dashboard","help")]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Arg1 = "",

    [Parameter(Position=2)]
    [string]$Arg2 = "",

    [string]$Domain = "",
    [string]$Pattern = "",
    [string]$Language = "",
    [string]$Framework = "",
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
    $projDb = [string]$metadata.dbType
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

    $safeQuery = Convert-ToSqlLiteral $Query
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

    $searchSql = $searchTemplate -f $safeQuery, $projectFilter

    $resultsJson = Invoke-SqlJson -Query $searchSql

    if (-not $resultsJson -or $resultsJson -eq '[]') {
        $ftsQuery = (($Query -split '\s+' | ForEach-Object { "${_}*" }) -join ' OR ')
        $resultsJson = Invoke-SqlJson -Query ($searchTemplate -f $ftsQuery, $projectFilter)
    }

    if (-not $resultsJson -or $resultsJson -eq '[]') {
        Write-Warn "Nenhuma solução encontrada para: '$Query'"
        Write-Info "Após resolver com agente externo, use: .\iagents-factory.ps1 capture"
        return
    }

    $results = @($resultsJson | ConvertFrom-Json)
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
    Write-Host '    capture                  Captura solucao de agente externo' -ForegroundColor White
    Write-Host '    search "query"           Busca solucoes no Knowledge Hub' -ForegroundColor White
    Write-Host '    search-cross "query"     Busca cross-project' -ForegroundColor White
    Write-Host '    stats                    Metricas de economia e reuso' -ForegroundColor White
    Write-Host '    projects                 Lista projetos registrados' -ForegroundColor White
    Write-Host '    export                   Exporta knowledge para Git sync' -ForegroundColor White
    Write-Host '    import [file]            Importa knowledge de outro dev' -ForegroundColor White
    Write-Host '    cleanup                  Remove solucoes stale/depreciadas' -ForegroundColor White
    Write-Host '    dashboard [factory|mcp]  Abre dashboard da Factory (padrao) ou MCP Graph' -ForegroundColor White
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
    Write-Host '    .\iagents-factory.ps1 search "calculo roi"' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 capture -Domain financial -Pattern calculation' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 stats' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 dashboard' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 dashboard mcp' -ForegroundColor DarkGray
    Write-Host '    .\iagents-factory.ps1 export' -ForegroundColor DarkGray
    Write-Host ''
}

# --- MAIN DISPATCHER ----------------------------------------

switch ($Command) {
    "init"         { Invoke-Init }
    "register"     { Invoke-Register -ProjectPath $Arg1 }
    "capture"      { Invoke-Capture }
    "search"       { Invoke-Search -Query $Arg1 }
    "search-cross" { Invoke-Search -Query $Arg1 -CrossProject }
    "stats"        { Invoke-Stats }
    "projects"     { Invoke-Projects }
    "export"       { Invoke-Export }
    "import"       { Invoke-Import -FilePath $Arg1 }
    "cleanup"      { Invoke-Cleanup }
    "dashboard"    { Invoke-Dashboard }
    "help"         { Invoke-Help }
    default        { Invoke-Help }
}

