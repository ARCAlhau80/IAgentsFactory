# ===============================================================
# IAgentsFactory - Setup Script (com Auto-Deteccao)
# 
# USO:
#   1. Abra PowerShell na pasta do seu projeto
#   2. Execute: & "C:\caminho\IAgentsFactory\setup-ia-squad.ps1"
#   3. O script detecta stack, build, test automaticamente
#   4. Confirme e pronto!
#
# FLAGS:
#   -Auto           -> Modo automatico (sem perguntas, usa tudo detectado)
#   -ProjectName X  -> Override do nome
#   -TemplatePath X -> Caminho do IAgentsFactory (auto-detectado se omitido)
# ===============================================================

param(
    [string]$ProjectName,
    [string]$ProjectDesc,
    [string]$Language,
    [string]$Framework,
    [string]$BuildCmd,
    [string]$TestCmd,
    [string]$RunCmd,
    [string]$TemplatePath,
    [string]$DbType,
    [switch]$Auto
)

# --- FUNcOES DE AUTO-DETECcaO ---------------------------------

function Get-ProjectStackDetails {
    param([string]$Dir)
    
    $result = @{
        Language     = ""
        Framework    = ""
        BuildCmd     = ""
        TestCmd      = ""
        RunCmd       = ""
        DbType       = ""
        ProjectName  = ""
        ProjectDesc  = ""
        PackageBase  = ""
        JavaVersion  = ""
        NodeVersion  = ""
        PythonVersion = ""
        DotnetVersion = ""
        Detected     = @()
    }
    
    # --- JAVA / MAVEN ----------------------------------------
    $pomXml = Join-Path $Dir "pom.xml"
    if (Test-Path $pomXml) {
        $result.Language = "Java"
        $result.Detected += "pom.xml"
        
        $pomContent = Get-Content $pomXml -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # Detect Java version
        if ($pomContent -match '<java\.version>(\d+[\.\d]*)</java\.version>') {
            $result.JavaVersion = $Matches[1]
            $result.Language = "Java $($Matches[1])"
        } elseif ($pomContent -match '<maven\.compiler\.source>(\d+[\.\d]*)</maven\.compiler\.source>') {
            $result.JavaVersion = $Matches[1]
            $result.Language = "Java $($Matches[1])"
        }
        
        # Detect framework from dependencies
        if ($pomContent -match 'spring-boot') {
            $result.Framework = "Spring Boot"
            if ($pomContent -match '<version>(\d+\.\d+[\.\d]*)</version>' -and $pomContent -match 'spring-boot-starter-parent') {
                # Try to find Spring Boot version
                if ($pomContent -match 'spring-boot-starter-parent[\s\S]*?<version>(\d+\.\d+[\.\d]*)</version>') {
                    $result.Framework = "Spring Boot $($Matches[1])"
                }
            }
            $result.Detected += "Spring Boot"
        } elseif ($pomContent -match 'quarkus') {
            $result.Framework = "Quarkus"
            $result.Detected += "Quarkus"
        } elseif ($pomContent -match 'micronaut') {
            $result.Framework = "Micronaut"
            $result.Detected += "Micronaut"
        }
        
        # Detect project name from pom
        if ($pomContent -match '<artifactId>([^<]+)</artifactId>') {
            $result.ProjectName = $Matches[1]
        }
        if ($pomContent -match '<description>([^<]+)</description>') {
            $result.ProjectDesc = $Matches[1]
        }
        
        # Detect DB from pom dependencies
        if ($pomContent -match 'oracle|ojdbc') { $result.DbType = "Oracle" }
        elseif ($pomContent -match 'postgresql') { $result.DbType = "PostgreSQL" }
        elseif ($pomContent -match 'mysql') { $result.DbType = "MySQL" }
        elseif ($pomContent -match 'h2database|h2') { $result.DbType = "H2" }
        elseif ($pomContent -match 'sqlserver|mssql') { $result.DbType = "SQL Server" }
        elseif ($pomContent -match 'mongodb') { $result.DbType = "MongoDB" }
        
        # Build commands
        if (Test-Path (Join-Path $Dir "mvnw.cmd")) {
            $result.BuildCmd = ".\mvnw.cmd clean package -DskipTests"
            $result.TestCmd = ".\mvnw.cmd test"
        } elseif (Test-Path (Join-Path $Dir "mvnw")) {
            $result.BuildCmd = "./mvnw clean package -DskipTests"
            $result.TestCmd = "./mvnw test"
        } else {
            $result.BuildCmd = "mvn clean package -DskipTests"
            $result.TestCmd = "mvn test"
        }
        $result.RunCmd = "java -jar target/*.jar"
        
        # Detect package base from src
        $srcMain = Join-Path $Dir "src\main\java"
        if (Test-Path $srcMain) {
            $deepest = Get-ChildItem -Path $srcMain -Directory -Recurse | 
                Where-Object { (Get-ChildItem $_.FullName -File -Filter "*.java" -ErrorAction SilentlyContinue).Count -gt 0 } |
                Select-Object -First 1
            if ($deepest) {
                $result.PackageBase = $deepest.FullName.Replace($srcMain + "\", "").Replace("\", ".")
            }
        }
    }
    
    # --- JAVA / GRADLE ---------------------------------------
    $buildGradle = Join-Path $Dir "build.gradle"
    $buildGradleKts = Join-Path $Dir "build.gradle.kts"
    if ((-not $result.Language) -and ((Test-Path $buildGradle) -or (Test-Path $buildGradleKts))) {
        $result.Language = "Java"
        $result.Detected += "Gradle"
        
        $gradleFile = if (Test-Path $buildGradleKts) { $buildGradleKts } else { $buildGradle }
        $gradleContent = Get-Content $gradleFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        if ($gradleContent -match 'kotlin') { $result.Language = "Kotlin" }
        if ($gradleContent -match 'spring-boot') { $result.Framework = "Spring Boot" }
        
        if (Test-Path (Join-Path $Dir "gradlew.bat")) {
            $result.BuildCmd = ".\gradlew.bat build -x test"
            $result.TestCmd = ".\gradlew.bat test"
        } else {
            $result.BuildCmd = "gradle build -x test"
            $result.TestCmd = "gradle test"
        }
        $result.RunCmd = ".\gradlew.bat bootRun"
    }
    
    # --- NODE.JS / TYPESCRIPT --------------------------------
    $packageJson = Join-Path $Dir "package.json"
    if ((-not $result.Language) -and (Test-Path $packageJson)) {
        $result.Detected += "package.json"
        
        $pkgContent = Get-Content $packageJson -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $pkg = $pkgContent | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        # TypeScript or JavaScript?
        $tsConfig = Join-Path $Dir "tsconfig.json"
        if ((Test-Path $tsConfig) -or ($pkg.devDependencies.PSObject.Properties.Name -contains "typescript")) {
            $result.Language = "TypeScript"
            $result.Detected += "TypeScript"
        } else {
            $result.Language = "JavaScript"
        }
        
        # Project info
        if ($pkg.name) { $result.ProjectName = $pkg.name }
        if ($pkg.description) { $result.ProjectDesc = $pkg.description }
        
        # Detect framework
        $allDeps = @()
        if ($pkg.dependencies) { $allDeps += $pkg.dependencies.PSObject.Properties.Name }
        if ($pkg.devDependencies) { $allDeps += $pkg.devDependencies.PSObject.Properties.Name }
        
        if ($allDeps -contains "@nestjs/core") { $result.Framework = "NestJS"; $result.Detected += "NestJS" }
        elseif ($allDeps -contains "next") { $result.Framework = "Next.js"; $result.Detected += "Next.js" }
        elseif ($allDeps -contains "nuxt") { $result.Framework = "Nuxt"; $result.Detected += "Nuxt" }
        elseif ($allDeps -contains "express") { $result.Framework = "Express"; $result.Detected += "Express" }
        elseif ($allDeps -contains "fastify") { $result.Framework = "Fastify"; $result.Detected += "Fastify" }
        elseif ($allDeps -contains "react") { $result.Framework = "React"; $result.Detected += "React" }
        elseif ($allDeps -contains "vue") { $result.Framework = "Vue.js"; $result.Detected += "Vue.js" }
        elseif ($allDeps -contains "@angular/core") { $result.Framework = "Angular"; $result.Detected += "Angular" }
        
        # Detect DB
        if ($allDeps -contains "pg" -or $allDeps -contains "postgres") { $result.DbType = "PostgreSQL" }
        elseif ($allDeps -contains "mysql2" -or $allDeps -contains "mysql") { $result.DbType = "MySQL" }
        elseif ($allDeps -contains "mongodb" -or $allDeps -contains "mongoose") { $result.DbType = "MongoDB" }
        elseif ($allDeps -contains "better-sqlite3" -or $allDeps -contains "sqlite3") { $result.DbType = "SQLite" }
        
        # Build commands with scripts detection
        if ($pkg.scripts) {
            $scripts = $pkg.scripts.PSObject.Properties.Name
            $pm = if (Test-Path (Join-Path $Dir "yarn.lock")) { "yarn" }
                  elseif (Test-Path (Join-Path $Dir "pnpm-lock.yaml")) { "pnpm" }
                  else { "npm" }
            $result.Detected += $pm
            
            if ($scripts -contains "build")  { $result.BuildCmd = "$pm run build" }
            else { $result.BuildCmd = "$pm install" }
            
            if ($scripts -contains "test")   { $result.TestCmd = "$pm test" }
            elseif ($scripts -contains "test:unit") { $result.TestCmd = "$pm run test:unit" }
            else { $result.TestCmd = "$pm test" }
            
            if ($scripts -contains "start")     { $result.RunCmd = "$pm start" }
            elseif ($scripts -contains "dev")    { $result.RunCmd = "$pm run dev" }
            elseif ($scripts -contains "serve")  { $result.RunCmd = "$pm run serve" }
            else { $result.RunCmd = "$pm start" }
        } else {
            $result.BuildCmd = "npm install"
            $result.TestCmd = "npm test"
            $result.RunCmd = "npm start"
        }
    }
    
    # --- PYTHON ----------------------------------------------
    $pyProject = Join-Path $Dir "pyproject.toml"
    $requirements = Join-Path $Dir "requirements.txt"
    $setupPy = Join-Path $Dir "setup.py"
    if ((-not $result.Language) -and ((Test-Path $pyProject) -or (Test-Path $requirements) -or (Test-Path $setupPy))) {
        $result.Language = "Python"
        $result.Detected += "Python"
        
        # Detect framework from requirements
        $depContent = ""
        if (Test-Path $requirements) {
            $depContent = Get-Content $requirements -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $result.Detected += "requirements.txt"
        }
        if (Test-Path $pyProject) {
            $depContent += Get-Content $pyProject -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $result.Detected += "pyproject.toml"
            # Try to get project name
            if ($depContent -match 'name\s*=\s*"([^"]+)"') {
                $result.ProjectName = $Matches[1]
            }
        }
        
        if ($depContent -match 'fastapi') { $result.Framework = "FastAPI"; $result.Detected += "FastAPI" }
        elseif ($depContent -match 'django') { $result.Framework = "Django"; $result.Detected += "Django" }
        elseif ($depContent -match 'flask') { $result.Framework = "Flask"; $result.Detected += "Flask" }
        elseif ($depContent -match 'starlette') { $result.Framework = "Starlette"; $result.Detected += "Starlette" }
        
        # Detect DB
        if ($depContent -match 'psycopg|asyncpg') { $result.DbType = "PostgreSQL" }
        elseif ($depContent -match 'pymysql|mysql') { $result.DbType = "MySQL" }
        elseif ($depContent -match 'pymongo|motor') { $result.DbType = "MongoDB" }
        elseif ($depContent -match 'cx.Oracle|oracledb') { $result.DbType = "Oracle" }
        
        # Build commands
        if (Test-Path $pyProject) {
            if ($depContent -match 'poetry') {
                $result.BuildCmd = "poetry install"
                $result.TestCmd = "poetry run pytest"
                $result.RunCmd = "poetry run python -m $($result.ProjectName)"
                $result.Detected += "Poetry"
            } else {
                $result.BuildCmd = "pip install -e ."
                $result.TestCmd = "pytest"
            }
        } else {
            $result.BuildCmd = "pip install -r requirements.txt"
            $result.TestCmd = "pytest"
        }
        
        if (-not $result.RunCmd) {
            if ($result.Framework -eq "FastAPI") { $result.RunCmd = "uvicorn main:app --reload" }
            elseif ($result.Framework -eq "Django") { $result.RunCmd = "python manage.py runserver" }
            elseif ($result.Framework -eq "Flask") { $result.RunCmd = "flask run" }
            else { $result.RunCmd = "python main.py" }
        }
    }
    
    # --- C# / .NET -------------------------------------------
    $csprojFiles = Get-ChildItem -Path $Dir -Filter "*.csproj" -ErrorAction SilentlyContinue
    $slnFiles = Get-ChildItem -Path $Dir -Filter "*.sln" -ErrorAction SilentlyContinue
    if ((-not $result.Language) -and ($csprojFiles -or $slnFiles)) {
        $result.Language = "C#"
        $result.Detected += ".NET"
        
        if ($csprojFiles) {
            $csprojContent = Get-Content $csprojFiles[0].FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $result.ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($csprojFiles[0].Name)
            
            if ($csprojContent -match '<TargetFramework>net(\d+\.\d+)</TargetFramework>') {
                $result.DotnetVersion = $Matches[1]
                $result.Framework = ".NET $($Matches[1])"
            } elseif ($csprojContent -match '<TargetFramework>net(\d+)</TargetFramework>') {
                $result.DotnetVersion = $Matches[1]
                $result.Framework = ".NET $($Matches[1])"
            }
            
            # Detect web framework
            if ($csprojContent -match 'Microsoft\.AspNetCore') { 
                $result.Framework = "ASP.NET Core $($result.DotnetVersion)" 
            }
            
            # Detect DB
            if ($csprojContent -match 'Npgsql') { $result.DbType = "PostgreSQL" }
            elseif ($csprojContent -match 'MySql') { $result.DbType = "MySQL" }
            elseif ($csprojContent -match 'Oracle') { $result.DbType = "Oracle" }
            elseif ($csprojContent -match 'SqlServer|Microsoft\.Data\.Sql') { $result.DbType = "SQL Server" }
        }
        
        if ($slnFiles) {
            $result.ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($slnFiles[0].Name)
        }
        
        $result.BuildCmd = "dotnet build"
        $result.TestCmd = "dotnet test"
        $result.RunCmd = "dotnet run"
    }
    
    # --- GO --------------------------------------------------
    $goMod = Join-Path $Dir "go.mod"
    if ((-not $result.Language) -and (Test-Path $goMod)) {
        $result.Language = "Go"
        $result.Detected += "Go"
        $goContent = Get-Content $goMod -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        if ($goContent -match '^module\s+(.+)$') {
            $moduleName = ($Matches[1]).Trim()
            $result.ProjectName = ($moduleName -split '/')[-1]
        }
        
        if ($goContent -match 'gin-gonic') { $result.Framework = "Gin" }
        elseif ($goContent -match 'echo') { $result.Framework = "Echo" }
        elseif ($goContent -match 'fiber') { $result.Framework = "Fiber" }
        else { $result.Framework = "Go stdlib" }
        
        $result.BuildCmd = "go build ./..."
        $result.TestCmd = "go test ./..."
        $result.RunCmd = "go run ."
    }
    
    # --- RUST ------------------------------------------------
    $cargoToml = Join-Path $Dir "Cargo.toml"
    if ((-not $result.Language) -and (Test-Path $cargoToml)) {
        $result.Language = "Rust"
        $result.Detected += "Rust"
        $cargoContent = Get-Content $cargoToml -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($cargoContent -match 'name\s*=\s*"([^"]+)"') { $result.ProjectName = $Matches[1] }
        if ($cargoContent -match 'actix') { $result.Framework = "Actix" }
        elseif ($cargoContent -match 'axum') { $result.Framework = "Axum" }
        elseif ($cargoContent -match 'rocket') { $result.Framework = "Rocket" }
        $result.BuildCmd = "cargo build"
        $result.TestCmd = "cargo test"
        $result.RunCmd = "cargo run"
    }
    
    # --- FALLBACK: folder name as project name ---------------
    if (-not $result.ProjectName) {
        $result.ProjectName = (Get-Item $Dir).Name
    }
    
    return $result
}

# --- ENRIQUECIMENTO DE CONTEXTO A PARTIR DE DOCS DO PROJETO ---

function Get-ProjectDocInsights {
    param([string]$Dir, [hashtable]$Det)
    
    $extra = @{
        Version      = ""
        SourceDir    = ""
        TestDir      = ""
        ConfigFile   = ""
        TestFw       = ""
        PkgMgr       = ""
        Runtime      = ""
        Logging      = ""
        ORM          = ""
    }
    
    # --- README.md: extrair descricao e version ---------------
    $readme = Join-Path $Dir "README.md"
    if (Test-Path $readme) {
        $rmContent = [System.IO.File]::ReadAllText($readme, [System.Text.Encoding]::UTF8)
        
        # Version badge: ![Version](https://img.shields.io/badge/Version-X.Y.Z-color)
        if ($rmContent -match 'Version[- ]*(\d+\.\d+[\.\d]*)') {
            $extra.Version = $Matches[1]
        }
        
        # Descricao: texto em **bold** logo apos o titulo # 
        if (-not $Det.ProjectDesc -and ($rmContent -match '(?m)^# .+[\r\n]+[\r\n]*\*\*(.+?)\*\*')) {
            $Det.ProjectDesc = ($Matches[1]).Trim() -replace '\r?\n', ' '
            if ($Det.ProjectDesc.Length -gt 100) {
                $Det.ProjectDesc = $Det.ProjectDesc.Substring(0, 97) + "..."
            }
        }
        
        # Framework do README (se nao detectou antes)
        if (-not $Det.Framework) {
            if ($rmContent -match 'CustomTkinter|customtkinter') { $Det.Framework = "CustomTkinter" }
            elseif ($rmContent -match 'Tkinter|tkinter') { $Det.Framework = "Tkinter" }
            elseif ($rmContent -match 'PyQt|pyqt') { $Det.Framework = "PyQt" }
            elseif ($rmContent -match 'Kivy|kivy') { $Det.Framework = "Kivy" }
        }
        
        $Det.Detected += "README.md"
    }
    
    # --- CHANGELOG.md: extrair versao mais recente ------------
    $changelog = Join-Path $Dir "CHANGELOG.md"
    if (Test-Path $changelog) {
        $clContent = Get-Content $changelog -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($clContent -match '#+\s*\[?v?(\d+\.\d+[\.\d]*)') {
            if (-not $extra.Version) { $extra.Version = $Matches[1] }
        }
        $Det.Detected += "CHANGELOG.md"
    }
    
    # --- Detectar diretorios de codigo e teste ----------------
    $srcCandidates = @("src", "app", "lib", "source", "main", "cmd", "internal", "pkg")
    foreach ($s in $srcCandidates) {
        $p = Join-Path $Dir $s
        if (Test-Path $p) { $extra.SourceDir = $s; break }
    }
    
    $testCandidates = @("tests", "test", "__tests__", "spec", "test_*.py")
    foreach ($t in $testCandidates) {
        $p = Join-Path $Dir $t
        if (Test-Path $p) { $extra.TestDir = $t; break }
    }
    # Fallback: check for test files in root
    if (-not $extra.TestDir) {
        $testFiles = Get-ChildItem -Path $Dir -File -Filter "test_*" -ErrorAction SilentlyContinue
        if (-not $testFiles) { $testFiles = Get-ChildItem -Path $Dir -File -Filter "*_test.*" -ErrorAction SilentlyContinue }
        if ($testFiles) { $extra.TestDir = "." }
    }
    
    # --- Detectar config files --------------------------------
    $configCandidates = @(
        @{File="application.yml"; Name="application.yml"},
        @{File="application.properties"; Name="application.properties"},
        @{File="appsettings.json"; Name="appsettings.json"},
        @{File=".env"; Name=".env"},
        @{File="config.py"; Name="config.py"},
        @{File="config.yaml"; Name="config.yaml"},
        @{File="config.json"; Name="config.json"},
        @{File=".env.example"; Name=".env.example"},
        @{File="settings.py"; Name="settings.py"}
    )
    foreach ($c in $configCandidates) {
        if (Test-Path (Join-Path $Dir $c.File)) { 
            $extra.ConfigFile = $c.Name; break 
        }
    }
    if (-not $extra.ConfigFile) {
        # Buscar recursivamente
        $found = Get-ChildItem -Path $Dir -Recurse -File -Include "*.yml","*.yaml","*.properties","*.env" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $extra.ConfigFile = $found.Name
        }
    }
    
    # --- Python: detectar mais frameworks de requirements.txt -
    $reqFile = Join-Path $Dir "requirements.txt"
    if (Test-Path $reqFile) {
        $reqContent = Get-Content $reqFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # Test framework
        if ($reqContent -match 'pytest') { $extra.TestFw = "pytest" }
        elseif ($reqContent -match 'unittest') { $extra.TestFw = "unittest" }
        elseif ($reqContent -match 'nose') { $extra.TestFw = "nose" }
        
        # Package manager
        $extra.PkgMgr = "pip"
        
        # Logging
        if ($reqContent -match 'loguru') { $extra.Logging = "Loguru" }
        elseif ($reqContent -match 'structlog') { $extra.Logging = "structlog" }
        else { $extra.Logging = "logging (stdlib)" }
        
        # ORM
        if ($reqContent -match 'sqlalchemy') { $extra.ORM = "SQLAlchemy" }
        elseif ($reqContent -match 'django') { $extra.ORM = "Django ORM" }
        elseif ($reqContent -match 'peewee') { $extra.ORM = "Peewee" }
        elseif ($reqContent -match 'tortoise') { $extra.ORM = "Tortoise ORM" }
        
        # GUI frameworks (se nao detectou ainda)
        if (-not $Det.Framework) {
            if ($reqContent -match 'customtkinter') { $Det.Framework = "CustomTkinter" }
            elseif ($reqContent -match 'tkinter') { $Det.Framework = "Tkinter" }
            elseif ($reqContent -match 'PyQt\d') { $Det.Framework = "PyQt" }
        }
    }
    
    # --- Node.js: detectar test framework ---------------------
    $pkgJson = Join-Path $Dir "package.json"
    if (Test-Path $pkgJson) {
        $pkgContent = Get-Content $pkgJson -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($pkgContent -match '"jest"') { $extra.TestFw = "Jest" }
        elseif ($pkgContent -match '"vitest"') { $extra.TestFw = "Vitest" }
        elseif ($pkgContent -match '"mocha"') { $extra.TestFw = "Mocha" }
        elseif ($pkgContent -match '"jasmine"') { $extra.TestFw = "Jasmine" }
    }
    
    # --- Java: detectar test framework e mais ----------------
    $pomXml = Join-Path $Dir "pom.xml"
    if (Test-Path $pomXml) {
        $pomContent = Get-Content $pomXml -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($pomContent -match 'junit-jupiter|junit5') { $extra.TestFw = "JUnit 5" }
        elseif ($pomContent -match 'junit') { $extra.TestFw = "JUnit 4" }
        if ($pomContent -match 'mockito') { $extra.TestFw += " + Mockito" }
        if ($pomContent -match 'hibernate') { $extra.ORM = "Hibernate" }
        elseif ($pomContent -match 'mybatis') { $extra.ORM = "MyBatis" }
        if ($pomContent -match 'log4j') { $extra.Logging = "Log4j" }
        elseif ($pomContent -match 'logback|slf4j') { $extra.Logging = "SLF4J/Logback" }
    }
    
    # --- Runtime version detection ----------------------------
    if ($Det.Language -match 'Python') {
        try {
            $pyVer = & python --version 2>&1
            if ($pyVer -match '(\d+\.\d+[\.\d]*)') {
                $extra.Runtime = $Matches[1]
                if (-not $extra.Version) { $extra.Version = $Matches[1] }
            }
        } catch {}
    }
    
    return $extra
}

