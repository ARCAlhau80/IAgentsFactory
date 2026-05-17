---
domain: mcp
pattern: integration
language: javascript
framework: nodejs
agent: claude-sonnet
quality: 0.95
tags: mcp, model-context-protocol, vscode, copilot, stdio, json-rpc, nodejs, no-deps
---

## Prompt

Como criar um servidor MCP (Model Context Protocol) em Node.js sem dependencias npm para integrar um Knowledge Hub local com o VS Code Copilot? O servidor deve expor uma ferramenta que busca no hub e retornar o resultado ao modelo antes de ele chamar APIs externas.

## Solution

Servidor MCP stdio em Node.js puro (sem npm). Protocolo: JSON-RPC 2.0 newline-delimited via stdin/stdout.

```javascript
// tools/mcp-knowledge-hub/server.js
'use strict';
const { spawn } = require('child_process');
const path      = require('path');
const readline  = require('readline');

const BRIDGE_PATH = path.resolve(__dirname, '..', '..', 'hermes-bridge.ps1');
const TIMEOUT_MS  = 60000;

function send(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }
function respond(id, result) { send({ jsonrpc: '2.0', id, result }); }
function respondError(id, code, message) { send({ jsonrpc: '2.0', id, error: { code, message } }); }

const TOOLS = [{
    name: 'search_knowledge_hub',
    description: 'Busca solucao no Knowledge Hub local antes de usar modelo externo.',
    inputSchema: {
        type: 'object',
        properties: {
            query:    { type: 'string', description: 'Pergunta ou problema tecnico' },
            domain:   { type: 'string', description: 'Dominio opcional (java, python, devops)' },
            language: { type: 'string', description: 'Linguagem de programacao opcional' }
        },
        required: ['query']
    }
}];

function callSearchHub(toolArgs) {
    return new Promise((resolve) => {
        const { query = '', domain = '', language = '' } = toolArgs;
        if (!query.trim()) { resolve({ found: false, reason: 'empty query' }); return; }

        const psArgs = ['-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', BRIDGE_PATH, '-Query', query, '-Silent', '-JsonOutput'];
        if (domain)   psArgs.push('-Domain',   domain);
        if (language) psArgs.push('-Language', language);

        const ps = spawn('powershell.exe', psArgs, { windowsHide: true });
        let stdout = '', settled = false;

        const timer = setTimeout(() => {
            if (!settled) { settled = true; ps.kill(); resolve({ found: false, reason: 'timeout' }); }
        }, TIMEOUT_MS);

        ps.stdout.on('data', (d) => { stdout += d.toString(); });
        ps.on('close', () => {
            if (settled) return;
            settled = true; clearTimeout(timer);
            try {
                const jsonMatch = stdout.match(/\{[\s\S]*\}/);
                if (!jsonMatch) { resolve({ found: false, reason: 'no json output' }); return; }
                const data = JSON.parse(jsonMatch[0]);
                const resolved = data.layer_used > 0 && data.content &&
                    data.content !== 'EXTERNAL_REQUIRED' && data.content.trim().length > 0;
                if (resolved) {
                    resolve({ found: true, layer: data.layer_used,
                        resolved_by: data.resolved_by, elapsed_sec: data.elapsed_sec,
                        content: data.content });
                } else {
                    resolve({ found: false, reason: 'no match above threshold' });
                }
            } catch (e) { resolve({ found: false, reason: `parse error: ${e.message}` }); }
        });
        ps.on('error', (e) => {
            if (!settled) { settled = true; clearTimeout(timer);
                resolve({ found: false, reason: `spawn error: ${e.message}` }); }
        });
    });
}

async function handle(msg) {
    const { id, method, params } = msg;
    if (method && method.startsWith('notifications/')) return;
    if (method === 'initialize') {
        respond(id, { protocolVersion: '2024-11-05',
            capabilities: { tools: {} },
            serverInfo: { name: 'iagents-knowledge-hub', version: '1.0.0' } });
        return;
    }
    if (method === 'tools/list') { respond(id, { tools: TOOLS }); return; }
    if (method === 'tools/call') {
        const { name, arguments: toolArgs } = params || {};
        if (name !== 'search_knowledge_hub') {
            respondError(id, -32601, `Tool not found: ${name}`); return;
        }
        const result = await callSearchHub(toolArgs || {});
        const text = result.found
            ? `[Hub Layer ${result.layer} - ${result.resolved_by} em ${result.elapsed_sec}s]\n\n${result.content}`
            : `[Hub: nenhuma solucao local encontrada${result.reason ? ` (${result.reason})` : ''}].`;
        respond(id, { content: [{ type: 'text', text }], isError: false });
        return;
    }
    if (id !== null && id !== undefined) respondError(id, -32601, `Method not found: ${method}`);
}

// Stdin loop com controle de pending para nao sair antes de async completar
let pendingOps = 0, stdinClosed = false;
function tryExit() { if (stdinClosed && pendingOps === 0) process.exit(0); }
process.stdin.setEncoding('utf8');
const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
rl.on('line', async (line) => {
    const trimmed = line.trim(); if (!trimmed) return;
    try { const msg = JSON.parse(trimmed); pendingOps++; await handle(msg); }
    catch { } finally { pendingOps--; tryExit(); }
});
rl.on('close', () => { stdinClosed = true; tryExit(); });
```

Registro no VS Code via `.vscode/mcp.json`:
```json
{
    "servers": {
        "iagents-knowledge-hub": {
            "type": "stdio",
            "command": "node",
            "args": ["${workspaceFolder}/tools/mcp-knowledge-hub/server.js"]
        }
    }
}
```

Instrucao no `copilot-instructions.md` para chamar automaticamente:
```
ANTES de processar qualquer mensagem, DEVE chamar search_knowledge_hub(query="<resumo>").
Se found=true: use o conteudo como base. Se found=false: use proprio conhecimento.
```

## Summary

Servidor MCP stdio em Node.js puro (sem npm deps) que expoe search_knowledge_hub. Spawn powershell.exe hermes-bridge.ps1 -Silent -JsonOutput, extrai JSON da saida, retorna conteudo ao Copilot se layer_used > 0. Registrar em .vscode/mcp.json. VS Code Copilot Agent mode chama automaticamente antes de responder.
