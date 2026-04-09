# 🏭 IAgentsFactory — Apresentação Executiva

### Fábrica de Software com Memória Persistente de IA

**Data:** 2026-04-06 | **Autor:** AR CALHAU | **Status:** ✅ Aprovado

---

## 📌 Slide 1 — O Problema

```
╔══════════════════════════════════════════════════════════╗
║                    HOJE (SEM MEMÓRIA)                   ║
║                                                          ║
║   Projeto A          Projeto B          Projeto C        ║
║   "Como calcular     "Como calcular     "Como calcular   ║
║    ROI?"              ROI similar?"      ROI variante?"   ║
║      │                    │                   │           ║
║      ▼                    ▼                   ▼           ║
║   Claude API          Claude API          Claude API      ║
║   ~4k tokens          ~4k tokens          ~4k tokens      ║
║                                                          ║
║   💰 Custo total: 12k tokens (mesma pergunta 3x)        ║
║   ⏱️ Tempo: 3 chamadas API (6-15 segundos)              ║
║   🧠 Aprendizado retido: ZERO                           ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 2 — A Solução

```
╔══════════════════════════════════════════════════════════╗
║                 FUTURO (COM MEMÓRIA)                    ║
║                                                          ║
║   Projeto A          Projeto B          Projeto C        ║
║   "Calcular ROI"     "Calcular ROI"     "Calcular ROI"   ║
║      │                    │                   │           ║
║      ▼                    ▼                   ▼           ║
║   🔍 Knowledge Hub    🔍 Knowledge Hub   🔍 Knowledge Hub║
║   ❌ Não tem          ✅ Match 85%!      ✅ Match 92%!   ║
║      │                    │                   │           ║
║      ▼                    │                   │           ║
║   Claude API           (local)             (local)       ║
║   ~4k tokens           ~500 tok adapt.     0 tokens      ║
║   💾 SALVA!                                              ║
║                                                          ║
║   💰 Custo total: 4.5k tokens (economia de 63%)         ║
║   ⏱️ Tempo: 1 API + 2 locais (~ms)                     ║
║   🧠 Aprendizado: CRESCE a cada interação               ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 3 — Visão Arquitetural

```
╔══════════════════════════════════════════════════════════╗
║                  IAGENTSFACTORY                          ║
║                                                          ║
║  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   ║
║  │ Loteria  │ │  Médico  │ │   CRM    │ │  Proj N  │   ║
║  │   ROI    │ │  Saúde   │ │ Vendas   │ │   ...    │   ║
║  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   ║
║       └─────────────┴────────────┴─────────────┘         ║
║                         │                                ║
║            ┌────────────▼────────────┐                   ║
║            │   🧠 KNOWLEDGE HUB     │                   ║
║            │                         │                   ║
║            │  SQLite + FTS5 + RAG    │                   ║
║            │  TF-IDF Embeddings      │                   ║
║            │  Cross-Project Search   │                   ║
║            │  70-85% Token Savings   │                   ║
║            └────────────┬────────────┘                   ║
║                         │                                ║
║         ┌───────────────┼───────────────┐                ║
║         ▼               ▼               ▼                ║
║  ┌────────────┐  ┌────────────┐  ┌────────────┐         ║
║  │ OpenClaude │  │ MCP Graph  │  │  VS Code   │         ║
║  │ Multi-LLM  │  │ Workflow   │  │  Copilot   │         ║
║  │ 200+ models│  │ 26 tools   │  │  6 agents  │         ║
║  └────────────┘  └────────────┘  └────────────┘         ║
║                                                          ║
║  ┌──────────────────────────────────────────────────┐   ║
║  │         AGENTES EXTERNOS (Otimizados)            │   ║
║  │  Claude │ GPT-4o │ DeepSeek │ Gemini │ Ollama    │   ║
║  └──────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 4 — Os 3 Pilares

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ║
║   │     ISGT     │  │  MCP Graph   │  │  OpenClaude  │  ║
║   │              │  │  Workflow     │  │              │  ║
║   │  🎯 Orques-  │  │  🧠 Motor de │  │  🔌 Gateway  │  ║
║   │  trador      │  │  Persistên-  │  │  Multi-      │  ║
║   │  Central     │  │  cia + RAG   │  │  Provider    │  ║
║   │              │  │              │  │              │  ║
║   │ • 6 agents   │  │ • SQLite+FTS │  │ • 200+ LLMs │  ║
║   │ • 7 patterns │  │ • Embeddings │  │ • Routing    │  ║
║   │ • 9 skills   │  │ • 26 MCP     │  │ • MCP native │  ║
║   │ • 24 prompts │  │ • Dashboard  │  │ • CLI-first  │  ║
║   │ • Auto-setup │  │ • 910+ tests │  │ • VS Code    │  ║
║   └──────────────┘  └──────────────┘  └──────────────┘  ║
║                                                          ║
║   JÁ EXISTE ✅       JÁ EXISTE ✅      JÁ EXISTE ✅     ║
║   (Nosso projeto)   (Repo local)      (Open source)     ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 5 — Fluxo de Aprendizado

```
╔══════════════════════════════════════════════════════════╗
║          KNOWLEDGE CAPTURE PIPELINE                     ║
║                                                          ║
║   ① Dev faz pergunta ao agente                          ║
║      │                                                   ║
║   ② ISGT busca no Knowledge Hub (local)                 ║
║      │                                                   ║
║      ├── ✅ Match ≥ 75%? → RETORNA LOCAL (0 tokens!)    ║
║      │                                                   ║
║      └── ❌ Sem match? → Chama agente externo           ║
║           │                                              ║
║   ③ OpenClaude roteia para melhor provider               ║
║      (DeepSeek=barato | GPT-4o=complexo)                ║
║           │                                              ║
║   ④ Agente responde                                     ║
║           │                                              ║
║   ⑤ CAPTURA AUTOMÁTICA:                                 ║
║      ├── Classifica (domain, pattern, language)         ║
║      ├── Indexa (FTS5 + TF-IDF embeddings)              ║
║      ├── Deduplica (SHA-256)                            ║
║      └── Salva no Knowledge Hub                         ║
║           │                                              ║
║   ⑥ Próxima vez → BUSCA LOCAL PRIMEIRO                  ║
║                                                          ║
║   📊 Resultado: fábrica fica mais inteligente           ║
║      com cada interação                                  ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 6 — Banco de Dados

