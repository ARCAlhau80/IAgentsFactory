'use strict';
/**
 * IAgentsFactory - MCP Knowledge Hub Server
 * Exposes the local Knowledge Hub as an MCP tool for VS Code Copilot.
 *
 * Flow: Copilot Agent calls search_knowledge_hub -> hermes-bridge.ps1 (-Silent -JsonOutput)
 *   Layer 1a: FTS5 keyword search (<0.1s, 0 tokens)
 *   Layer 1b: Vector cosine similarity, nomic-embed-text (0.5-1s, 0 tokens)
 *   Layer 2:  Ollama local gpt-oss:20b (if Layers 1a/1b miss)
 * If found (layer_used >= 1): Copilot uses the hub content.
 * If not found (layer_used = 0): Copilot falls back to its own model.
 *
 * Transport: stdio (newline-delimited JSON-RPC 2.0)
 * No npm dependencies required.
 */

const { spawn } = require('child_process');
const path      = require('path');
const readline  = require('readline');

const BRIDGE_PATH = path.resolve(__dirname, '..', '..', 'hermes-bridge.ps1');
const TIMEOUT_MS  = 30000;

// ---------- MCP wire helpers ----------------------------------------

function send(obj) {
    process.stdout.write(JSON.stringify(obj) + '\n');
}

function respond(id, result) {
    send({ jsonrpc: '2.0', id, result });
}

function respondError(id, code, message) {
    send({ jsonrpc: '2.0', id, error: { code, message } });
}

// ---------- Tool definition -----------------------------------------

const TOOLS = [
    {
        name: 'search_knowledge_hub',
        description:
            'Busca uma solucao no Knowledge Hub local do IAgentsFactory ANTES de usar conhecimento do modelo. ' +
            'Layer 1a: FTS5 keyword (instantaneo, 0 tokens). ' +
            'Layer 1b: busca vetorial semantica com nomic-embed-text (similar mesmo com palavras diferentes). ' +
            'Layer 2: Ollama local gpt-oss:20b (sem custo externo). ' +
            'Se found=true: use o conteudo retornado como base da resposta. ' +
            'Se found=false: use seu proprio conhecimento normalmente.',
        inputSchema: {
            type: 'object',
            properties: {
                query: {
                    type: 'string',
                    description: 'A pergunta ou problema tecnico a buscar no hub local'
                },
                domain: {
                    type: 'string',
                    description: 'Dominio opcional (ex: java, python, devops, finance)'
                },
                language: {
                    type: 'string',
                    description: 'Linguagem de programacao opcional (ex: Java, TypeScript, Python)'
                }
            },
            required: ['query']
        }
    }
];

// ---------- Tool executor -------------------------------------------

function callSearchHub(toolArgs) {
    return new Promise((resolve) => {
        const query    = (toolArgs.query    || '').trim();
        const domain   = (toolArgs.domain   || '').trim();
        const language = (toolArgs.language || '').trim();

        if (!query) {
            resolve({ found: false, reason: 'empty query' });
            return;
        }

        const psArgs = [
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', BRIDGE_PATH,
            '-Query', query,
            '-Silent', '-JsonOutput'
        ];
        if (domain)   psArgs.push('-Domain',   domain);
        if (language) psArgs.push('-Language', language);

        const ps = spawn('powershell.exe', psArgs, { windowsHide: true });
        let stdout = '';
        let stderr = '';
        let settled = false;

        const timer = setTimeout(() => {
            if (!settled) {
                settled = true;
                ps.kill();
                resolve({ found: false, reason: 'timeout' });
            }
        }, TIMEOUT_MS);

        ps.stdout.on('data', (d) => { stdout += d.toString(); });
        ps.stderr.on('data', (d) => { stderr += d.toString(); });

        ps.on('close', () => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);

            try {
                // Bridge may emit log lines before JSON — extract the JSON object
                const jsonMatch = stdout.match(/\{[\s\S]*\}/);
                if (!jsonMatch) {
                    resolve({ found: false, reason: 'no json output' });
                    return;
                }

                const data = JSON.parse(jsonMatch[0]);
                const resolved = data.layer_used > 0
                    && data.content
                    && data.content !== 'EXTERNAL_REQUIRED'
                    && data.content.trim().length > 0;

                if (resolved) {
                    resolve({
                        found:        true,
                        layer:        data.layer_used,
                        resolved_by:  data.resolved_by || 'local',
                        elapsed_sec:  data.elapsed_sec,
                        content:      data.content
                    });
                } else {
                    resolve({ found: false, reason: 'no match above threshold' });
                }
            } catch (e) {
                resolve({ found: false, reason: `parse error: ${e.message}` });
            }
        });

        ps.on('error', (e) => {
            if (!settled) {
                settled = true;
                clearTimeout(timer);
                resolve({ found: false, reason: `spawn error: ${e.message}` });
            }
        });
    });
}

// ---------- MCP request dispatcher ----------------------------------

async function handle(msg) {
    const { id, method, params } = msg;

    // Notifications have no id — never respond
    if (method && method.startsWith('notifications/')) return;

    if (method === 'initialize') {
        respond(id, {
            protocolVersion: '2024-11-05',
            capabilities: { tools: {} },
            serverInfo: { name: 'iagents-knowledge-hub', version: '1.0.0' }
        });
        return;
    }

    if (method === 'tools/list') {
        respond(id, { tools: TOOLS });
        return;
    }

    if (method === 'tools/call') {
        const { name, arguments: toolArgs } = params || {};

        if (name !== 'search_knowledge_hub') {
            respondError(id, -32601, `Tool not found: ${name}`);
            return;
        }

        const result = await callSearchHub(toolArgs || {});

        let text;
        if (result.found) {
            text =
                `[Knowledge Hub - Layer ${result.layer} via ${result.resolved_by}` +
                ` em ${result.elapsed_sec}s]\n\n` +
                result.content;
        } else {
            text =
                `[Knowledge Hub: nenhuma solucao local encontrada` +
                (result.reason ? ` (${result.reason})` : '') +
                `]. Use seu proprio conhecimento para responder.`;
        }

        respond(id, {
            content: [{ type: 'text', text }],
            isError: false
        });
        return;
    }

    // Unknown method with id
    if (id !== undefined && id !== null) {
        respondError(id, -32601, `Method not found: ${method}`);
    }
}

// ---------- Stdio loop ----------------------------------------------

process.stdin.setEncoding('utf8');

let pendingOps = 0;
let stdinClosed = false;

function tryExit() {
    if (stdinClosed && pendingOps === 0) process.exit(0);
}

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });

rl.on('line', async (line) => {
    const trimmed = line.trim();
    if (!trimmed) return;
    try {
        const msg = JSON.parse(trimmed);
        pendingOps++;
        await handle(msg);
    } catch {
        // Malformed input — ignore silently (MCP spec)
    } finally {
        pendingOps--;
        tryExit();
    }
});

rl.on('close', () => {
    stdinClosed = true;
    tryExit();
});
