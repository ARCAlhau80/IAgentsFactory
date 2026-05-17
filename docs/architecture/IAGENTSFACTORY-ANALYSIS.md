# 🏭 Análise Técnica: IAgentsFactory — Fábrica de Software com Memória Persistente e IA Local

**Criado em:** 2026-04-06  
**Atualizado em:** 2026-05-17 (Hermes Edition)  
**Autor:** AR CALHAU (assistido por COORDINATOR Agent)  
**Status:** ✅ Operacional  
**Versão:** 3.0.0

---

## 1. Sumário Executivo

O **IAgentsFactory** é uma **Fábrica de Software Multi-Projeto** com **Memória de Longa Duração** e **IA Local Integrada**, capaz de:

1. Reter, indexar e reutilizar conhecimento adquirido em interações com agentes externos (Claude, GPT-4o, DeepSeek, etc.)
2. Resolver consultas localmente via **Hermes Agent + Ollama** antes de consumir tokens externos
3. Orquestrar o desenvolvimento com fluxo `constitution → specify → plan → tasks → analyze`
4. Garantir qualidade via Engineering Pillars (Security, Architecture, Quality, DevOps)

**Objetivo primário:** Minimizar o custo com provedores externos via uma arquitetura de resolução em **3 camadas** onde o mais caro só é acionado quando o mais barato não resolve.

---

## 2. Análise do Estado Atual (AS-IS → v3.0)

### 2.1 Evolução do Produto

| Versão | Data | Novidades Principais |
|--------|------|---------------------|
| 1.0 | Abr 2026 | Knowledge Hub (SQLite+FTS5), CLI, captura automática |
| 2.0 | Mai 2026 | Engineering Pillars, SPEC workflow, fluxo constitution→analyze |
| **3.0** | **Mai 2026** | **Hermes Agent + Ollama local, resolução 3 camadas, auto-update** |

### 2.2 Estado Atual dos Componentes

| Componente | Estado | Descrição |
|------------|--------|-----------|
| Knowledge Hub | ✅ Operacional | SQLite+FTS5, search, capture, stats |
| SPEC Workflow | ✅ Operacional | constitution/specify/plan/tasks/analyze |
| Engineering Pillars | ✅ Operacional | checklists + gate em new-project.ps1 |
| Dashboard | ✅ Operacional | Node.js local, knowledge.db |
| Hermes Bridge | ✅ Implementado | 3-layer resolution, hermes-bridge.ps1 |
| Hermes Setup | ✅ Implementado | auto-install WSL2+Ollama, setup-hermes.ps1 |
| Auto-update | ✅ Implementado | Task Scheduler, hermes-update.ps1 |
| Memory Sync | ✅ Implementado | bidirecional, hermes-sync.ps1 |

---

## 3. Arquitetura v3.0 — 3-Layer Resolution

### 3.1 Visão Geral

### 2.1 A Base Conceitual Herdada do ISGT