```
╔══════════════════════════════════════════════════════════╗
║   DECISÃO: SQLite + FTS5 + JSON (via MCP Graph)        ║
║                                                          ║
║   ┌──────────────┬──────────┬──────────┬──────────┐     ║
║   │   Critério   │  SQLite  │ Postgres │ MongoDB  │     ║
║   ├──────────────┼──────────┼──────────┼──────────┤     ║
║   │ Setup        │ Zero ✅  │ Config   │ Config   │     ║
║   │ Local-first  │ 1 file ✅│ Servidor │ Servidor │     ║
║   │ Full-text    │ FTS5 ✅  │ tsvector │ TextIdx  │     ║
║   │ JSON storage │ ✅       │ JSONB    │ Nativo   │     ║
║   │ MCP Graph    │ Já usa ✅│ ❌       │ ❌       │     ║
║   │ Performance  │ Excelente│ Overkill │ Overkill │     ║
║   │ Custo        │ $0 ✅    │ $$$      │ $$$      │     ║
║   │ Portável     │ 1 .db ✅ │ Cluster  │ Cluster  │     ║
║   └──────────────┴──────────┴──────────┴──────────┘     ║
║                                                          ║
║   📝 SQLite suporta TBs de dados                        ║
║   📝 WAL mode = leituras concorrentes                   ║
║   📝 FTS5 = busca textual nativa                        ║
║   📝 MCP Graph já implementa tudo isso                  ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 7 — Prós e Contras

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ✅ PRÓS                      ❌ CONTRAS               ║
║   ──────────────               ───────────────          ║
║   💰 -60% a -90% tokens       🔴 Complexidade 3 sistemas║
║   ⚡ Busca local em ms         🟡 Stale knowledge       ║
║   🎯 Padrões consistentes     🟡 False matches possíveis║
║   🔌 Funciona offline         🟡 Overhead de captura    ║
║   🔒 IP fica local            🟡 Context mismatch       ║
║   📈 ROI crescente            🟡 OpenClaude é externo   ║
║   🏭 Multi-projeto real       🟡 Curva de aprendizado   ║
║   🔧 80% da stack pronta      🟢 TF-IDF limitado        ║
║   💡 Cost-aware routing       🟢 Single-user (v1)       ║
║   📊 Custo cresce log.        🟢 DB growth              ║
║                                                          ║
║   VEREDICTO: Prós >> Contras                            ║
║   Contras são MITIGÁVEIS com fases incrementais         ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 8 — Roadmap

```
╔══════════════════════════════════════════════════════════╗
║                  ROADMAP 2026                           ║
║                                                          ║
║  ABR─MAI    JUN─JUL    AGO─SET     OUT      NOV─DEZ    ║
║  ┌──────┐  ┌──────┐   ┌──────┐  ┌──────┐  ┌──────┐    ║
║  │FASE 1│→ │FASE 2│→  │FASE 3│→ │FASE 4│→ │FASE 5│    ║
║  │      │  │      │   │      │  │      │  │      │    ║
║  │Know- │  │Multi-│   │Open- │  │Dash- │  │Team  │    ║
║  │ledge │  │Proj. │   │Claude│  │board │  │Sync  │    ║
║  │Hub   │  │Regis-│   │Integ.│  │+Metr.│  │(Git) │    ║
║  │      │  │try   │   │      │  │      │  │      │    ║
║  │MCP   │  │Cross │   │Agent │  │Econ. │  │Share │    ║
║  │Graph │  │Proj. │   │Route │  │Token │  │Know- │    ║
║  │Integ.│  │Search│   │Captur│  │Report│  │ledge │    ║
║  └──────┘  └──────┘   └──────┘  └──────┘  └──────┘    ║
║  🟡 NOW    ⬜ Plan    ⬜ Plan   ⬜ Plan   ⬜ Plan     ║
║                                                          ║
║  Valor:     Valor:     Valor:    Valor:    Valor:       ║
║  Prova de   Fábrica    Otimiza   Visibil.  Escala       ║
║  Conceito   Real       Custo     Total     p/Times      ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 9 — Métricas de Sucesso

