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
const https     = require('https');

const BRIDGE_PATH = path.resolve(__dirname, '..', '..', 'hermes-bridge.ps1');
const TIMEOUT_MS  = 60000;

// ---------- Layer 3 session state (persists while process runs) ------
const session = {
    webSearchMode: 'default',  // 'default' | 'unlimited' | 'per_search'
    searchCount:   0
};

// ---------- Complexity analyzer -------------------------------------
const HIGH_COMPLEXITY = [
    /arquitetura|architecture/i,
    /design\s+de\s+sistema|system\s+design/i,
    /distribu[ií]d[ao]|distributed/i,
    /microservice|microsservi[çc]o/i,
    /pipeline\s+complexo|complex\s+pipeline/i,
    /estrat[eé]gia\s+de|strategy\s+for/i,
    /refatora[çc][aã]o\s+completa|full\s+refactor/i,
    /integra[çc][aã]o\s+entre.+e\s+/i,
    /como\s+(projetar|desenhar)\s+um/i,
    /event\s+(sourcing|driven)|cqrs|saga\s+pattern/i
];
const MED_COMPLEXITY = [
    /implementar|implement/i,
    /criar|create/i,
    /configurar|configure|setup/i,
    /padr[aã]o|pattern/i,
    /como\s+(fazer|usar|criar)/i,
    /ci\/cd|pipeline/i
];

function analyzeComplexity(query) {
    if (!query) return 'low';
    const wordCount = query.trim().split(/\s+/).length;
    if (HIGH_COMPLEXITY.some(p => p.test(query)) || wordCount > 40) return 'high';
    if (MED_COMPLEXITY.some(p  => p.test(query)) || wordCount > 15) return 'medium_low';
    return 'low';
}

