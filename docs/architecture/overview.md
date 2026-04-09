# 🏗️ Architecture Overview — IAgentsFactory

**Propósito:** visão técnica consolidada do produto e do fluxo de especificação leve  
**Nível:** Técnico — Arquitetos, mantenedores e agentes de automação

---

## 🎯 O Problema Que Resolvemos

```
ENTRADA:   demandas de código, arquitetura, operação e reuso entre projetos
DESAFIO:   evitar retrabalho, baixa rastreabilidade e dependência total de agentes externos
PROBLEMA:  conhecimento valioso se perde entre sessões e entre repositórios
RESULTADO: knowledge hub local + workflow SPEC leve + operação multiprojeto
ESCALA:    uso local-first, vários repositórios, múltiplos agentes e backlog incremental
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
│  ├─ register / search / capture / export / import    │
│  ├─ constitution / specify / plan / tasks / analyze  │
│  └─ Responsabilidade: coordenar fluxo knowledge-first│
├──────────────────────────────────────────────────────┤
│  GOVERNANCE LAYER                                    │
│  ├─ specs/memory, templates, presets, extensions     │
│  ├─ gate `analyze`                                   │
│  └─ Responsabilidade: reduzir ambiguidade e validar  │
├──────────────────────────────────────────────────────┤
│  PERSISTENCE LAYER                                   │
│  ├─ SQLite (`knowledge.db`) + FTS5                   │
│  ├─ learned_solutions / factory_projects / reuse_log │
│  └─ Responsabilidade: armazenar e ranquear memória   │
├──────────────────────────────────────────────────────┤
│  INTEGRATION LAYER                                   │
│  ├─ MCP Graph Workflow                               │
│  ├─ OpenClaude / agentes externos                    │
│  └─ Responsabilidade: extensão visual e providers    │
└──────────────────────────────────────────────────────┘
```

---

## 🔀 Fluxo Principal

```
1. Operador ou agente inicia uma demanda
   │
2. Factory executa `search` / `search-cross` antes de gerar algo novo
   │
3. Se a demanda for nova, cria `constitution/specify/plan/tasks`
   │
4. `analyze` valida estrutura, seções obrigatórias e placeholders
   │
5. Com gate aprovado, implementação/captura pode seguir
   │
6. Artefatos e soluções reutilizáveis são publicados no Knowledge Hub
   │
7. Próximos projetos reutilizam spec, plan, tasks e código já aprendido
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
factory_projects
  - projetos registrados na factory
learning_sessions
  - sessões e consumo agregado
reuse_log
  - histórico de reuso e economia de tokens
solutions_fts
  - índice FTS5 para busca textual
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
| Banco | SQLite + FTS5 |
| Escopo de memória | soluções + specs + planos + tarefas |
| Operação | local-first, multiprojeto |

---

## 📎 Referências

- [AS-IS.md](../../.github/context/AS-IS.md) — Estado atual
- [TO-BE.md](../../.github/context/TO-BE.md) — Roadmap futuro
- [type_matrix.md](../../.github/context/type_matrix.md) — Inventário de componentes
- [../decisions/ADR-003-spec-workflow-governance.md](../decisions/ADR-003-spec-workflow-governance.md) — Adoção do fluxo SPEC leve
