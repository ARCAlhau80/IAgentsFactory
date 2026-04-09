# 🗂️ TYPE MATRIX: Inventário de Componentes — IAgentsFactory

**Propósito:** Catálogo centralizado de TODOS os componentes, suas relações e status  
**Atualizado:** 2026-04-06

---

## 📋 Legend

- 🎯 = Componente principal
- 🔌 = Interface/Contract
- 📦 = Entity/Model (Domain)
- 🏗️ = Service/Use Case
- 🗄️ = Repository/DAO (Persistence)
- 🔄 = Strategy/Pattern
- ✅ = Bem implementado
- ⚠️ = Precisa refatorar
- ❌ = Problema crítico
- 🆕 = Novo (a ser criado)

---

## 1️⃣ AI Agents

| # | Componente | Arquivo | Responsabilidade | Status | Notas |
|---|-----------|---------|-----------------|--------|-------|
| 1 | 🎯 ARCHITECT | `.github/agents/ARCHITECT.md` | Design review, padrões, performance | ✅ | |
| 2 | 🎯 BACKEND | `.github/agents/BACKEND.md` | Geração de código | ✅ | |
| 3 | 🎯 QA | `.github/agents/QA.md` | Testes, cobertura, qualidade | ✅ | |
| 4 | 🎯 REFACTOR | `.github/agents/REFACTOR.md` | Code smells, limpeza | ✅ | |
| 5 | 🎯 COORDINATOR | `.github/agents/COORDINATOR.md` | Planejamento, sequenciamento | ✅ | |
| 6 | 🎯 OBSERVABILITY | `.github/agents/OBSERVABILITY.md` | Logs, métricas, tracing | ✅ | |
| 7 | 🎯 KNOWLEDGE | `.github/agents/KNOWLEDGE.md` | Memória persistente, reuso | 🆕 | Fase 1 |

---

## 2️⃣ Skills

| # | Componente | Arquivo | Responsabilidade | Status | Notas |
|---|-----------|---------|-----------------|--------|-------|
| 1 | 🏗️ Testing Strategies | `skills/testing-strategies.md` | Pirâmide de testes | ✅ | |
| 2 | 🏗️ Clean Architecture | `skills/clean-architecture.md` | Separação de camadas | ✅ | |
| 3 | 🏗️ Observability | `skills/observability.md` | Logs, métricas, traces | ✅ | |
| 4 | 🏗️ Security Basics | `skills/security-basics.md` | OWASP Top 10 | ✅ | |
| 5 | 🏗️ API Design | `skills/api-design.md` | REST best practices | ✅ | |
| 6 | 🏗️ Performance Tuning | `skills/performance-tuning.md` | N+1, cache, indexing | ✅ | |
| 7 | 🏗️ Domain-Driven Design | `skills/domain-driven-design.md` | DDD essentials | ✅ | |
| 8 | 🏗️ CI/CD | `skills/ci-cd.md` | Pipeline & Docker | ✅ | |
| 9 | 🏗️ Knowledge Capture | `skills/knowledge-capture.md` | Captura e reuso de soluções | 🆕 | Fase 1 |

---

## 3️⃣ Patterns

| # | Componente | Arquivo | Responsabilidade | Status | Notas |
|---|-----------|---------|-----------------|--------|-------|
| 1 | 🔄 Controller | `patterns/controller-pattern.md` | REST endpoint template | ✅ | |
| 2 | 🔄 Service | `patterns/service-pattern.md` | Business logic template | ✅ | |
| 3 | 🔄 Repository | `patterns/repository-pattern.md` | Data access template | ✅ | |
| 4 | 🔄 Entity | `patterns/entity-pattern.md` | Domain model template | ✅ | |
| 5 | 🔄 DTO | `patterns/dto-pattern.md` | Transfer object template | ✅ | |
| 6 | 🔄 Visitor | `patterns/visitor-pattern.md` | Traverse structures | ✅ | |

---

## 4️⃣ Prompts

| # | Componente | Arquivo | Prompts | Status | Notas |
|---|-----------|---------|---------|--------|-------|
| 1 | 📦 Code Generation | `prompts/code-generation.md` | 5 prompts | ✅ | |
| 2 | 📦 Testing | `prompts/testing.md` | 3 prompts | ✅ | |
| 3 | 📦 Refactoring | `prompts/refactoring.md` | 5 prompts | ✅ | |
| 4 | 📦 Documentation | `prompts/documentation.md` | 4 prompts | ✅ | |
| 5 | 📦 Observability | `prompts/observability.md` | 5 prompts | ✅ | |
| 6 | 📦 Knowledge Capture | `prompts/knowledge-capture.md` | 5 prompts | 🆕 | Fase 1 |