| Aspecto | Estado |
|---------|--------|
| **Tipo** | Template de markdown (ADK — AI Development Kit) |
| **Agentes** | 6 especialistas (ARCHITECT, BACKEND, QA, REFACTOR, COORDINATOR, OBSERVABILITY) |
| **Patterns** | 7 templates reutilizáveis (controller, service, repository, entity, dto, visitor) |
| **Skills** | 9 guias how-to (testing, clean-arch, security, DDD, API design, etc.) |
| **Prompts** | 24 prompts prontos organizados por categoria |
| **Setup** | PowerShell auto-detect (Java, Node, Python, C#, Go, Rust) |
| **Multi-projeto** | ❌ Não — cada projeto é independente |
| **Memória** | ❌ Não — cada sessão começa do zero |
| **Persistência** | ❌ Não — soluções se perdem ao fechar a conversa |

### 2.2 Limitações Identificadas

| # | Limitação | Impacto |
|---|-----------|---------|
| 1 | Sem memória entre sessões | Repetição de perguntas → desperdício de tokens |
| 2 | Sem compartilhamento entre projetos | Conhecimento isolado por repo |
| 3 | Sem captura de aprendizado | Soluções de agentes externos se perdem |
| 4 | Single-project design | Não gerencia múltiplos projetos |
| 5 | Sem métricas de uso | Impossível medir economia ou ROI |
| 6 | Dependência total de agentes externos | Sem fallback offline |

---

## 3. Componentes Analisados para a Evolução

### 3.1 ISGT (Projeto Atual)

**Papel futuro:** Orquestrador central — templates, agents, standards, project registry

| Força | Fraqueza |
|-------|----------|
| 6 agents especializados | Sem persistência |
| 7+ patterns prontos | Single-project |
| Auto-detect de stack | Sem knowledge capture |
| AI-agnostic | Sem métricas |

### 3.2 MCP Graph Workflow (Local — v4.2.0)

**Localização:** `C:\Users\AR CALHAU\source\repos\mcp-graph-workflow`  
**Papel futuro:** Motor de persistência — Knowledge Hub com RAG local

| Capacidade | Detalhe |
|------------|---------|
| **Banco** | SQLite WAL + FTS5 full-text search |
| **RAG Local** | TF-IDF embeddings (100% offline) |
| **MCP Tools** | 26 ferramentas via Model Context Protocol |
| **Compressão** | 70-85% redução de tokens no contexto |
| **Knowledge Store** | SHA-256 dedup, 5 tipos de fonte |
| **REST API** | 44 endpoints, 17 routers (Express v5) |
| **Dashboard** | React 19 + Tailwind + React Flow + D3 |
| **Integrations** | Event-driven (Serena, GitNexus, Context7, Playwright) |
| **Snapshots** | Versionamento de grafos (time travel) |
| **Testes** | 910+ unit/integration + 11 E2E Playwright |

### 3.3 OpenClaude (GitHub — Open Source)

**Repositório:** `https://github.com/Gitlawb/openclaude`  
**Papel futuro:** Gateway multi-provider — routing de agentes + captura de respostas

| Capacidade | Detalhe |
|------------|---------|
| **Providers** | 200+ modelos (OpenAI, Gemini, DeepSeek, Ollama, Codex, etc.) |
| **Agent Routing** | Roteia agentes para modelos diferentes (custo-otimizado) |
| **MCP** | Suporte nativo a MCP clients |
| **CLI** | Terminal-first workflow completo |
| **Web Tools** | Web search (DuckDuckGo), web fetch, Firecrawl |
| **VS Code** | Extensão integrada |
| **Profiles** | Saved provider profiles (.openclaude-profile.json) |

---

## 4. Arquitetura Proposta (TO-BE)

### 3.1 Visão Geral

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IAgentsFactory v3.0 (Multi-Projeto)              │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Proj ROI │  │Proj Médico│  │ Proj CRM │  │ Proj N.. │          │
│  │ Loteria  │  │  Saúde   │  │ Vendas   │  │          │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       └──────────────┴──────────────┴──────────────┘                │
│                          │ ask / search / specify                   │
│              ┌───────────▼────────────┐                             │
│              │  hermes-bridge.ps1     │  ← 3-layer orchestrator    │
│              └───────────┬────────────┘                             │
│       ┌───────────────────┼──────────────────────┐                  │
│       ▼                   ▼                      ▼                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐      │
│  │  CAMADA 1    │  │  CAMADA 2    │  │  CAMADA 3            │      │
│  │  Knowledge   │  │  Hermes +    │  │  Provider Externo    │      │
│  │  Hub (FTS5)  │  │  Ollama      │  │  Claude / GPT / etc  │      │
│  │  0 tokens    │  │  (WSL2)      │  │  custo medido        │      │
│  │  < 0.1s      │  │  0 custo     │  │  auto-capturado      │      │
│  │  threshold   │  │  90s timeout │  │  no Hub              │      │
│  │  ≥ 0.75      │  │  auto-cap.   │  │                      │      │
│  └──────────────┘  └──────────────┘  └──────────────────────┘      │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Task Scheduler (automação sem intervenção)      │   │
│  │  HermesUpdate 06:00 diário │ HermesSync 06:30 diário        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Fluxo de Resolução (Knowledge Pipeline v3)

```
┌─────────────────────────────────────────────────────────────┐
│              FLUXO: ask "como implementar X"                │
│                                                             │
│  1. hermes-bridge recebe a query                            │
│     │                                                       │
│  2. Busca FTS5 no Knowledge Hub (camada 1)                  │
│     ├── score ≥ 0.75 → retorna resposta local ──────► FIM   │
│     │   (0 tokens, < 100ms)                                 │
│     └── score < 0.75 ↓                                     │
│                                                             │
│  3. Consulta Hermes + Ollama via WSL2 (camada 2)            │
│     ├── resposta OK → auto-captura no Hub ──────────► FIM   │
│     │   (0 custo externo, resposta salva p/ futuro)         │
│     └── timeout / indisponível ↓                            │
│                                                             │
│  4. Escala para provider externo (camada 3)                 │
│     ├── resposta auto-capturada no Hub                      │
│     ├── registra em hermes_escalations (métricas)           │
│     └── próxima consulta igual → camada 1 ──────────► FIM  │
└─────────────────────────────────────────────────────────────┘
```

```
┌──────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                      │
│  ├─ VS Code Copilot Agents (ISGT agents .md)             │
│  ├─ OpenClaude CLI (terminal workflow)                   │
│  ├─ MCP Graph Dashboard (React 19 + React Flow)          │
│  └─ Responsabilidade: interface dev ⟷ fábrica            │
├──────────────────────────────────────────────────────────┤
│  ORCHESTRATION LAYER                                     │
│  ├─ IAgentsFactory Core (project registry + routing)       │
│  ├─ Knowledge Capture Pipeline (intercept → classify)    │
│  ├─ Session Tracker (tokens, duration, quality)          │
│  └─ Responsabilidade: coordenar fluxo multi-projeto      │
├──────────────────────────────────────────────────────────┤
│  INTELLIGENCE LAYER                                      │
│  ├─ Layer 1: FTS5 Search (threshold ≥ 0.75)              │
│  ├─ Layer 2: Hermes + Ollama (WSL2, 0 custo externo)     │
│  ├─ Layer 3: Provider externo (fallback medido)          │
│  ├─ Cross-Project Search (busca entre projetos)          │
│  └─ Responsabilidade: buscar pelo caminho mais barato    │
├──────────────────────────────────────────────────────────┤
│  PERSISTENCE LAYER                                       │
│  ├─ SQLite + WAL mode (ACID, concurrent reads)           │
│  ├─ FTS5 (full-text search)                              │
│  ├─ Knowledge Store (SHA-256 dedup, 5 sources)           │
│  ├─ hermes_sessions + hermes_escalations (métricas)      │
│  └─ Responsabilidade: armazenamento local-first          │
├──────────────────────────────────────────────────────────┤
│  AUTOMATION LAYER                                        │
│  ├─ Task Scheduler: HermesUpdate (06:00 diário)          │
│  ├─ Task Scheduler: HermesSync   (06:30 diário)          │
│  └─ Responsabilidade: manutenção zero-touch              │
├──────────────────────────────────────────────────────────┤
│  PROVIDER LAYER                                          │
│  ├─ Hermes + Ollama (local, WSL2, custo zero)            │
│  ├─ OpenClaude (200+ models, agent routing)              │
│  ├─ MCP Protocol (26 tools, stdio + HTTP transport)      │
│  ├─ GitHub Copilot (VS Code native)                      │
│  └─ Responsabilidade: comunicação com agentes            │
└──────────────────────────────────────────────────────────┘
```

---

## 5. Banco de Dados: Decisão Técnica

### 5.1 Comparativo

| Critério | SQLite | PostgreSQL | MongoDB |
|----------|--------|-----------|---------|
| Setup | Zero config | Instalar + configurar | Instalar + configurar |
| Local-first | ✅ Nativo (1 arquivo) | ❌ Precisa servidor | ❌ Precisa servidor |
| Full-text search | ✅ FTS5 nativo | ✅ tsvector | ✅ Text index |
| JSON storage | ✅ json_extract() | ✅ JSONB | ✅ Nativo |
| MCP Graph já usa | ✅ Sim | ❌ | ❌ |
| Performance 1 dev | ✅ Excelente | Overkill | Overkill |
| Custo | ✅ Zero | 💰 Hosting | 💰 Hosting |
| Portabilidade | ✅ Um arquivo .db | ❌ Cluster | ❌ Cluster |
| Concurrent reads | ✅ WAL mode | ✅ MVCC | ✅ Nativo |

### 5.2 Decisão: SQLite + FTS5 + JSON

**Justificativa:** O MCP Graph Workflow já implementa SQLite com WAL + FTS5 + embeddings. Adicionar PostgreSQL/MongoDB introduziria complexidade desnecessária para um sistema local-first single-user.

### 5.3 Schema Proposto (Knowledge Hub)

```sql
-- Soluções aprendidas com agentes externos
CREATE TABLE learned_solutions (
  id TEXT PRIMARY KEY,
  domain TEXT NOT NULL,           -- 'financial', 'medical', 'crm'
  pattern TEXT NOT NULL,          -- 'roi-calculation', 'crud-api'
  language TEXT,                  -- 'java', 'typescript', 'python'
  framework TEXT,                 -- 'spring-boot', 'nestjs'
  source_project TEXT,            -- 'loteria-roi'
  source_agent TEXT,              -- 'claude-sonnet', 'gpt-4o'
  prompt_used TEXT,               -- prompt original
  solution_content TEXT,          -- resposta completa
  solution_summary TEXT,          -- resumo para busca rápida
  quality_score REAL DEFAULT 0,   -- 0-1 (atualizado pelo dev)
  usage_count INTEGER DEFAULT 0,  -- quantas vezes reutilizado
  tokens_saved INTEGER DEFAULT 0, -- economia acumulada
  tags TEXT,                      -- JSON array de tags
  created_at TEXT DEFAULT (datetime('now')),
  last_used_at TEXT,
  expires_at TEXT                  -- TTL opcional
);

-- FTS5 para busca textual eficiente
CREATE VIRTUAL TABLE solutions_fts USING fts5(
  domain, pattern, solution_summary, tags,
  content=learned_solutions
);

-- Registro de projetos da fábrica
CREATE TABLE factory_projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  path TEXT NOT NULL,              -- caminho local do projeto
  language TEXT,
  framework TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  last_active_at TEXT,
  total_solutions_used INTEGER DEFAULT 0,
  total_tokens_saved INTEGER DEFAULT 0
);

-- Sessões de aprendizado
CREATE TABLE learning_sessions (
  id TEXT PRIMARY KEY,
  project_id TEXT REFERENCES factory_projects(id),
  agent TEXT NOT NULL,             -- 'claude-sonnet', 'gpt-4o', 'hermes-local'
  started_at TEXT DEFAULT (datetime('now')),
  ended_at TEXT,
  total_tokens_used INTEGER DEFAULT 0,
  solutions_captured INTEGER DEFAULT 0,
  summary TEXT
);

-- NOVO v3.0: sessões do Hermes Agent (métricas de resolução local)
CREATE TABLE hermes_sessions (
  id TEXT PRIMARY KEY,
  project_id TEXT REFERENCES factory_projects(id),
  query TEXT NOT NULL,
  resolved_by TEXT DEFAULT 'unknown',  -- 'local-hub', 'hermes-local', 'external'
  layer_used INTEGER DEFAULT 3,        -- 1, 2 ou 3
  response_content TEXT DEFAULT '',
  elapsed_sec REAL DEFAULT 0,
  tokens_saved INTEGER DEFAULT 0,      -- estimativa de tokens economizados
  created_at TEXT DEFAULT (datetime('now','localtime'))
);

-- NOVO v3.0: escalações para provider externo (métricas de economia)
CREATE TABLE hermes_escalations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  query TEXT NOT NULL,
  project TEXT DEFAULT '',
  escalated_at TEXT DEFAULT (datetime('now','localtime')),
  UNIQUE(query, project)               -- sem duplicatas por query+projeto
);
```

---

## 6. Análise de Prós e Contras

### 6.1 Prós

| # | Pró | Impacto | Confiança |
|---|-----|---------|-----------|
| 1 | **Economia massiva de tokens** — camada 1+2 resolvem sem custo externo | 💰 -70% a -95% custo APIs | 🟢 Alta |
| 2 | **Velocidade** — busca local em ms vs. 2-5s API externa | ⚡ Feedback instantâneo | 🟢 Alta |
| 3 | **IA local gratuita** — Hermes+Ollama resolve sem enviar dados para fora | 🔒 Privacidade + custo zero | 🟢 Alta |
| 4 | **Consistência** — mesma solução reutilizada = menos bugs | 🎯 Padrões convergem | 🟢 Alta |
| 5 | **Offline-first** — funciona sem internet para soluções aprendidas e Hermes | 🔌 Independência | 🟢 Alta |
| 6 | **Auto-update sem intervenção** — Task Scheduler mantém tudo atualizado | 🤖 Zero-touch | 🟢 Alta |
| 7 | **IP local** — conhecimento e modelos ficam na máquina, não na cloud | 🔒 Controle total | 🟢 Alta |
| 8 | **ROI crescente** — fábrica fica mais inteligente a cada projeto | 📈 Exponencial | 🟡 Média |
| 9 | **Multi-projeto** — compartilha aprendizados entre projetos | 🏭 True factory | 🟢 Alta |
| 10 | **Multi-provider** — fallback inteligente por camada | 💡 Cost-aware | 🟢 Alta |

### 6.2 Contras e Riscos

| # | Contra | Severidade | Mitigação |
|---|--------|-----------|-----------|
| 1 | **Complexidade** — 3 sistemas integrados | 🔴 Alta | Integração incremental por fases |
| 2 | **Stale knowledge** — soluções obsoletas | 🟡 Média | TTL + score + re-validação |
| 3 | **False matches** — busca retorna solução errada | 🟡 Média | Threshold ≥75% + fallback externo |
| 4 | **Overhead de captura** — salvar interações = fricção | 🟡 Média | Captura automática + curadoria opt. |
| 5 | **DB growth** — muitos projetos = DB grande | 🟢 Baixa | SQLite suporta TBs + cleanup |
| 6 | **Context mismatch** — Proj A ≠ Proj B | 🟡 Média | Metadata rica + filtros por domain |
| 7 | **OpenClaude é externo** — manutenção comunidade | 🟡 Média | Usar como dep, não forkar |
| 8 | **Curva de aprendizado** | 🟡 Média | Setup automatizado (força do ISGT) |
| 9 | **TF-IDF limitado** — menos preciso que transformers | 🟢 Baixa | Upgrade futuro p/ ONNX local |
| 10 | **Single-user** — não compartilha entre devs | 🟡 Média | Fase 5: sync via Git |

---

## 7. Caso de Uso Concreto: ROI Loteria → Software Médico

| Cenário | SEM Memória (Hoje) | COM Memória (Proposta) |
|---------|-------------------|----------------------|
| Proj Loteria precisa de cálculo ROI | Pergunta ao Claude → ~4k tokens | Pergunta ao Claude → ~4k tokens → **salva** |
| Proj Médico precisa de similar | Pergunta de novo → ~4k tokens | **Busca local** → match 80% → adapta com ~500 tokens |
| **Economia por reuso** | 0% | **~87% tokens** |
| Proj N precisa de ROI variante | Pergunta de novo... | Busca local → combina 2 soluções → 0 tokens |

---

## 8. Roadmap de Implementação

### Fase 1: Knowledge Hub (MCP Graph Integration) — 🟡 IN PROGRESS
```
Período:    Abril–Maio 2026
Objetivo:   ISGT captura e busca soluções via MCP Graph
Entregas:
├─ .mcp.json configurado no ISGT
├─ Knowledge capture skill (novo skill)
├─ Cross-reference search tool
├─ learned_solutions schema
└─ Métricas básicas (tokens saved)
Métricas: Primeira solução reutilizada com sucesso
```

### Fase 2: Multi-Projeto Registry — ⬜ PLANNED
```
Período:    Junho–Julho 2026
Objetivo:   Gerenciar N projetos com busca cross-project
Entregas:
├─ factory_projects registry
├─ Cross-project search (domain-aware)
├─ Project isolation + sharing rules
└─ Setup automático de novo projeto na fábrica
Dependência: Fase 1 completa
```

### Fase 3: OpenClaude Integration — ⬜ PLANNED
```
Período:    Agosto–Setembro 2026
Objetivo:   Agent routing inteligente + captura automática
Entregas:
├─ OpenClaude como provider layer
├─ Agent routing (custo-otimizado)
├─ Auto-capture de respostas
└─ Fallback: local → externo → local (save)
Dependência: Fase 2 completa
```

### Fase 4: Dashboard & Métricas — ⬜ PLANNED
```
Período:    Outubro 2026
Objetivo:   Visibilidade total sobre economia e aprendizado
Entregas:
├─ Dashboard de economia de tokens
├─ Mapa de conhecimento por domain
├─ Métricas de reuso por projeto
└─ Reports exportáveis
Dependência: Fase 3 completa
```

### Fase 5: Team Sync — ⬜ PLANNED
```
Período:    Novembro–Dezembro 2026
Objetivo:   Compartilhar knowledge entre desenvolvedores
Entregas:
├─ Git-based knowledge sync
├─ Merge strategies para soluções conflitantes
├─ Access control por projeto/team
└─ Knowledge marketplace entre equipes
Dependência: Fase 4 completa
```

---

## 9. Futuros Usos de APIs

| API | Fase | Finalidade |
|-----|------|-----------|
| **MCP Protocol** | 1 | Comunicação ISGT ↔ MCP Graph (26 tools) |
| **GitHub API** | 2+ | Sync issues, compartilhar knowledge via repos |
| **Ollama API** | 3+ | Embeddings locais mais precisos (ONNX/transformer) |
| **OpenClaude API** | 3 | Agent routing multi-provider |
| **REST Knowledge API** | 2+ | Expor Knowledge Hub para ferramentas externas |
| **VS Code Extension API** | 4+ | Inline suggestions de soluções aprendidas |
| **Webhook API** | 4+ | Notificações de knowledge match |

---

## 10. Conclusão

| Aspecto | Avaliação |
|---------|-----------|
| **Viabilidade** | 🟢 Alta — os 3 componentes existem e são compatíveis |
| **Complexidade** | 🟡 Média-Alta — integração é o desafio |
| **ROI esperado** | 🟢 Alto — economia cresce exponencialmente |
| **Risco técnico** | 🟡 Médio — SQLite + MCP são maduros |
| **Inovação** | 🟢 Alta — poucos frameworks fazem isso |
| **Sustentabilidade** | 🟢 Alta — local-first, sem vendor lock-in |

**Decisão:** ✅ Aprovado. Iniciar Fase 1 imediatamente.