function Show-Detection {
    param($det)
    
    Write-Host ""
    Write-Host "  Arquivos detectados: " -ForegroundColor DarkGray -NoNewline
    Write-Host ($det.Detected -join ", ") -ForegroundColor DarkCyan
    Write-Host ""
}

function Resolve-DetectedValue {
    param(
        [string]$Label,
        [string]$Detected,
        [string]$Override,
        [string]$Example,
        [bool]$AutoMode
    )
    
    # 1. Override por parametro -> usa direto
    if ($Override) { return $Override }
    
    # 2. Modo auto -> usa detectado (ou vazio se nao detectou)
    if ($AutoMode) { return $Detected }
    
    # 3. Modo interativo: mostra detectado e permite alterar
    if ($Detected) {
        $resolvedValue = Read-Host "  $Label [$Detected] (Enter para aceitar, ou digite novo)"
        if ([string]::IsNullOrWhiteSpace($resolvedValue)) { return $Detected }
        return $resolvedValue
    }
    
    # 4. Nada detectado, pedir
    return Read-Host "  $Label (ex: $Example)"
}

# ===============================================================
# MAIN
# ===============================================================

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  IAgentsFactory - Setup (com Auto-Deteccao)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# --- 1. Resolve template path --------------------------------
if (-not $TemplatePath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (Test-Path (Join-Path $scriptDir ".github")) {
        $TemplatePath = $scriptDir
    } else {
        $TemplatePath = Read-Host "Caminho para a pasta IAgentsFactory (ex: C:\IAgentsFactory)"
    }
}