---

## 5️⃣ Context & Documentation

| # | Componente | Arquivo | Responsabilidade | Status | Notas |
|---|-----------|---------|-----------------|--------|-------|
| 1 | 🔌 Copilot Instructions | `.github/copilot-instructions.md` | Auto-loaded by Copilot | ✅ | Atualizado c/ KNOWLEDGE |
| 2 | 🔌 AS-IS | `.github/context/AS-IS.md` | Estado atual | ✅ | Atualizado para Factory |
| 3 | 🔌 TO-BE | `.github/context/TO-BE.md` | Roadmap 5 fases | ✅ | Atualizado para Factory |
| 4 | 🔌 Type Matrix | `.github/context/type_matrix.md` | Este arquivo | ✅ | |
| 5 | 📦 Architecture Analysis | `docs/architecture/IAGENTSFACTORY-ANALYSIS.md` | Análise técnica completa | 🆕 | |
| 6 | 📦 Presentation | `docs/architecture/IAGENTSFACTORY-PRESENTATION.md` | Apresentação executiva | 🆕 | |
| 7 | 📦 ADR-001 | `docs/decisions/ADR-001-knowledge-hub-architecture.md` | Decisão de banco | 🆕 | |

---

## 6️⃣ Integrations (Externas — Fase 1+)

| # | Componente | Localização | Papel | Status | Notas |
|---|-----------|-------------|-------|--------|-------|
| 1 | 🔌 MCP Graph Workflow | `C:\...\mcp-graph-workflow` v4.2.0 | Motor de persistência + RAG | ⚠️ | Integração pendente |
| 2 | 🔌 OpenClaude | `github.com/Gitlawb/openclaude` | Gateway multi-provider | ⬜ | Fase 3 |

---

## 4️⃣ Controllers / Endpoints

| # | Classe/Module | Base Path | Endpoints | Autenticação | Status |
|---|---------------|-----------|-----------|-------------|--------|
| 1 | [Entity1Controller] | /api/v1/entities | GET, POST, PUT, DELETE | JWT | ✅ |
| 2 | [ReportController] | /api/v1/reports | GET | JWT | 🆕 |

---

## 5️⃣ DTOs

| # | Classe/Module | Tipo | Entity Relacionada | Validações | Status |
|---|---------------|------|--------------------|-----------|--------|
| 1 | [Entity1Request] | Request | Entity1 | @NotBlank nome, @Email email | ✅ |
| 2 | [Entity1Response] | Response | Entity1 | — | ✅ |

---

## 6️⃣ Strategies / Patterns (se aplicável)

<!-- Remova esta seção se o projeto não usa Strategy Pattern -->

| # | Strategy | Tipo | Dependências | Status | Complexidade |
|---|----------|------|-------------|--------|-------------|
| 1 | [Strategy1] | [Type] | DAO1, Entity1 | ✅ | Simples |
| 2 | [Strategy2] | [Type] | DAO2, Entity2 | ⚠️ | Complexa |

---

## 📊 Resumo

| Categoria | Total | ✅ OK | ⚠️ Refactor | ❌ Crítico | 🆕 Novo |
|-----------|-------|-------|-------------|-----------|---------|
| Entities | [X] | [X] | [X] | [X] | [X] |
| Repositories | [X] | [X] | [X] | [X] | [X] |
| Services | [X] | [X] | [X] | [X] | [X] |
| Controllers | [X] | [X] | [X] | [X] | [X] |
| DTOs | [X] | [X] | [X] | [X] | [X] |
| **Total** | **[X]** | **[X]** | **[X]** | **[X]** | **[X]** |

---

## 🔗 Mapa de Dependências

```
Controller ──▶ Service ──▶ Repository ──▶ Entity
                 │
                 └──▶ Mapper ──▶ DTO
```

<!-- Adapte o diagrama para o seu projeto. Exemplos:
Controller → Service → Repository → Entity
Service → ExternalAPI
Service → MessageQueue
Scheduler → Service
-->

---

## 📎 Referências

- [Architecture Overview](../../docs/architecture/overview.md) — Visão geral da arquitetura
- [Legacy Analysis](../../docs/legacy-analysis/overview.md) — Análise de débito técnico
- [AS-IS.md](AS-IS.md) — Estado atual
- [TO-BE.md](TO-BE.md) — Roadmap