```
╔══════════════════════════════════════════════════════════╗
║                  KPIs DO PROJETO                        ║
║                                                          ║
║  ┌─────────────────────┬──────────┬──────────┐          ║
║  │ Métrica             │ Baseline │ Meta 6m  │          ║
║  ├─────────────────────┼──────────┼──────────┤          ║
║  │ Token savings/mês   │ 0        │ -60%     │          ║
║  │ Knowledge entries   │ 0        │ 100+     │          ║
║  │ Reuse rate          │ 0%       │ 40%+     │          ║
║  │ Local resolve rate  │ 0%       │ 30%+     │          ║
║  │ Avg response time   │ 3-5s     │ <500ms*  │          ║
║  │ Projects managed    │ 1        │ 3+       │          ║
║  │ Cross-proj reuse    │ 0        │ 10+      │          ║
║  └─────────────────────┴──────────┴──────────┘          ║
║                                                          ║
║  * Para soluções encontradas localmente                  ║
║                                                          ║
║  📊 "A fábrica paga-se a si mesma em ~2 meses"         ║
╚══════════════════════════════════════════════════════════╝
```

---

## 📌 Slide 10 — Próximos Passos (FASE 1)

```
╔══════════════════════════════════════════════════════════╗
║              FASE 1 — INÍCIO IMEDIATO                   ║
║                                                          ║
║  ☐ 1. Configurar .mcp.json no ISGT                     ║
║       (conectar ao MCP Graph Workflow)                   ║
║                                                          ║
║  ☐ 2. Criar skill: knowledge-capture.md                 ║
║       (captura automática de soluções)                   ║
║                                                          ║
║  ☐ 3. Criar agent: KNOWLEDGE.md                         ║
║       (agente especializado em memória)                  ║
║                                                          ║
║  ☐ 4. Atualizar AS-IS.md e TO-BE.md                    ║
║       (documentar estado atual e visão)                  ║
║                                                          ║
║  ☐ 5. Criar ADR-001: Knowledge Hub Architecture         ║
║       (registrar decisão arquitetural)                   ║
║                                                          ║
║  ☐ 6. Configurar MCP Graph como Knowledge Hub           ║
║       (schema + tools + busca)                           ║
║                                                          ║
║  ☐ 7. Primeiro teste end-to-end                         ║
║       (capturar solução → buscar → reutilizar)           ║
║                                                          ║
║  STATUS: 🟡 INICIANDO AGORA                             ║
╚══════════════════════════════════════════════════════════╝
```

---

**📄 Documento completo:** [docs/architecture/IAGENTSFACTORY-ANALYSIS.md](IAGENTSFACTORY-ANALYSIS.md)  
**📋 ADR:** [docs/decisions/ADR-001-knowledge-hub-architecture.md](../decisions/ADR-001-knowledge-hub-architecture.md)