if (-not (Test-Path $TemplatePath)) {
    Write-Host "ERRO: Pasta template nao encontrada em: $TemplatePath" -ForegroundColor Red
    exit 1
}

$targetDir = (Get-Location).Path

# --- 2. Auto-detect project ----------------------------------
Write-Host ""
Write-Host "  Analisando pasta: $targetDir" -ForegroundColor Yellow
Write-Host "  Procurando: pom.xml, package.json, requirements.txt, *.csproj, go.mod, Cargo.toml..." -ForegroundColor DarkGray

$detected = Get-ProjectStackDetails -Dir $targetDir

# --- 2b. Enrich from project docs ----------------------------
$enriched = Get-ProjectDocInsights -Dir $targetDir -Det $detected

if ($detected.Language) {
    Write-Host ""
    Write-Host "  PROJETO DETECTADO!" -ForegroundColor Green
    Show-Detection $detected
    Write-Host "  Linguagem:  $($detected.Language)" -ForegroundColor Green
    Write-Host "  Framework:  $($detected.Framework)" -ForegroundColor Green
    Write-Host "  Build:      $($detected.BuildCmd)" -ForegroundColor Green
    Write-Host "  Test:       $($detected.TestCmd)" -ForegroundColor Green
    Write-Host "  Run:        $($detected.RunCmd)" -ForegroundColor Green
    if ($detected.DbType) {
        Write-Host "  Database:   $($detected.DbType)" -ForegroundColor Green
    }
    if ($detected.PackageBase) {
        Write-Host "  Package:    $($detected.PackageBase)" -ForegroundColor Green
    }
    if ($enriched.Version) {
        Write-Host "  Version:    $($enriched.Version)" -ForegroundColor Green
    }
    if ($enriched.SourceDir) {
        Write-Host "  Source:     $($enriched.SourceDir)/" -ForegroundColor Green
    }
    if ($enriched.TestFw) {
        Write-Host "  Test Fw:    $($enriched.TestFw)" -ForegroundColor Green
    }
    if ($enriched.Logging) {
        Write-Host "  Logging:    $($enriched.Logging)" -ForegroundColor Green
    }
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  Nenhum projeto detectado automaticamente." -ForegroundColor Yellow
    Write-Host "  Respondendo manualmente..." -ForegroundColor Yellow
    Write-Host ""
}