// ---------- Security scanner for web content ------------------------
const WEB_SECURITY_RULES = [
    { id: 'PI-01', sev: 'critical', p: /ignore\s+(previous|all|any)\s+instructions?/i,     label: 'Prompt injection: override instructions' },
    { id: 'PI-02', sev: 'critical', p: /you\s+are\s+now\s+(?:a\s+)?(?!helpful)/i,          label: 'Persona override attempt' },
    { id: 'PI-03', sev: 'critical', p: /<\/?system>|<\/?instructions?>/i,                  label: 'Hidden system tag' },
    { id: 'PI-04', sev: 'critical', p: /\[INST\]|\[\/INST\]|###\s*System:/i,               label: 'Instruction smuggling token' },
    { id: 'MC-01', sev: 'critical', p: /\beval\s*\(|\bexec\s*\(|os\.system\s*\(/i,        label: 'Malicious exec in content' },
    { id: 'MC-02', sev: 'high',     p: /base64.*exec|atob.*eval/i,                          label: 'Base64 obfuscated execution' },
    { id: 'EX-01', sev: 'high',     p: /\$env:.*(curl|wget)|curl.*\$env/i,                  label: 'Env var exfiltration pattern' },
    { id: 'EX-02', sev: 'high',     p: /password\s*=\s*["'][^"']{4,}/i,                    label: 'Hardcoded credential' }
];

function scanWebContent(text) {
    const findings = WEB_SECURITY_RULES
        .filter(r => r.p.test(text))
        .map(r => ({ id: r.id, severity: r.sev, label: r.label }));
    return {
        isClean:     findings.length === 0,
        hasCritical: findings.some(f => f.severity === 'critical'),
        findings
    };
}

// ---------- HTTP GET helper (no external deps) ----------------------
function httpGet(url) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, {
            headers: { 'User-Agent': 'IAgentsFactory/1.0 (research-layer)' },
            timeout: 12000
        }, (res) => {
            let buf = '';
            res.on('data', c => { buf += c; });
            res.on('end',  () => resolve(buf));
        });
        req.on('error',   reject);
        req.on('timeout', () => { req.destroy(); reject(new Error('http_timeout')); });
    });
}

// ---------- DuckDuckGo instant-answer search ------------------------
async function duckSearch(query) {
    const enc = encodeURIComponent(query);
    const raw = await httpGet(
        `https://api.duckduckgo.com/?q=${enc}&format=json&no_html=1&skip_disambig=1`
    );
    const data = JSON.parse(raw);
    const out  = [];

    if (data.AbstractText) {
        out.push({
            title:   data.Heading || query,
            snippet: data.AbstractText,
            url:     data.AbstractURL || '',
            source:  'instant_answer'
        });
    }
    for (const t of (data.RelatedTopics || []).slice(0, 6)) {
        if (t.Text && t.FirstURL) {
            out.push({
                title:   t.Text.split(' - ')[0].substring(0, 80),
                snippet: t.Text,
                url:     t.FirstURL,
                source:  'related'
            });
        }
    }
    return out;
}

// ---------- Tool: web_search_solution --------------------------------
async function callWebSearch(toolArgs) {
    const query      = (toolArgs.query || '').trim();
    const authParam  = toolArgs.authorization || 'auto';
    const complexity = toolArgs.complexity    || analyzeComplexity(query);

    if (!query) return { found: false, error: 'empty query' };

    // --- Authorization gate -----------------------------------------
    const needsConfirm =
        (session.webSearchMode === 'per_search' &&
            authParam !== 'user_approved' && authParam !== 'session_unlimited') ||
        (session.webSearchMode === 'default' && complexity === 'high' &&
            authParam !== 'user_approved' && authParam !== 'session_unlimited');

    if (needsConfirm) {
        const isHigh = complexity === 'high';
        return {
            found: false,
            requires_user_confirmation: true,
            complexity,
            message: isHigh
                ? `[Layer 3 — Web Search] Complexidade **alta** detectada.\n\n` +
                  `Esta consulta envolve um tópico abrangente e pode se beneficiar de uma pesquisa mais profunda na internet.\n\n` +
                  `**Deseja que eu pesquise online?**\n` +
                  `- **sim** → autorizo esta pesquisa\n` +
                  `- **pesquisas ilimitadas** → autorizo todas as pesquisas desta sessão\n` +
                  `- **não** → use apenas conhecimento interno`
                : `[Layer 3 — Web Search] Aguardando autorização para esta pesquisa (modo per_search).\n\n` +
                  `Query: "${query}" | Complexidade: ${complexity}\n` +
                  `Responda **sim** para autorizar ou chame novamente com authorization='user_approved'.`
        };
    }

    // --- Execute search ---------------------------------------------
    session.searchCount++;
    let raw;
    try { raw = await duckSearch(query); }
    catch (e) { return { found: false, error: `search_failed: ${e.message}` }; }

    if (!raw || raw.length === 0) {
        return { found: false, reason: 'no_results', complexity };
    }

    // --- Security scan each result ----------------------------------
    const safe    = [];
    const blocked = [];
    for (const r of raw) {
        const scan = scanWebContent(`${r.title} ${r.snippet}`);
        if (scan.hasCritical) {
            blocked.push({ url: r.url, findings: scan.findings.map(f => f.label) });
        } else {
            const entry = { title: r.title, snippet: r.snippet, url: r.url, source: r.source };
            if (scan.findings.length > 0)
                entry.security_warnings = scan.findings.map(f => f.label);
            safe.push(entry);
        }
    }

    if (safe.length === 0) {
        return {
            found:          false,
            security_alert: true,
            blocked_count:  blocked.length,
            reason:         'all_results_blocked_by_security_scan'
        };
    }

    // --- Build explanation text -------------------------------------
    const explanationParts = safe.map((r, i) =>
        `**[${i + 1}] ${r.title}**\n${r.snippet}\nFonte: ${r.url}`
    );

    return {
        found:                          true,
        layer:                          3,
        resolved_by:                    'web_search_duckduckgo',
        complexity,
        search_number:                  session.searchCount,
        results:                        safe,
        blocked_results:                blocked.length,
        requires_implementation_approval: true,
        explanation:
            `[Layer 3 — Web Search #${session.searchCount}] Resultados para: "${query}"\n\n` +
            explanationParts.join('\n\n') +
            (blocked.length > 0 ? `\n\n⚠️ ${blocked.length} resultado(s) bloqueado(s) pela varredura de segurança.` : '') +
            `\n\n---\n⚠️ **Antes de implementar:** Revisei os resultados acima. Posso prosseguir com a implementação?`
    };
}

// ---------- Tool: set_search_authorization --------------------------
function setSearchAuthorization(toolArgs) {
    const mode = (toolArgs.mode || '').toLowerCase();
    if (mode === 'unlimited') {
        session.webSearchMode = 'unlimited';
        return {
            success: true, mode: 'unlimited',
            message: '[Layer 3] ✅ Modo **pesquisas ilimitadas** ativado para esta sessão.\n' +
                     'Todas as buscas web serão executadas automaticamente sem solicitar autorização.'
        };
    }
    if (mode === 'per_search') {
        session.webSearchMode = 'per_search';
        return {
            success: true, mode: 'per_search',
            message: '[Layer 3] ✅ Modo **autorizar por pesquisa** ativado.\n' +
                     'Cada busca web solicitará sua confirmação antes de executar.'
        };
    }
    return { success: false, message: `Modo inválido: '${mode}'. Use 'unlimited' ou 'per_search'.` };
}

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
            'Layer 3: se found=false, o resultado inclui complexity e web_search_available=true. ' +
            'Para complexidade low/medium_low: chame web_search_solution diretamente. ' +
            'Para complexidade high: pergunte ao usuario antes de chamar web_search_solution. ' +
            'Se found=true: use o conteudo retornado como base da resposta.',
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
    },
    {
        name: 'web_search_solution',
        description:
            'Layer 3: Busca solucao na internet via DuckDuckGo quando o Hub local nao encontrou resposta. ' +
            'REGRA DE USO: ' +
            '(1) Para complexidade low/medium_low: chame com authorization=auto diretamente. ' +
            '(2) Para complexidade high: pergunte ao usuario antes de chamar. ' +
            '(3) Se session mode=per_search: sempre pergunte ao usuario antes. ' +
            'SEGURANCA: resultados sao varridos automaticamente contra prompt injection e codigo malicioso. ' +
            'IMPLEMENTACAO: quando found=true, sempre explique a solucao ao usuario ANTES de implementar e aguarde aprovacao.',
        inputSchema: {
            type: 'object',
            properties: {
                query: {
                    type: 'string',
                    description: 'Consulta de pesquisa em linguagem natural'
                },
                complexity: {
                    type: 'string',
                    enum: ['low', 'medium_low', 'high'],
                    description: 'Complexidade estimada da consulta (opcional — calculada automaticamente se omitida)'
                },
                authorization: {
                    type: 'string',
                    enum: ['auto', 'user_approved', 'session_unlimited'],
                    description: 'auto=verificar modo sessao; user_approved=usuario aceitou esta pesquisa; session_unlimited=ilimitado ja ativado'
                }
            },
            required: ['query']
        }
    },
    {
        name: 'set_search_authorization',
        description:
            'Define o modo de autorizacao para pesquisas web (Layer 3) desta sessao. ' +
            'Use quando o usuario disser: "pesquisas ilimitadas" -> mode=unlimited. ' +
            'Use quando o usuario disser: "autorizar cada pesquisa" ou "perguntar antes" -> mode=per_search.',
        inputSchema: {
            type: 'object',
            properties: {
                mode: {
                    type: 'string',
                    enum: ['unlimited', 'per_search'],
                    description: 'unlimited=pesquisar sem pedir permissao; per_search=pedir autorizacao em cada busca'
                }
            },
            required: ['mode']
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
                    const complexity = analyzeComplexity(query);
                    resolve({
                        found:                false,
                        reason:              'no match above threshold',
                        complexity,
                        web_search_available: true,
                        web_search_hint:
                            complexity === 'high'
                                ? 'Complexidade alta — pergunte ao usuario se deseja pesquisa web antes de chamar web_search_solution.'
                                : 'Complexidade baixa/media — voce pode chamar web_search_solution diretamente com authorization=auto.'
                    });
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

        if (name === 'web_search_solution') {
            const wsResult = await callWebSearch(toolArgs || {});
            let wsText;
            if (wsResult.requires_user_confirmation) {
                wsText = wsResult.message;
            } else if (wsResult.found) {
                wsText = wsResult.explanation;
            } else {
                wsText = `[Layer 3 — Web Search] Nenhum resultado encontrado` +
                    (wsResult.reason   ? ` (${wsResult.reason}).`   : '.') +
                    (wsResult.error    ? `\nErro: ${wsResult.error}` : '') +
                    (wsResult.security_alert ? `\n⚠️ ALERTA DE SEGURANÇA: ${wsResult.blocked_count} resultado(s) bloqueado(s).` : '');
            }
            respond(id, { content: [{ type: 'text', text: wsText }], isError: false });
            return;
        }

        if (name === 'set_search_authorization') {
            const authResult = setSearchAuthorization(toolArgs || {});
            respond(id, { content: [{ type: 'text', text: authResult.message }], isError: false });
            return;
        }

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
            const hint = result.web_search_hint || '';
            const cplx = result.complexity ? ` | complexidade: ${result.complexity}` : '';
            text =
                `[Knowledge Hub: nenhuma solucao local encontrada` +
                (result.reason ? ` (${result.reason})` : '') +
                `${cplx}]\n\n` +
                (hint ? `${hint}\n` : '') +
                (result.web_search_available
                    ? `\nPara buscar na internet: chame \`web_search_solution\` com a mesma query.`
                    : `Use seu proprio conhecimento para responder.`);
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
