# ===============================================================
# IAgentsFactory - Knowledge Capture Pipeline
#
# Supported modes:
#   .\capture-pipeline.ps1 -Watch
#   .\capture-pipeline.ps1 -FromFile path\to\file.solution.md
#   .\capture-pipeline.ps1 -FromGit
#   .\capture-pipeline.ps1 -Batch path\to\directory
# ===============================================================

param(
    [switch]$Watch,
    [string]$FromFile,
    [switch]$FromGit,
    [string]$Batch,
    [string]$Project = "",
    [switch]$DryRun,
    [switch]$VerboseLog
)

try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = $utf8
    [Console]::OutputEncoding = $utf8
    $OutputEncoding = $utf8
} catch {
}

$ErrorActionPreference = "Stop"

$FACTORY_DIR = Join-Path $env:USERPROFILE ".iagents-factory"
$DB_PATH = Join-Path $FACTORY_DIR "knowledge.db"
$CAPTURE_LOG = Join-Path $FACTORY_DIR "capture-log.json"
$TRACE_LOG = Join-Path $FACTORY_DIR "capture-debug.log"

function Write-Pipeline {
    param([string]$Text)
    Write-Host "  [PIPELINE] $Text" -ForegroundColor Magenta
}

function Write-TraceLog {
    param([string]$Text)

    if (-not $VerboseLog) {
        return
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    Add-Content -Path $TRACE_LOG -Value ("[{0}] {1}" -f $timestamp, $Text) -Encoding UTF8
}

function Ensure-KnowledgeHub {
    if (-not (Test-Path $DB_PATH)) {
        throw "Knowledge Hub not initialized. Run .\iagents-factory.ps1 init"
    }
}

function Get-SqliteCommand {
    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite) {
        throw "sqlite3.exe not found in PATH"
    }

    return $sqlite.Source
}

function Convert-ToSqlLiteral {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return $Text.Replace("'", "''")
}

function Get-ContentHash {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLower()
    } finally {
        $sha.Dispose()
    }
}

function Get-TokenEstimate {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return 0
    }

    return [math]::Ceiling($Text.Length / 4)
}

function Invoke-SqlNonQuery {
    param([string]$Query)

    $sqlite = Get-SqliteCommand
    $tempSqlFile = Join-Path $env:TEMP ("iagents-capture-{0}.sql" -f ([guid]::NewGuid().ToString("N")))
    Set-Content -Path $tempSqlFile -Value $Query -Encoding UTF8
    try {
        $output = & $sqlite $DB_PATH ".read $tempSqlFile" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw (("sqlite3 failed: {0}" -f ($output | Out-String).Trim()).Trim())
        }

        return ($output | Out-String).Trim()
    } finally {
        Remove-Item -Path $tempSqlFile -ErrorAction SilentlyContinue
    }
}

