# 🏭 IAgentsFactory — Multi-Process AI Factory

**O que é:** Fábrica de agentes e automações com foco em **geração multi-processo**, memória persistente e reuso entre projetos.  
**Origem:** Evolução do ISGT, que permanece como ADK base e referência de templates.  
**Posicionamento:** `IAgentsFactory` é um produto separado, com identidade própria, voltado para orquestração, captura de conhecimento e execução multi-projeto.

**Novidade:** fluxo nativo de especificacao leve com `constitution -> specify -> plan -> tasks -> analyze`, ligado ao Knowledge Hub e com gate antes de implementacao/captura.

---

## 🧠 Como Funciona

```
┌─────────────────────────────────────────────────────────┐
│  Dev pede solução → Agente IA gera → Factory CAPTURA    │
│  Dev pede similar → Factory BUSCA  → Reutiliza (0 tok)  │
│  Economia cresce exponencialmente com o tempo            │
└─────────────────────────────────────────────────────────┘
```

**Ciclo de Vida:**
1. **Buscar** → `iagents-factory.ps1 search "cálculo roi"` → encontra solução anterior
2. **Gerar** → Se não encontrar, agente gera normalmente
3. **Capturar** → `iagents-factory.ps1 capture` → salva no Knowledge Hub
4. **Reutilizar** → Próximo projeto consulta automaticamente

---

## ⚡ Quick Start

### 1. Inicializar a Factory (uma vez)
```powershell
# Inicializa o Knowledge Hub (SQLite + FTS5)
.\iagents-factory.ps1 init
```

### 2. Registrar um projeto
```powershell
# Registra projeto existente (auto-detecta stack)
.\iagents-factory.ps1 register C:\caminho\meu-projeto
```

### 2.1. Exemplo real de portfolio multiprojeto
```powershell
.\iagents-factory.ps1 register C:\Users\AR CALHAU\source\repos\IA-Gro
.\iagents-factory.ps1 register C:\Users\AR CALHAU\source\repos\LotoScope
.\iagents-factory.ps1 register C:\Users\AR CALHAU\source\repos\ToDo
.\iagents-factory.ps1 register C:\Users\AR CALHAU\source\repos\AtualizadorLotofacil

# Ver carteira registrada na fabrica
.\iagents-factory.ps1 projects
```

### 3. Aplicar template IA Squad ao projeto
```powershell
# Via menu interativo
.\setup.bat

# Ou direto via PowerShell (auto-detecta tudo)
.\setup-ia-squad.ps1 -Auto
```

### 4. Buscar e capturar soluções
```powershell
# Buscar no Knowledge Hub
.\iagents-factory.ps1 search "validação de CPF"

# Buscar em outros projetos registrados
.\iagents-factory.ps1 search-cross "cálculo de ROI"

# Capturar solução de agente externo
.\iagents-factory.ps1 capture

# Pipeline automático (monitora clipboard)
.\capture-pipeline.ps1 -Watch

# Importar arquivo .solution.md
.\capture-pipeline.ps1 -FromFile minha-solucao.solution.md

# Popular a demo multiprojeto com seeds reais
.\capture-pipeline.ps1 -FromFile .\seed-solutions\todo-kanban-status-api.solution.md -Project ToDo
.\capture-pipeline.ps1 -FromFile .\seed-solutions\lotoscope-analytics-pipeline.solution.md -Project LotoScope
```

### 4.1. Fluxo leve de especificacao
```powershell
# 1. Ajustar a constituicao do projeto
.\iagents-factory.ps1 constitution "qualidade, simplicidade e reuso multiprojeto"

# 2. Criar uma feature spec
.\iagents-factory.ps1 specify "Painel de intake de demandas com classificacao e trilha de aprovacao"

# 3. Gerar plano tecnico
.\iagents-factory.ps1 plan "PowerShell + Node, SQLite, baixo acoplamento e knowledge-first"

# 4. Gerar tarefas e publicar artefatos no Knowledge Hub apos gate
.\iagents-factory.ps1 tasks

# 5. Rodar o gate manualmente quando precisar
.\iagents-factory.ps1 analyze
```

### 5. Métricas
```powershell
.\iagents-factory.ps1 stats
```

### 6. Dashboards
```powershell
# Dashboard nativo da Factory (knowledge.db)
.\iagents-factory.ps1 dashboard

# Dashboard do MCP Graph (workflow / task graph)
.\iagents-factory.ps1 dashboard mcp
```

O dashboard da Factory suporta filtros por projeto, linguagem e domínio para navegar o acervo multiprojeto.

---

## 📁 Estrutura

