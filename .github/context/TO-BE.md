# 🎯 TO-BE — Visão Futura do IAgentsFactory

**Horizonte:** 9 meses (Abril–Dezembro 2026)  
**Objetivo:** Consolidar o IAgentsFactory como fábrica multi-projeto com memória persistente, captura operacional e geração multi-processo

---

## 🚀 Roadmap por Fases

### Fase 1: Knowledge Hub — ✅ BASELINE OPERACIONAL
```
Período:    Abril–Maio 2026
Objetivo:   IAgentsFactory captura, busca e mede soluções via Knowledge Hub local
Entregas:
├─ .mcp.json configurado para a Factory
├─ Skill: knowledge-capture.md
├─ Agent: KNOWLEDGE.md
├─ ADR-001: Knowledge Hub Architecture
├─ Schema: learned_solutions + factory_projects
├─ CLI operacional: init/register/search/search-cross/stats/export/import
└─ Dashboard nativo ligado ao knowledge.db
Métricas de Sucesso: baseline funcional concluída
```

### Fase 2: Multi-Projeto Registry — ⬜ PLANNED
```
Período:    Junho–Julho 2026
Objetivo:   Gerenciar N projetos com busca cross-project
Entregas:
├─ factory_projects registry funcional
├─ Cross-project search (domain-aware)
├─ Project isolation + sharing rules
├─ Setup automático registra projeto na fábrica
└─ CLI para listar/buscar soluções entre projetos
Dependência: Fase 1 completa
Métricas: 3+ projetos registrados, 10+ soluções cross-project
```

### Fase 3: OpenClaude Integration — ⬜ PLANNED
```
Período:    Agosto–Setembro 2026
Objetivo:   Agent routing inteligente + captura automática
Entregas:
├─ OpenClaude como provider layer
├─ Agent routing (DeepSeek=barato, GPT-4o=complexo)
├─ Auto-capture pipeline (resposta → classify → index → save)
├─ Fallback flow: local → externo → local (salva)
└─ Métricas de economia por provider
Dependência: Fase 2 completa
Métricas: -60% tokens gastos vs. baseline
```

### Fase 4: Dashboard & Métricas — ⬜ PLANNED
```
Período:    Outubro 2026
Objetivo:   Visibilidade total sobre economia e aprendizado
Entregas:
├─ Dashboard de economia de tokens (React via MCP Graph)
├─ Mapa de conhecimento por domain
├─ Métricas de reuso por projeto
└─ Reports exportáveis (PDF/HTML)
Dependência: Fase 3 completa
Métricas: Dashboard funcional com dados reais
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
Métricas: 2+ devs compartilhando knowledge base
```

---

## 🏛️ Arquitetura Target

```
┌──────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                      │
│  ├─ VS Code Copilot Agents (.github/agents)              │
│  ├─ OpenClaude CLI (terminal multi-provider)             │
│  └─ MCP Graph Dashboard (React 19 + React Flow)          │
├──────────────────────────────────────────────────────────┤
│  ORCHESTRATION LAYER                                     │
│  ├─ IAgentsFactory Core (project registry + routing)     │
│  ├─ Knowledge Capture Pipeline (intercept → classify)    │
│  └─ Session Tracker (tokens, duration, quality)          │
├──────────────────────────────────────────────────────────┤
│  INTELLIGENCE LAYER                                      │
│  ├─ RAG Engine (TF-IDF + BM25 ranking)                   │
│  ├─ Cross-Project Search (domain-aware)                  │
│  ├─ Token Budget Manager (70-85% compression)            │
│  └─ Similarity Matcher (threshold ≥ 75%)                 │
├──────────────────────────────────────────────────────────┤
│  PERSISTENCE LAYER                                       │
│  ├─ SQLite + WAL mode (ACID, concurrent reads)           │
│  ├─ FTS5 (full-text search nativo)                       │
│  ├─ Knowledge Store (SHA-256 dedup)                      │
│  └─ TF-IDF Embeddings (100% local)                      │
├──────────────────────────────────────────────────────────┤
│  PROVIDER LAYER                                          │
│  ├─ OpenClaude (200+ models, agent routing)              │
│  ├─ MCP Protocol (26 tools, stdio + HTTP)                │
│  └─ GitHub Copilot (VS Code native)                      │
└──────────────────────────────────────────────────────────┘
```

---

## 📊 Metas Quantitativas

| Métrica | Atual | Meta (6m) | Meta (9m) | Prazo |
|---------|-------|-----------|-----------|-------|
| Knowledge entries | 0 | 100+ | 500+ | Dez 2026 |
| Token savings | 0% | -60% | -80% | Dez 2026 |
| Reuse rate | 0% | 40%+ | 60%+ | Dez 2026 |
| Local resolve rate | 0% | 30%+ | 50%+ | Dez 2026 |
| Projects managed | 1 | 3+ | 5+ | Dez 2026 |
| Avg response (local) | N/A | <500ms | <200ms | Dez 2026 |
| Cross-project reuse | 0 | 10+ | 50+ | Dez 2026 |

---

## 🚧 Decisões Tomadas

1. ✅ **SQLite + FTS5** como banco local (não PostgreSQL/MongoDB) — ADR-001
2. ✅ **MCP Graph Workflow** como motor de persistência + RAG
3. ✅ **OpenClaude** como gateway multi-provider (Fase 3)
4. ✅ **Integração incremental** por fases (não big-bang)

## 🚧 Decisões Pendentes

1. **Threshold de similaridade** — 75%? 80%? Testar na Fase 1
2. **TTL de soluções** — expirar após 6 meses? Nunca? Por domain?
3. **Granularidade de captura** — toda interação ou só validadas pelo dev?
4. **Sync protocol (Fase 5)** — Git LFS? SQLite replication? CRDTs?

---

<!-- Análise técnica completa em: docs/architecture/IAGENTSFACTORY-ANALYSIS.md
     Apresentação executiva em: docs/architecture/IAGENTSFACTORY-PRESENTATION.md -->
     Atualize status das fases conforme progride. -->

