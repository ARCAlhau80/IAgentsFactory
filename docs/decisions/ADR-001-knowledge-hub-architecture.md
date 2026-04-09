# ADR-001: Knowledge Hub Architecture — SQLite + MCP Graph Workflow

- **Status:** Accepted
- **Data:** 2026-04-06
- **Decisores:** AR CALHAU

## Contexto

O ISGT (IA Squad Generic Template) é atualmente um template estático de markdown que fornece contexto para agentes de IA. Cada interação com agentes externos (Claude, GPT-4o, DeepSeek, etc.) consome tokens e gera soluções que se perdem ao final da sessão. Ao trabalhar com múltiplos projetos que compartilham domínios similares (ex: cálculo de ROI em projeto de loteria e em software médico), as mesmas perguntas são repetidas, desperdiçando tokens e tempo.

**Necessidade:** Memória persistente de longa duração, local-first, capaz de indexar, buscar e reutilizar soluções aprendidas entre projetos e sessões.

## Decisão

Adotar **SQLite + FTS5 + TF-IDF embeddings** como Knowledge Hub, integrado via **MCP Graph Workflow** (v4.2.0), com **OpenClaude** como gateway multi-provider futuro (Fase 3).

### Componentes escolhidos:
1. **MCP Graph Workflow** → Motor de persistência (SQLite WAL + FTS5 + RAG pipeline + 26 MCP tools)
2. **OpenClaude** → Gateway multi-provider (200+ modelos, agent routing, MCP nativo)
3. **ISGT** → Orquestrador central (agents, patterns, skills, project registry)

### Banco de dados: SQLite (não PostgreSQL, não MongoDB)
- Local-first (1 arquivo, zero infra)
- FTS5 nativo para busca textual
- JSON via json_extract() para flexibilidade
- WAL mode para leituras concorrentes
- MCP Graph já implementa esta stack

## Alternativas Consideradas

| Alternativa | Prós | Contras |
|------------|------|---------|
| **PostgreSQL** | JSONB rico, tsvector, MVCC | Requer servidor, overkill para 1 dev, custos de hosting |
| **MongoDB** | Schema-less nativo, fácil escalar | Requer servidor, sem FTS robusto, overkill para local |
| **Arquivos JSON** | Zero setup, gitável | Sem busca textual, sem embeddings, sem queries complexas |
| **Redis** | Fast cache, expirable keys | Volátil, sem full-text, não é storage primário |
| **LanceDB** | Vector DB local, embeddings nativos | Imaturo, menos ecossistema, sem FTS5 |

## Consequências

### ✅ Positivas
- Reutilização de infraestrutura existente (MCP Graph já tem SQLite+FTS5+RAG)
- Zero custo de infraestrutura (local-first)
- 70-85% de compressão de tokens no contexto (RAG pipeline do MCP Graph)
- Economia estimada de 60-90% em tokens de APIs externas
- Portabilidade total (1 arquivo .db)
- Busca semântica local via TF-IDF (sem APIs externas)

### ⚠️ Negativas
- Complexidade de integração entre 3 sistemas (mitigada por fases incrementais)
- TF-IDF menos preciso que transformer embeddings (suficiente para v1, upgrade futuro)
- Single-user na v1 (team sync planejado para Fase 5)
- Dependência do MCP Graph Workflow como componente core

### 📐 Trade-offs aceitos
- Precisão de busca (TF-IDF) vs. simplicidade (sem API externa para embeddings)
- Local-only vs. portabilidade entre máquinas (resolvido na Fase 5 com Git sync)
- Captura automática vs. curadoria manual (híbrido: auto + scoring pelo dev)