```
IAgentsFactory/
├── .github/
│   ├── copilot-instructions.md      ← Configuração central Copilot
│   ├── copilot/                     ← Contexto técnico do projeto
│   ├── context/                     ← AS-IS, TO-BE, type_matrix
│   └── agents/                      ← 8 agentes IA (incl. KNOWLEDGE)
├── config/                          ← Configs da Factory
│   ├── openclaude-settings.json     ← Template OpenClaude com routing
│   ├── dashboard-config.json        ← Métricas e KPIs do Knowledge Hub
│   ├── git-sync-guide.md            ← Guia team sync via Git
│   ├── .gitignore-factory           ← Gitignore para projetos clientes
│   └── _example.solution.md         ← Formato de captura de soluções
├── docs/                            ← Documentação técnica
│   ├── architecture/
│   │   ├── overview.md
│   │   ├── IAGENTSFACTORY-ANALYSIS.md ← Análise técnica completa
│   │   └── IAGENTSFACTORY-PRESENTATION.md
│   ├── decisions/
│   │   ├── README.md
│   │   └── ADR-001-knowledge-hub-architecture.md
│   └── legacy-analysis/
├── patterns/                        ← Templates de design patterns
│   ├── controller-pattern.md, service-pattern.md, etc.
│   └── _example-pattern.md
├── seed-solutions/                  ← Seeds de captura para demo multiprojeto
│   ├── iagentsfactory-dashboard-knowledge.solution.md
│   ├── todo-kanban-status-api.solution.md
│   ├── lotoscope-analytics-pipeline.solution.md
│   ├── ia-gro-python-entrypoint.solution.md
│   └── atualizadorlotofacil-api-sync.solution.md
├── skills/                          ← How-to guides técnicos
│   ├── testing-strategies.md, clean-architecture.md, etc.
│   ├── knowledge-capture.md         ← Skill de captura/reuso
│   └── _example-skill.md
├── prompts/                         ← Prompts prontos para IA
│   ├── code-generation.md, testing.md, refactoring.md, etc.
│   ├── knowledge-capture.md         ← 5 prompts de knowledge
│   └── _example-prompt.md
├── specs/                           ← Workflow leve de constitution/specify/plan/tasks
│   ├── memory/constitution.md       ← Principios do projeto
│   ├── templates/                   ← Templates core do workflow
│   ├── presets/                     ← Overrides de templates
│   └── extensions/                  ← Regras extras para o gate analyze
├── .mcp.json                        ← Integração MCP Graph Workflow
├── iagents-factory.ps1              ← CLI principal da Factory
├── isgt-factory.ps1                 ← Wrapper de compatibilidade
├── capture-pipeline.ps1             ← Pipeline de captura automática
├── setup-ia-squad.ps1               ← Setup de projetos (auto-detect)
└── setup.bat                        ← Menu interativo Windows
```

---

## 🤖 Agentes IA

| Agente | Responsabilidade | Quando Usar |
|--------|-----------------|-------------|
| 🏛️ ARCHITECT | Design, Padrões | Revisar arquitetura |
| 💻 BACKEND | Geração de código | Gerar componentes |
| 🧪 QA | Testes, Cobertura | Criar testes |
| 🔧 REFACTOR | Code smells | Melhorar código |
| 🎯 COORDINATOR | Planejamento | Planejar sprints |
| 📊 OBSERVABILITY | Logs, Métricas | Instrumentar |
| 🧠 KNOWLEDGE | Memória, Reuso | Buscar/capturar soluções |

---

## 🏭 Knowledge Hub

### Comandos da Factory CLI

| Comando | Descrição |
|---------|-----------|
| `init` | Inicializa Knowledge Hub (SQLite + FTS5) |
| `register [path]` | Registra projeto (auto-detecta stack) |
| `constitution [foco]` | Atualiza a constituicao operacional do projeto |
| `specify "desc"` | Cria uma spec leve em `specs/NNN-feature/` |
| `plan [contexto]` | Gera plano tecnico e artefatos auxiliares da feature ativa |
| `tasks` | Gera checklist de execucao, roda o gate e publica artefatos no Hub |
| `analyze [feature]` | Valida completude estrutural antes de implementar ou capturar |
| `capture` | Captura solução interativamente |
| `search "query"` | Busca full-text no Knowledge Hub e registra reuso do melhor match |
| `search-cross "query"` | Busca em outros projetos registrados, excluindo o projeto atual quando conhecido |
| `stats` | Dashboard de métricas e economia |
| `projects` | Lista projetos registrados |
| `export` | Exporta knowledge para JSON (Git sync) |
| `import [file]` | Importa knowledge de outro dev |
| `cleanup` | Remove soluções depreciadas |
| `dashboard` | Abre dashboard da Factory ligado ao knowledge.db |

### Dashboards Disponiveis

| Comando | URL | Papel |
|---------|-----|-------|
| `dashboard` | `http://localhost:3010` | Dashboard da Factory, ligado ao Knowledge Hub |
| `dashboard mcp` | `http://localhost:3000` | Dashboard do MCP Graph, ligado a workflow e backlog |

### Workflow SPEC Leve

O fluxo `SPEC` complementa o knowledge-first da factory com governanca minima e reutilizavel:

