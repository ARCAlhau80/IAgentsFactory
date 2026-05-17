# 🏗️ Architecture Overview — IAgentsFactory

**Propósito:** visão técnica consolidada do produto e do fluxo de especificação leve  
**Nível:** Técnico — Arquitetos, mantenedores e agentes de automação  
**Versão:** 3.1.0 — Ollama Edition (Maio 2026)

---

## 🎯 O Problema Que Resolvemos

```
ENTRADA:   demandas de código, arquitetura, operação e reuso entre projetos
DESAFIO:   evitar retrabalho, custo com tokens externos e dependência total de provedores pagos
PROBLEMA:  conhecimento valioso se perde entre sessões e entre repositórios
RESULTADO: knowledge hub local + Ollama Windows nativo (Layer 2) + workflow SPEC leve + operação multiprojeto
ESCALA:    uso local-first, sem infra cloud, vários repositórios, múltiplos agentes
```

---

## 🏛️ Camadas Arquiteturais

```
┌──────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                  │
│  ├─ PowerShell CLI (`iagents-factory.ps1`)           │
│  ├─ Dashboard Node/HTTP (`tools/factory-dashboard`)  │
│  └─ Responsabilidade: comandos, visualização e setup │
├──────────────────────────────────────────────────────┤
│  ORCHESTRATION LAYER                                 │
│  ├─ ask / hermes-status / hermes-update              │
│  ├─ register / search / capture / export / import    │
│  ├─ constitution / specify / plan / tasks / analyze  │
│  └─ Responsabilidade: coordenar fluxo knowledge-first│
├──────────────────────────────────────────────────────┤
│  LOCAL INTELLIGENCE — 3-Layer Resolution             │
│  ├─ Camada 1: Knowledge Hub FTS5 (0 tokens, <0.1s)  │
│  │            threshold ≥ 0.75, dedup SHA-256        │
  ├─ Camada 2: Ollama Windows nativo (localhost:11434)    │
  │            0 custo externo, timeout 90s               │
  │            auto-captura no Hub após resposta          │
│  ├─ Camada 3: Provider externo (Claude/GPT)          │
│  │            custo medido, resposta capturada       │
│  └─ hermes-bridge.ps1 orquestra o fluxo              │
├──────────────────────────────────────────────────────┤
│  GOVERNANCE LAYER                                    │
│  ├─ specs/memory, templates, presets, extensions     │
│  ├─ gate `analyze` + Engineering Pillars checklist   │
│  └─ Responsabilidade: reduzir ambiguidade e validar  │
├──────────────────────────────────────────────────────┤
│  PERSISTENCE LAYER                                   │
│  ├─ SQLite (`knowledge.db`) + FTS5 + WAL             │
│  ├─ learned_solutions / factory_projects / reuse_log │
│  ├─ hermes_sessions / hermes_escalations             │
│  └─ Responsabilidade: armazenar e ranquear memória   │
├──────────────────────────────────────────────────────┤
│  AUTOMATION LAYER                                    │
│  ├─ Task Scheduler: HermesUpdate (06:00 diário)      │
│  ├─ Task Scheduler: HermesSync   (06:30 diário)      │
│  └─ Responsabilidade: manutenção sem intervenção     │
├──────────────────────────────────────────────────────┤
│  INTEGRATION LAYER                                   │
│  ├─ MCP Graph Workflow (26 tools)                    │
│  ├─ OpenClaude / agentes externos                    │
│  └─ Responsabilidade: extensão visual e providers    │
└──────────────────────────────────────────────────────┘
```

---

## 🔀 Fluxo Principal

