---
domain: mcp
pattern: multi-project-propagation
language: powershell
framework: vscode
agent: claude-sonnet
quality: 0.93
tags: mcp, vscode, copilot, multi-project, propagation, factory, update-mcp, mcp.json
---

## Prompt

Tenho um servidor MCP (Knowledge Hub) rodando em um repositorio central (IAgentsFactory).
Como propagar automaticamente a configuracao .vscode/mcp.json para todos os projetos
registrados na factory, sem ter que configurar manualmente cada um? E como garantir que
novos projetos ja nascem com a configuracao MCP?

## Solution

Estrategia: o MCP server vive em um repositorio central (IAgentsFactory). Cada projeto
precisa apenas de um .vscode/mcp.json com o caminho ABSOLUTO para o server.js.

Dois mecanismos complementares:

**1. Comando update-mcp (para projetos existentes)**

```powershell
# iagents-factory.ps1 - Invoke-UpdateMcp
function Invoke-UpdateMcp {
    param([string]$TargetPath)

    $serverJs = Join-Path $PSScriptRoot "tools\mcp-knowledge-hub\server.js"
    $mcpContent = @"
{
    "servers": {
        "iagents-knowledge-hub": {
            "type": "stdio",
            "command": "node",
            "args": ["$($serverJs.Replace('\', '\\'))"],
            "env": {}
        }
    }
}
"@

    # Pega todos os projetos registrados ou projeto especifico
    $rows = if ($TargetPath) {
        @([pscustomobject]@{ Name = Split-Path -Leaf $TargetPath; Path = $TargetPath })
    } else {
        # Le factory_projects do SQLite
        $rows = Invoke-Sql -Query 'SELECT name, path FROM factory_projects WHERE is_active = 1;'
    }

    foreach ($proj in $rows) {
        $vscodeDir = Join-Path $proj.Path ".vscode"
        if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null }
        Set-Content -Path (Join-Path $vscodeDir "mcp.json") -Value $mcpContent -Encoding UTF8
        Write-Host "[OK] $($proj.Name) -> .vscode/mcp.json"
    }
}

# Uso: propagar para todos os projetos de uma vez
.\iagents-factory.ps1 update-mcp

# Ou para projeto especifico
.\iagents-factory.ps1 update-mcp "C:\projetos\meu-app"
```

**2. Auto-inject no setup-ia-squad.ps1 (para projetos novos)**

```powershell
# setup-ia-squad.ps1 - secao apos copiar templates
$mcpServerJs = Join-Path $TemplatePath "tools\mcp-knowledge-hub\server.js"
if (Test-Path $mcpServerJs) {
    $vscodeDir = Join-Path $targetDir ".vscode"
    if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null }
    $escapedPath = $mcpServerJs.Replace('\', '\\')
    $mcpJson = "{`n    `"servers`": {`n        `"iagents-knowledge-hub`": {`n            `"type`": `"stdio`",`n            `"command`": `"node`",`n            `"args`": [`"$escapedPath`"],`n            `"env`": {}`n        }`n    }`n}`n"
    Set-Content -Path (Join-Path $vscodeDir "mcp.json") -Value $mcpJson -Encoding UTF8
    Write-Host "OK: .vscode/mcp.json (Knowledge Hub MCP)"
}
```

**Importante: caminho ABSOLUTO, nao ${workspaceFolder}**
- `${workspaceFolder}` so funciona se o workspace aberto for o IAgentsFactory
- Para outros projetos, usar caminho absoluto para o server.js central
- O server.js e um arquivo Node.js puro (~80 linhas, sem npm deps), seguro manter centralizado

**Fluxo do usuario apos update-mcp:**
1. Abrir o projeto no VS Code
2. Aceitar prompt "Start MCP Server: iagents-knowledge-hub"
3. Em Agent mode, Copilot chama search_knowledge_hub automaticamente antes de responder

## Summary

Para propagar MCP server central a todos os projetos: 1) Comando update-mcp itera factory_projects no SQLite e cria .vscode/mcp.json com caminho absoluto em cada projeto. 2) setup-ia-squad.ps1 auto-injeta mcp.json em novos projetos. Usar caminho absoluto, nao ${workspaceFolder}, pois o server vive no repositorio central, nao no projeto alvo.