1. `constitution` define principios e foco operacional do projeto.
2. `specify` cria a feature e fixa objetivo, goals e criteria.
3. `plan` traduz a spec para slices tecnicos e validacao.
4. `tasks` quebra a entrega em checklist, roda `analyze` e publica `constitution/spec/plan/tasks` no Knowledge Hub.
5. `analyze` endurece o gate com templates, presets e extensions.

Esse fluxo permite que spec, plan e tasks tambem virem memoria reutilizavel da fabrica, e nao apenas codigo final.

### Exemplo Real de Fabrica Local

Hoje a Factory pode operar com um portfolio real de projetos locais, por exemplo:

| Projeto | Papel na Fabrica |
|---------|------------------|
| `IAgentsFactory` | Produto operacional da factory |
| `IA-Gro` | Exemplo de projeto Python empacotado em solution do Visual Studio |
| `LotoScope` | Exemplo de projeto Python analitico com alta densidade de scripts |
| `ToDo` | Exemplo de app web pequeno para onboardings e testes rapidos |
| `AtualizadorLotofacil` | Exemplo adicional de job .NET 8 com integracao SQL Server |

Isso permite demonstrar o fluxo de `register`, `projects`, `search-cross` e dashboard sobre repositorios reais, sem depender de exemplos artificiais.

### Formato de Captura (.solution.md)

```markdown
---
domain: financial
pattern: calculation
language: java
framework: spring-boot
agent: claude-sonnet
quality: 0.9
tags: roi, investment
---
## Prompt
<prompt original>
## Solution
<código/solução>
## Summary
<resumo 1-2 linhas>
```

### Capture Pipeline

```powershell
# Monitor clipboard (cola solução → captura automática)
.\capture-pipeline.ps1 -Watch

# Importar de arquivo
.\capture-pipeline.ps1 -FromFile solucao.solution.md

# Importar de commits Git
.\capture-pipeline.ps1 -FromGit

# Importar diretório inteiro
.\capture-pipeline.ps1 -Batch .\solutions\
```

---

## 🔗 Integrações

### MCP Graph Workflow
- Banco SQLite WAL + FTS5 para busca full-text
- 26 tools MCP para manipulação via agentes
- Dashboard React para visualização

### OpenClaude
- 200+ modelos (Anthropic, OpenAI, DeepSeek, Ollama)
- Agent routing automático por tipo de tarefa
- MCP nativo para acesso ao Knowledge Hub

### VS Code Copilot
- `copilot-instructions.md` lido automaticamente
- Agentes especializados via `.github/agents/`
- Skills e patterns carregados sob demanda

---

## 👥 Team Sync (Git)

```powershell
# Dev A: exporta knowledge
.\iagents-factory.ps1 export
git add .iagents-factory/exports/ && git commit -m "knowledge export" && git push

# Dev B: importa knowledge
git pull
.\iagents-factory.ps1 import .iagents-factory\exports\knowledge-export-*.json
# Dedup automático via content_hash
```

---

## ❓ FAQ

**P: Preciso de tudo isso?**  
R: Não. O mínimo é `setup-ia-squad.ps1` para projetos. A Factory (Knowledge Hub) é opcional e incremental.

**P: Funciona com qualquer linguagem?**  
R: Sim. Auto-detecta Java, TypeScript, Python, C#, Go, Rust.

**P: Quanto custa?**  
R: Zero. SQLite local, sem infra cloud. Economiza tokens ao reutilizar soluções.

**P: Como medir a economia?**  
R: `.\iagents-factory.ps1 stats` mostra tokens economizados e custo evitado.

**P: E se não tiver sqlite3 instalado?**  
R: O script usa Node.js + better-sqlite3 do MCP Graph como fallback.

**P: O comando `isgt-factory.ps1` ainda funciona?**  
R: Sim. Existe um wrapper de compatibilidade, mas o comando recomendado agora e `./iagents-factory.ps1`.

---

## 📊 Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTATION                          │
│  VS Code Copilot │ OpenClaude CLI │ MCP Dashboard       │
├─────────────────────────────────────────────────────────┤
│                   ORCHESTRATION                         │
│  Factory CLI │ Capture Pipeline │ Setup Script           │
├─────────────────────────────────────────────────────────┤
│                   INTELLIGENCE                          │
│  FTS5 Search │ RAG (TF-IDF) │ Agent Routing             │
├─────────────────────────────────────────────────────────┤
│                   PERSISTENCE                           │
│  SQLite WAL │ Knowledge Store │ Project Registry         │
├─────────────────────────────────────────────────────────┤
│                   PROVIDER                              │
│  Anthropic │ OpenAI │ DeepSeek │ Ollama │ Copilot       │
└─────────────────────────────────────────────────────────┘
```

---

**Licença:** MIT  
**Autor:** AR CALHAU  
**Versão:** 2.0.0 (Factory Edition)