# --- 3. Confirm / override each value ------------------------
$isAuto = $Auto.IsPresent

if ($isAuto -and $detected.Language) {
    Write-Host "  Modo automatico (-Auto): usando todos os valores detectados." -ForegroundColor Cyan
    Write-Host ""
}

$finalName   = Resolve-DetectedValue -Label "Nome do projeto"  -Detected $detected.ProjectName  -Override $ProjectName  -Example "OrderAPI"                    -AutoMode $isAuto
$finalDesc   = Resolve-DetectedValue -Label "Descricao"         -Detected $detected.ProjectDesc  -Override $ProjectDesc  -Example "API REST para pedidos"       -AutoMode $isAuto
$finalLang   = Resolve-DetectedValue -Label "Linguagem"          -Detected $detected.Language     -Override $Language     -Example "Java, TypeScript, Python"    -AutoMode $isAuto
$finalFw     = Resolve-DetectedValue -Label "Framework"          -Detected $detected.Framework    -Override $Framework    -Example "Spring Boot, React, FastAPI" -AutoMode $isAuto
$finalBuild  = Resolve-DetectedValue -Label "Comando de build"   -Detected $detected.BuildCmd     -Override $BuildCmd     -Example "./mvnw clean install"        -AutoMode $isAuto
$finalTest   = Resolve-DetectedValue -Label "Comando de teste"   -Detected $detected.TestCmd      -Override $TestCmd      -Example "./mvnw test"                 -AutoMode $isAuto
$finalRun    = Resolve-DetectedValue -Label "Comando de run"      -Detected $detected.RunCmd       -Override $RunCmd       -Example "java -jar app.jar"           -AutoMode $isAuto
$finalDb     = Resolve-DetectedValue -Label "Banco de dados"      -Detected $detected.DbType       -Override $DbType       -Example "PostgreSQL, MySQL, Oracle"   -AutoMode $isAuto

