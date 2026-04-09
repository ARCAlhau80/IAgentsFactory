# 📊 AS-IS — Estado Atual do IAgentsFactory

**Última atualização:** 2026-04-09  
**Status:** Produto separado do ISGT, com runtime local já operacional

---

## 🏗️ Stack Atual

```
Type:           AI Factory local-first com ADK herdado do ISGT
Language:       PowerShell + JavaScript + Markdown
AI Integration: VS Code Copilot Agents (.github/) + MCP Graph + OpenClaude template
Database:       SQLite local (.iagents-factory/knowledge.db)
Build:          Node.js para dashboard e integrações MCP
Tests:          Smoke/validação funcional manual
```

---

## 🎯 O Que Funciona Bem

✅ **Knowledge Hub funcional** — SQLite + FTS5 + export/import + métricas  
✅ **Dashboard operacional** — painel próprio da factory em Node.js  
✅ **Registro multiprojeto** — carteira local de projetos para reuso cross-project  
✅ **Capture pipeline** — ingestão por arquivo, lote, clipboard e Git  
✅ **ADK herdado do ISGT** — agents, patterns, prompts e skills continuam reutilizáveis  
✅ **Setup com auto-detect** — PowerShell detecta stack automaticamente (Java, Node, Python, C#, Go, Rust)  
✅ **Produto separado** — roadmap e naming próprios como IAgentsFactory  

---

## 🔴 Pain Points & Dívidas Técnicas

| # | Problema | Severidade | Impacto | Origem |
|---|----------|------------|---------|--------|
| 1 | Testes automatizados ainda não formalizados | 🟡 Média | Regressões dependem de smoke/manual | Base ainda em consolidação |
| 2 | Parte do acervo ainda é template genérico herdado do ADK | 🟡 Média | Pode confundir onboarding sem curadoria | Herança do ISGT |
| 3 | Dependência local de MCP Graph para alguns fluxos avançados | 🟡 Média | Build/config externo ainda influencia operação | Arquitetura composta |
| 4 | Team sync ainda depende de disciplina operacional | 🟡 Média | Compartilhamento não é transparente entre devs | Fase de Git sync inicial |
| 5 | Base de conhecimento ainda pequena | 🟡 Média | Match rate tende a ser baixo no começo | Poucas capturas iniciais |
| 6 | Diagnóstico/editor pode manter resíduos de nomenclatura antiga | 🟢 Baixa | Ruído operacional pontual | Migração recente |

**Severidade:** 🔴 Crítica (segurança, data loss) | 🟡 Média (produtividade) | 🟢 Baixa (cosmético)

---

## 📊 Métricas Atuais

| Métrica | Valor | Status |
|---------|-------|--------|
| Agents funcionais | 7 | ✅ |
| Patterns disponíveis | 7+ | ✅ |
| Skills documentadas | 9+ | ✅ |
| Prompts prontos | 20+ | ✅ |
| Linguagens suportadas | 6+ (Java, TS, Python, C#, Go, Rust) | ✅ |
| Knowledge persistido | Ativo em SQLite local | ✅ |
| Projetos simultâneos | Multi-projeto | ✅ |
| Token savings | Medido via stats/dashboard | ✅ |
| Busca local de soluções | search + search-cross | ✅ |

---

## ⚠️ Riscos Identificados

1. **Curadoria insuficiente do acervo** — capturas ruins degradam a busca local
2. **Dependência de setup local** — Node/MCP/SQLite precisam estar consistentes por máquina
3. **Integração multiprojeto ainda amadurecendo** — heurísticas e metadados podem evoluir
4. **Acoplamento operacional com ferramentas locais** — mudanças em MCP Graph podem exigir ajustes

---

## 🔗 Componentes Complementares Disponíveis

| Componente | Localização | Status | Papel Futuro |
|------------|-------------|--------|--------------|
| **ISGT ADK** | Base conceitual herdada | ✅ Disponível | Patterns, prompts, skills e agentes-base |
| **MCP Graph Workflow** | `C:\...\mcp-graph-workflow` | ✅ Funcional | Persistência complementar, RAG e dashboard MCP |
| **OpenClaude** | `github.com/Gitlawb/openclaude` | ✅ Open source | Gateway multi-provider futuro |

---

<!-- Evolução planejada: ver TO-BE.md e docs/architecture/IAGENTSFACTORY-ANALYSIS.md -->

