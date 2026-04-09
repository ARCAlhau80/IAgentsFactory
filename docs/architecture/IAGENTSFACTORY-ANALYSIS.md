# 🏭 Análise Técnica: IAgentsFactory → Fábrica de Software com Memória Persistente

**Data:** 2026-04-06  
**Autor:** AR CALHAU (assistido por COORDINATOR Agent)  
**Status:** ✅ Aprovado — Início de implementação  
**Versão:** 1.0

---

## 1. Sumário Executivo

Transformar o **IAgentsFactory** a partir da base conceitual do ISGT (IA Squad Generic Template) em uma **Fábrica de Software Multi-Projeto** com **Memória de Longa Duração**, capaz de reter, indexar e reutilizar conhecimento adquirido em interações com agentes de IA externos (Claude, GPT-4o, DeepSeek, Gemini, Ollama, etc.).

**Objetivo primário:** Otimizar o uso de agentes externos — não substituí-los, mas garantir que soluções já aprendidas sejam reutilizadas localmente, economizando tokens, tempo e custo.

---

## 2. Análise do Estado Atual (AS-IS)

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

### 4.1 Visão Geral

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IAgentsFactory (Multi-Projeto)                     │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Proj ROI │  │Proj Médico│  │ Proj CRM │  │ Proj N.. │          │
│  │ Loteria  │  │  Saúde   │  │ Vendas   │  │          │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       │              │              │              │                │
│       └──────────────┴──────────────┴──────────────┘                │
│                          │                                          │
│              ┌───────────▼────────────┐                             │
│              │   Knowledge Hub Local  │                             │
│              │  (SQLite + FTS5 + RAG) │                             │
│              │                        │                             │
│              │ • Soluções indexadas    │                             │
│              │ • Patterns aprendidos  │                             │
│              │ • Erros resolvidos     │                             │
│              │ • Decisões (ADRs)      │                             │
│              │ • Embeddings TF-IDF    │                             │
│              └───────────┬────────────┘                             │
│                          │                                          │
│         ┌────────────────┼────────────────┐                        │
│         ▼                ▼                ▼                         │
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐                  │
│  │ OpenClaude │  │ MCP Graph  │  │ VS Code     │                  │
│  │  (CLI +    │  │ Workflow   │  │ Copilot     │                  │
│  │  Multi-    │  │ (Grafos +  │  │ (Agents +   │                  │
│  │  Provider) │  │  RAG +     │  │  Skills)    │                  │
│  │            │  │  Planning) │  │             │                  │
│  └────────────┘  └────────────┘  └─────────────┘                  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Agentes Externos (Token-Otimizados)            │   │
│  │  Claude Sonnet │ GPT-4o │ DeepSeek │ Gemini │ Ollama Local │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Fluxo de Conhecimento (Knowledge Pipeline)

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUXO DE APRENDIZADO                     │
│                                                             │
│  1. Dev trabalha no Projeto via ISGT (VS Code Copilot)      │
│     │                                                       │
│  2. Precisa resolver problema (ex: cálculo ROI)             │
│     │                                                       │
│  3. ┌──► ISGT consulta Knowledge Hub (MCP Graph)            │
│     │    │                                                   │
│     │    ├── MATCH ≥ 75%? → Retorna solução local ──────►   │
│     │    │   (0 tokens externos, ~ms de latência)     FIM   │
│     │    │                                                   │
│     │    └── MATCH < 75%? → Roteia para agente externo      │
│     │         │                                              │
│  4. │    OpenClaude seleciona melhor provider                │
│     │    (DeepSeek p/ simples, GPT-4o p/ complexo)          │
│     │         │                                              │
│  5. │    Agente externo responde                             │
│     │         │                                              │
│  6. │    Knowledge Capture Pipeline                          │
│     │    ├── Classifica (domain, pattern, language)          │
│     │    ├── Indexa (FTS5 + TF-IDF embeddings)              │
│     │    ├── Deduplica (SHA-256)                             │
│     │    └── Salva no Knowledge Hub                          │
│     │         │                                              │
│  7. └──── Próxima vez → busca local primeiro                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 Camadas Arquiteturais

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
│  ├─ RAG Engine (TF-IDF embeddings + BM25 ranking)        │
│  ├─ Cross-Project Search (busca entre projetos)          │
│  ├─ Token Budget Manager (otimiza contexto)              │
│  ├─ Similarity Matcher (threshold ≥ 75%)                 │
│  └─ Responsabilidade: buscar e ranquear conhecimento     │
├──────────────────────────────────────────────────────────┤
│  PERSISTENCE LAYER                                       │
│  ├─ SQLite + WAL mode (ACID, concurrent reads)           │
│  ├─ FTS5 (full-text search)                              │
│  ├─ Knowledge Store (SHA-256 dedup, 5 sources)           │
│  ├─ Embeddings Table (TF-IDF vectors)                    │
│  └─ Responsabilidade: armazenamento local-first          │
├──────────────────────────────────────────────────────────┤
│  PROVIDER LAYER                                          │
│  ├─ OpenClaude (200+ models, agent routing)              │
│  ├─ MCP Protocol (26 tools, stdio + HTTP transport)      │
│  ├─ GitHub Copilot (VS Code native)                      │
│  └─ Responsabilidade: comunicação com agentes externos   │
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
  agent TEXT NOT NULL,             -- 'claude-sonnet', 'gpt-4o'
  started_at TEXT DEFAULT (datetime('now')),
  ended_at TEXT,
  total_tokens_used INTEGER DEFAULT 0,
  solutions_captured INTEGER DEFAULT 0,
  summary TEXT
);

-- Embeddings TF-IDF para busca semântica
CREATE TABLE solution_embeddings (
  solution_id TEXT REFERENCES learned_solutions(id),
  chunk_index INTEGER,
  embedding TEXT,                  -- JSON array de floats
  chunk_text TEXT,
  PRIMARY KEY (solution_id, chunk_index)
);
```

---

## 6. Análise de Prós e Contras

### 6.1 Prós

| # | Pró | Impacto | Confiança |
|---|-----|---------|-----------|
| 1 | **Economia massiva de tokens** — reutiliza soluções validadas | 💰 -60% a -90% custo APIs | 🟢 Alta |
| 2 | **Velocidade** — busca local em ms vs. 2-5s API | ⚡ Feedback instantâneo | 🟢 Alta |
| 3 | **Consistência** — mesma solução reutilizada = menos bugs | 🎯 Padrões convergem | 🟢 Alta |
| 4 | **Offline-first** — funciona sem internet para soluções aprendidas | 🔌 Independência | 🟢 Alta |
| 5 | **IP local** — conhecimento fica na máquina, não na cloud | 🔒 Controle total | 🟢 Alta |
| 6 | **ROI crescente** — fábrica fica mais inteligente a cada projeto | 📈 Exponencial | 🟡 Média |
| 7 | **Multi-projeto** — compartilha aprendizados entre projetos | 🏭 True factory | 🟢 Alta |
| 8 | **Stack pronta** — MCP Graph tem 80% do que precisamos | 🔧 Menos dev | 🟢 Alta |
| 9 | **Multi-provider** — OpenClaude otimiza custo por routing | 💡 Cost-aware | 🟡 Média |
| 10 | **Sustentável** — custo cresce log, não linear | 📊 Escala | 🟢 Alta |

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