# --- 4. Summary & confirm ------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  Configuracao Final:" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  Projeto:    $finalName"
Write-Host "  Descricao:  $finalDesc"
Write-Host "  Linguagem:  $finalLang"
Write-Host "  Framework:  $finalFw"
Write-Host "  Build:      $finalBuild"
Write-Host "  Test:       $finalTest"
Write-Host "  Run:        $finalRun"
Write-Host "  Database:   $finalDb"
Write-Host "  Destino:    $targetDir"
Write-Host ""

if (-not $isAuto) {
    $confirm = Read-Host "  Confirmar? (s/n)"
    if ($confirm -ne "s" -and $confirm -ne "S" -and $confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "  Cancelado." -ForegroundColor Yellow
        exit 0
    }
}

# --- 5. Copy template files ----------------------------------
Write-Host ""
Write-Host "  Copiando arquivos do template..." -ForegroundColor Green

$folders = @(".github", "docs", "patterns", "skills", "prompts", "specs")
foreach ($folder in $folders) {
    $src = Join-Path $TemplatePath $folder
    $dst = Join-Path $targetDir $folder
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Recurse -Force
        Write-Host "    OK: $folder/" -ForegroundColor Green
    }
}

# --- 5b. Inject .vscode/mcp.json (Knowledge Hub MCP) ---------
$mcpServerJs = Join-Path $TemplatePath "tools\mcp-knowledge-hub\server.js"
if (Test-Path $mcpServerJs) {
    $vscodeDir = Join-Path $targetDir ".vscode"
    if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null }
    $mcpFile = Join-Path $vscodeDir "mcp.json"
    $escapedPath = $mcpServerJs.Replace('\', '\\')
    $mcpJson = @"
{
    "servers": {
        "iagents-knowledge-hub": {
            "type": "stdio",
            "command": "node",
            "args": ["$escapedPath"],
            "env": {}
        }
    }
}
"@
    Set-Content -Path $mcpFile -Value $mcpJson -Encoding UTF8
    Write-Host "    OK: .vscode/mcp.json (Knowledge Hub MCP)" -ForegroundColor Green
}