function Parse-FrontmatterValue {
    param(
        [string]$Frontmatter,
        [string]$Key,
        [string]$DefaultValue = ""
    )

    $pattern = "(?im)^" + [regex]::Escape($Key) + ":\s*(.+)$"
    $match = [regex]::Match($Frontmatter, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $DefaultValue
}

function Parse-SolutionFile {
    param([string]$FilePath)

    Write-TraceLog ("Parse-SolutionFile:start file={0}" -f $FilePath)
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8

    $frontmatterMatch = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---\r?\n?')
    $frontmatter = ""
    if ($frontmatterMatch.Success) {
        $frontmatter = $frontmatterMatch.Groups[1].Value
    }

    $promptMatch = [regex]::Match($content, '(?s)## Prompt\r?\n(.*?)(?=\r?\n## Solution)')
    $solutionMatch = [regex]::Match($content, '(?s)## Solution\r?\n(.*?)(?=\r?\n## Summary|$)')
    $summaryMatch = [regex]::Match($content, '(?s)## Summary\r?\n(.*?)$')

    $tags = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "tags"
    $qualityText = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "quality" -DefaultValue "0.8"
    $quality = 0.8
    $parsedQuality = 0.8
    if ([double]::TryParse($qualityText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedQuality)) {
        $quality = $parsedQuality
    }

    $result = @{
        domain = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "domain" -DefaultValue "general"
        pattern = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "pattern" -DefaultValue "general"
        language = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "language"
        framework = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "framework"
        agent = Parse-FrontmatterValue -Frontmatter $frontmatter -Key "agent"
        quality = $quality
        tags = @()
        prompt = ""
        solution = ""
        summary = ""
    }

    if ($tags) {
        $result.tags = @($tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    if ($promptMatch.Success) {
        $result.prompt = $promptMatch.Groups[1].Value.Trim()
    }
    if ($solutionMatch.Success) {
        $result.solution = $solutionMatch.Groups[1].Value.Trim()
    }
    if ($summaryMatch.Success) {
        $result.summary = $summaryMatch.Groups[1].Value.Trim()
    }

    Write-TraceLog ("Parse-SolutionFile:solution-length={0}" -f $result.solution.Length)
    return $result
}

function Update-CaptureLog {
    param(
        [string]$Id,
        [string]$Domain,
        [string]$Pattern,
        [string]$Hash
    )

    $captures = @()
    if (Test-Path $CAPTURE_LOG) {
        $existing = Get-Content -Path $CAPTURE_LOG -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($existing.captures) {
            $captures = @($existing.captures)
        }
    }

    $captures += @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        id = $Id
        domain = $Domain
        pattern = $Pattern
        hash = $Hash.Substring(0, 16)
    }

    @{ captures = $captures } | ConvertTo-Json -Depth 10 | Set-Content -Path $CAPTURE_LOG -Encoding UTF8
}

function Save-Solution {
    param([hashtable]$SolutionData)

    Write-TraceLog "Save-Solution:start"
    if ($DryRun) {
        Write-Pipeline ("DRY RUN: {0}/{1} ({2})" -f $SolutionData.domain, $SolutionData.pattern, $SolutionData.language)
        Write-Pipeline ("Summary: {0}" -f $SolutionData.summary)
        return
    }

    $id = [guid]::NewGuid().ToString("N").Substring(0, 12)
    $hash = Get-ContentHash -Text $SolutionData.solution
    $tagsJson = "[" + (($SolutionData.tags | ForEach-Object { '"' + ($_ -replace '"', '\\"') + '"' }) -join ",") + "]"
    $tokensInput = Get-TokenEstimate -Text $SolutionData.prompt
    $tokensOutput = Get-TokenEstimate -Text $SolutionData.solution

    $query = @"
INSERT OR IGNORE INTO learned_solutions
    (id, domain, pattern, language, framework, source_project, source_agent,
     prompt_used, solution_content, solution_summary, content_hash,
     quality_score, tokens_input, tokens_output, tags)
VALUES
    ('$id',
     '$(Convert-ToSqlLiteral $SolutionData.domain)',
     '$(Convert-ToSqlLiteral $SolutionData.pattern)',
     '$(Convert-ToSqlLiteral $SolutionData.language)',
     '$(Convert-ToSqlLiteral $SolutionData.framework)',
     '$(Convert-ToSqlLiteral $Project)',
     '$(Convert-ToSqlLiteral $SolutionData.agent)',
     '$(Convert-ToSqlLiteral $SolutionData.prompt)',
     '$(Convert-ToSqlLiteral $SolutionData.solution)',
     '$(Convert-ToSqlLiteral $SolutionData.summary)',
     '$hash',
     $($SolutionData.quality),
     $tokensInput,
     $tokensOutput,
     '$(Convert-ToSqlLiteral $tagsJson)');
SELECT changes();
"@

    $result = Invoke-SqlNonQuery -Query $query
    Write-TraceLog ("Save-Solution:sql-result={0}" -f $result)

    if ($result -notmatch '1') {
        Write-Pipeline ("Ignored duplicate solution (hash {0})" -f $hash.Substring(0, 16))
        return
    }

    Update-CaptureLog -Id $id -Domain $SolutionData.domain -Pattern $SolutionData.pattern -Hash $hash
    Write-Pipeline ("Captured: {0}/{1} [ID: {2}]" -f $SolutionData.domain, $SolutionData.pattern, $id)
}

function Import-FromFile {
    param([string]$FilePath)

    Write-TraceLog ("Import-FromFile:start file={0}" -f $FilePath)
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    Write-Pipeline ("Importing from: {0}" -f $FilePath)
    $data = Parse-SolutionFile -FilePath $FilePath
    if ([string]::IsNullOrWhiteSpace($data.solution)) {
        throw "File does not contain a ## Solution section"
    }

    Save-Solution -SolutionData $data
}

function Import-FromGit {
    Write-Pipeline "Scanning recent commits for .solution.md files"
    $files = git log --name-only --pretty=format: -20 2>$null | Where-Object { $_ -match '\.solution\.md$' } | Select-Object -Unique
    foreach ($file in $files) {
        if (Test-Path $file) {
            Import-FromFile -FilePath $file
        }
    }
}

function Import-Batch {
    param([string]$DirectoryPath)

    if (-not (Test-Path $DirectoryPath)) {
        throw "Directory not found: $DirectoryPath"
    }

    $files = Get-ChildItem -Path $DirectoryPath -Filter "*.solution.md" -Recurse -File
    if (-not $files) {
        Write-Pipeline ("No .solution.md files found in: {0}" -f $DirectoryPath)
        return
    }

    foreach ($file in $files) {
        Import-FromFile -FilePath $file.FullName
    }
}

function Start-Watch {
    Write-Pipeline "Watch mode enabled. Monitoring clipboard every 2 seconds."
    Write-Pipeline "Press Ctrl+C to stop."
    $lastClipboard = ""

    while ($true) {
        Start-Sleep -Seconds 2
        try {
            $clipboardText = Get-Clipboard -Raw -ErrorAction Stop
        } catch {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($clipboardText) -or $clipboardText -eq $lastClipboard) {
            continue
        }

        if ($clipboardText -match '(?s)^---\r?\n.*?\r?\n---.*?## Solution') {
            $tempFile = Join-Path $env:TEMP ("iagents-watch-{0}.solution.md" -f ([guid]::NewGuid().ToString("N")))
            try {
                Set-Content -Path $tempFile -Value $clipboardText -Encoding UTF8
                $lastClipboard = $clipboardText
                Import-FromFile -FilePath $tempFile
            } finally {
                Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
            }
        }
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "  IAgentsFactory - Capture Pipeline" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    .\capture-pipeline.ps1 -Watch" -ForegroundColor White
    Write-Host "    .\capture-pipeline.ps1 -FromFile X.solution.md" -ForegroundColor White
    Write-Host "    .\capture-pipeline.ps1 -FromGit" -ForegroundColor White
    Write-Host "    .\capture-pipeline.ps1 -Batch <dir>" -ForegroundColor White
    Write-Host ""
    Write-Host "  Flags:" -ForegroundColor Yellow
    Write-Host "    -Project <name>     Associate capture with a project" -ForegroundColor White
    Write-Host "    -DryRun             Parse only, do not write to DB" -ForegroundColor White
    Write-Host "    -VerboseLog         Write debug trace to ~/.iagents-factory/capture-debug.log" -ForegroundColor White
    Write-Host ""
}

try {
    Ensure-KnowledgeHub

    if ($VerboseLog) {
        Set-Content -Path $TRACE_LOG -Value "" -Encoding UTF8
        Write-TraceLog "Main:start"
    }

    if ($Watch) {
        Start-Watch
    } elseif ($FromFile) {
        Import-FromFile -FilePath $FromFile
    } elseif ($FromGit) {
        Import-FromGit
    } elseif ($Batch) {
        Import-Batch -DirectoryPath $Batch
    } else {
        Show-Help
    }
} catch {
    Write-Host ("  [ERROR] {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-TraceLog ("Main:error={0}" -f $_.Exception.Message)
    exit 1
}