```
1. Operador ou agente inicia uma demanda (ask / search / specify)
   │
2. hermes-bridge verifica Knowledge Hub local (camada 1, FTS5)
   │ score ≥ 0.75 → retorna imediatamente (0 tokens)
   │ score < 0.75 ↓
3. hermes-bridge consulta Ollama Windows via HTTP localhost:11434 (camada 2)
   │ resposta → auto-captura no Hub → retorna (0 custo externo)
   │ timeout / Ollama indisponível ↓
4. hermes-bridge escala para provider externo (camada 3)
   │ resposta capturada no Hub para reutilização futura
   │
5. Para demandas novas: cria constitution/specify/plan/tasks
   │
6. `analyze` valida estrutura, seções obrigatórias e gate Engineering Pillars
   │
7. Com gate aprovado, implementação/captura pode seguir
   │
8. Artefatos e soluções são publicados no Knowledge Hub
   │
9. hermes-update provisiona projetos registrados e mantém config atualizado (diário)
```

---

## 📐 Design Patterns em Uso

| Pattern | Onde Usado | Por quê |
|---------|-----------|---------|
| Repository | acesso SQLite no CLI | isolar consultas e persistência do fluxo operacional |
| Template Method | `specs/templates/*.md` | padronizar artefatos sem travar customização |
| Factory | setup e geração de estruturas | criar artefatos e diretórios consistentes |
| Strategy | presets/extensions | variar templates e gates sem reescrever o core |

---

## 🗄️ Modelo de Dados (Simplificado)

```
learned_solutions
  - solução ou artefato reutilizável (inclui workflow-spec/plan/tasks)
  - campos: domain, pattern, language, framework, content_hash (SHA-256)
  - índice FTS5 via solutions_fts para busca textual

factory_projects
  - projetos registrados na factory

learning_sessions
  - sessões e consumo agregado

reuse_log
  - histórico de reuso e economia de tokens

solutions_fts
  - índice FTS5 para busca textual (virtual table)

hermes_sessions         ← sessões do bridge: query, camada usada, tempo de resposta
hermes_escalations      ← registra quando precisou de provider externo (métricas de economia)
```

---

## 🔒 Segurança

- **Autenticação:** não exposta como plataforma multiusuário; operação local-first.
- **Autorização:** escopo controlado pelo operador no ambiente local.
- **Dados sensíveis:** evitar secrets em specs, prompts e capturas.
- **Secrets:** privilegiar env vars e configs locais, nunca hardcode.

---

## ⚡ Performance Considerations

- **Busca:** FTS5 local com sanitização por tokens para consultas com hífen e termos compostos.
- **Persistência:** SQLite em WAL para leitura concorrente e operação simples.
- **Dashboard:** leitura direta do `knowledge.db`, sem camada extra de API pesada.
- **Governança:** gate leve para não introduzir burocracia desnecessária.

---

## 📊 Métricas Atuais

| Métrica | Valor |
|---------|-------|
| CLI principal | PowerShell 5.1+ |
| Dashboard | Node.js HTTP local |
| Banco | SQLite + FTS5 + WAL |
| Agente local | Hermes + Ollama (WSL2) |
| Modelo padrão | llama3.2:3b |
| Resolução local | camadas 1+2 (hub + hermes) |
| Resolução externa | camada 3 (fallback medido) |
| Auto-update | Task Scheduler diário |
| Escopo de memória | soluções + specs + planos + tarefas |
| Operação | local-first, multiprojeto, offline-capable |

---

## 📎 Referências

- [AS-IS.md](../../.github/context/AS-IS.md) — Estado atual
- [TO-BE.md](../../.github/context/TO-BE.md) — Roadmap futuro (inclui fases H1-H5 Hermes)
- [type_matrix.md](../../.github/context/type_matrix.md) — Inventário de componentes
- [ADR-003-spec-workflow-governance.md](../decisions/ADR-003-spec-workflow-governance.md) — Fluxo SPEC leve
- [ADR-004-hermes-integration.md](../decisions/ADR-004-hermes-integration.md) — Integração Hermes
- [skills/hermes-integration.md](../../skills/hermes-integration.md) — Guia de uso Hermes