# --- 6. Replace placeholders ---------------------------------
Write-Host ""
Write-Host "  Substituindo placeholders..." -ForegroundColor Green

$allFiles = Get-ChildItem -Path $targetDir -Include "*.md" -Recurse | 
    Where-Object { $_.FullName -match '\.github|docs[\\/]|patterns|skills|prompts|specs' }

$replacements = @{
    '\[PROJECT_NAME\]'       = $finalName
    '\[PROJECT_DESC\]'       = $finalDesc
    '\[LANGUAGE\]'           = $finalLang
    '\[FRAMEWORK\]'          = $finalFw
    '\[BUILD_CMD\]'          = $finalBuild
    '\[TEST_CMD\]'           = $finalTest
    '\[RUN_CMD\]'            = $finalRun
    '\[DB_TYPE\]'            = $finalDb
    '\[DATABASE\]'           = $finalDb
    '\[ARCHITECTURE_STYLE\]' = "Layered"
    '\[SOURCE_DIR\]'         = $enriched.SourceDir
    '\[TEST_DIR\]'           = $enriched.TestDir
    '\[CONFIG_FILE\]'        = $enriched.ConfigFile
    '\[TEST_FRAMEWORK\]'     = $enriched.TestFw
    '\[TEST_FW\]'            = $enriched.TestFw
    '\[PKG_MGR\]'            = $enriched.PkgMgr
    '\[RUNTIME\]'            = $enriched.Runtime
    '\[LOGGING\]'            = $enriched.Logging
    '\[ORM\]'                = $enriched.ORM
}

