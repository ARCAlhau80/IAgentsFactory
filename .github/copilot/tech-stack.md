# 🛠️ TECH STACK — IAgentsFactory

**Propósito:** SSOT (Single Source of Truth) para todas as dependências  
**Atualizado:** 2026-04-09

---

## 📦 Stack Atual

### Linguagem & Runtime
```
Language:       PowerShell 5.1+, JavaScript, Markdown
Runtime:        Windows PowerShell + Node.js
Package Mgr:    npm (para MCP Graph e dashboard dependencies)
```

### Framework Principal
```
Framework:      Node HTTP utilitário + MCP Graph Workflow
ORM/ODM:        none (acesso SQLite direto via sqlite3/better-sqlite3)
API Style:      CLI + local HTTP dashboard + MCP
Auth:           GitHub auth via gh CLI quando necessário
```

### Banco de Dados
```
Primary DB:     SQLite (knowledge.db)
Cache:          none
Search:         SQLite FTS5 + TF-IDF via MCP Graph
Queue:          none hoje; multi-process orchestration e routing sao aplicacionais
```

### Logging & Observabilidade
```
Logging:        Console + logs locais de scripts
Metrics:        Queries SQLite + dashboard local
Tracing:        none
```

### Testes
```
Unit:           n/a formal ainda
Mocks:          n/a
Integration:    Fluxos locais PowerShell + MCP Graph
Coverage:       Validacao manual e smoke tests
Target:         Cobrir fluxos criticos antes de automatizar suite
```

### Infra & CI/CD
```
CI/CD:          GitHub Actions futuro
Container:      none
Deploy:         local-first
IaC:            none
```

---

## 📊 Dependências — Matriz de Status

| Lib | Versão Atual | Versão Target | Status | Breaking? |
|-----|-------------|---------------|--------|-----------|
| Node.js | ambiente local | LTS atual | 🟡 | Não |
| sqlite3 CLI | ambiente local | atual | 🟡 | Não |
| better-sqlite3 | via MCP Graph | compatível com Node local | 🟡 | Possível |
| GitHub CLI | instalado localmente | atual | ✅ | Não |

**Legenda:** ✅ Atualizado | 🟡 Update disponível | 🔴 EOL/Vulnerável

---

## 🔄 Caminho de Migração (se aplicável)

### ISGT ADK → IAgentsFactory Product Split
```
Esforço:    Médio
Risco:      Médio
Bloqueios:  consolidar naming, remover placeholders e estabilizar fluxo multi-processo
```

### MCP Graph Dependence Hardening
```
Esforço:    Médio
Risco:      Médio
```

---

## 🔒 Vulnerabilidades Conhecidas

| CVE | Lib | Severidade | Status | Mitigação |
|-----|-----|------------|--------|-----------|
| n/d | better-sqlite3 / Node transitive deps | A revisar | 🟡 Unknown | Rodar auditoria no repo MCP Graph e no dashboard quando houver package.json próprio |

<!-- Manter atualizado com `npm audit`, `mvn dependency-check:check`, `pip audit`, etc. -->
