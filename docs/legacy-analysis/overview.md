# 📚 Legacy Analysis Overview — [PROJECT_NAME]

**Propósito:** Identificar code smells, débitos técnicos e oportunidades de refatoração  
**Nível:** Arquitetos & Equipe de Refactoring

---

## 🗺️ Mapa de Problemas (Heat Map)

<!-- Classifique os componentes por severidade -->

```
┌─────────────────────────────────────────────────────────┐
│  CÓDIGO LEGADO — Heat Map                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🔴 CRITICAL (Corrigir primeiro)                        │
│  ├─ [Classe/módulo 1]            ([motivo])            │
│  ├─ [Classe/módulo 2]            ([motivo])            │
│  └─ [Classe/módulo 3]            ([motivo])            │
│                                                         │
│  🟡 MEDIUM (Planejar para próximas sprints)             │
│  ├─ [Classe/módulo 4]            ([motivo])            │
│  ├─ [Classe/módulo 5]            ([motivo])            │
│  └─ [Classe/módulo 6]            ([motivo])            │
│                                                         │
│  🟢 LOW (Melhorar quando possível)                      │
│  ├─ [Classe/módulo 7]            ([motivo])            │
│  └─ [Classe/módulo 8]            ([motivo])            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🩺 Code Smell Catalog

<!-- Para cada smell encontrado, documente: -->

### #1: [Nome do Smell]

**Localização:** `[arquivo/classe]`  
**Severidade:** 🔴 CRITICAL / 🟡 MEDIUM / 🟢 LOW

```
📊 Linhas de código: [XX]
📊 Complexidade ciclomática: [XX]
📊 Métodos: [XX]
🔴 SMELL: [God Object / Long Method / Feature Envy / ...]
```

**Problema:** [Descreva por que é um problema]

**Solução Proposta:**
1. [Passo 1]
2. [Passo 2]
3. [Passo 3]

**Esforço estimado:** [horas/dias]  
**Risco de regressão:** [alto/médio/baixo]

---

### #2: [Nome do Smell]

<!-- Repetir a estrutura acima para cada smell -->

---

## 📊 Resumo Quantitativo

| Categoria | Quantidade | Impacto |
|-----------|-----------|---------|
| 🔴 Critical smells | [X] | Bugs, performance, segurança |
| 🟡 Medium smells | [X] | Manutenção difícil |
| 🟢 Low smells | [X] | Qualidade de código |
| **Total** | **[X]** | |

---

## 🎯 Priorização de Refactoring

<!-- Ordene por: impacto × facilidade de correção -->

| Prioridade | Componente | Smell | Esforço | Impacto | ROI |
|-----------|------------|-------|---------|---------|-----|
| 1 | [Componente] | [Smell] | [X]h | 🔴 Alto | ⭐⭐⭐ |
| 2 | [Componente] | [Smell] | [X]h | 🔴 Alto | ⭐⭐⭐ |
| 3 | [Componente] | [Smell] | [X]h | 🟡 Médio | ⭐⭐ |
| 4 | [Componente] | [Smell] | [X]h | 🟢 Baixo | ⭐ |

---

## 🔧 Padrões de Refactoring Recomendados

| Smell | Refactoring | Referência |
|-------|-------------|-----------|
| God Class (> 500 LOC) | Extract Class + Single Responsibility | prompts/refactoring.md |
| Long Method (> 30 LOC) | Extract Method | prompts/refactoring.md #2 |
| if/else chain (> 4 branches) | Replace Conditional with Strategy | prompts/refactoring.md #3 |
| Código duplicado | Extract shared method/class | prompts/refactoring.md #4 |
| SQL concatenation | Parameterized queries | skills/security-basics.md |
| System.out / print | Structured logging | skills/observability.md |

---

## 📎 Referências

- [Architecture Overview](../architecture/overview.md) — Como o sistema está estruturado
- [AS-IS.md](../../.github/context/AS-IS.md) — Estado atual do projeto
- [Refactoring Prompts](../../prompts/refactoring.md) — Prompts prontos para refatorar
- [REFACTOR Agent](../../.github/agents/REFACTOR.md) — Agente especializado em limpeza