# Version: prioritize language runtime, then project version
$verValue = ""
if ($detected.JavaVersion) { $verValue = $detected.JavaVersion }
elseif ($enriched.Runtime) { $verValue = $enriched.Runtime }
elseif ($enriched.Version) { $verValue = $enriched.Version }
if ($verValue) { $replacements['\[VERSION\]'] = $verValue }

if ($detected.PackageBase) { $replacements['\[PACKAGE_BASE\]'] = $detected.PackageBase }

$fileCount = 0
foreach ($file in $allFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $changed = $false
    
    foreach ($pattern in $replacements.Keys) {
        $val = $replacements[$pattern]
        if ($val -and ($content -match $pattern)) {
            $content = $content -replace $pattern, $val
            $changed = $true
        }
    }
    
    if ($changed) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        $fileCount++
    }
}

Write-Host "    OK: $fileCount arquivos atualizados" -ForegroundColor Green

# --- 6b. Count remaining placeholders ------------------------
$remainingCount = 0
$remainingFiles = @()
foreach ($file in $allFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $found = [regex]::Matches($content, '\[[A-Z_]{3,}\]')
    $relativePath = $file.FullName.Substring($targetDir.Length).TrimStart('\')
    $isTemplateLike = (
        $relativePath -like '.github\agents\*' -or
        $relativePath -like 'patterns\*' -or
        $relativePath -like 'prompts\*' -or
        $relativePath -like 'skills\*' -or
        $relativePath -like 'specs\templates\*' -or
        $file.Name.StartsWith('_example')
    )
    if ($isTemplateLike) {
        continue
    }
    if ($found.Count -gt 0) {
        $remainingCount += $found.Count
        $unique = ($found | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ", "
        $remainingFiles += "    $($file.Name): $unique"
    }
}

# --- 7. Summary ----------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Setup completo! IAgentsFactory aplicado a: $finalName" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Arquivos criados:" -ForegroundColor Yellow
foreach ($folder in $folders) {
    $dst = Join-Path $targetDir $folder
    if (Test-Path $dst) {
        $count = (Get-ChildItem -Path $dst -Recurse -File).Count
        Write-Host "    $folder/ ($count arquivos)" -ForegroundColor White
    }
}
Write-Host ""
Write-Host "  Proximos passos:" -ForegroundColor Yellow
if ($remainingCount -gt 0) {
    Write-Host "    $remainingCount placeholders restantes em $($remainingFiles.Count) arquivos:" -ForegroundColor DarkYellow
    foreach ($rf in $remainingFiles) {
        Write-Host $rf -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "    Revise e preencha manualmente os placeholders [NOME] restantes." -ForegroundColor Yellow
} else {
    Write-Host "    Todos os placeholders foram preenchidos!" -ForegroundColor Green
}
Write-Host ""
Write-Host "  Dicas:" -ForegroundColor DarkGray
Write-Host "    - Arquivos com _ prefixo sao exemplos (copie para criar os seus)" -ForegroundColor DarkGray
Write-Host "    - O Copilot le .github/copilot-instructions.md automaticamente" -ForegroundColor DarkGray
Write-Host "    - Use o agente BACKEND para gerar codigo seguindo os patterns/" -ForegroundColor DarkGray
Write-Host ""

# --- 8. IAgentsFactory: Auto-register project ------------------
$factoryScript = Join-Path $TemplatePath "iagents-factory.ps1"
$factoryDir = Join-Path $env:USERPROFILE ".iagents-factory"
$factoryDb = Join-Path $factoryDir "knowledge.db"

if (Test-Path $factoryScript) {
    Write-Host "  Factory:" -ForegroundColor Cyan
    
    # Auto-init if needed
    if (-not (Test-Path $factoryDb)) {
        Write-Host "    Inicializando Knowledge Hub..." -ForegroundColor DarkGray
        & $factoryScript init
    }
    
    # Register project
    Write-Host "    Registrando projeto na Factory..." -ForegroundColor DarkGray
    & $factoryScript register $targetDir -Language $finalLang -Framework $finalFw -DbType $finalDb
    
    Write-Host "    Use: .\iagents-factory.ps1 search 'query' para buscar solucoes" -ForegroundColor DarkGray
    Write-Host "    Use: .\iagents-factory.ps1 capture para salvar solucoes de agentes" -ForegroundColor DarkGray
    Write-Host ""
}


