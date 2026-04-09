# 🎓 PROJECT CONTEXT — IAgentsFactory

**Propósito:** Entendimento rápido do projeto para desenvolvedores e IA  
**Nível:** Fundamental — leia ANTES de qualquer code change

---

## 🎯 O Que Este Projeto Faz

<!-- Descreva em 2-3 parágrafos o que o projeto faz, para quem, e por quê -->

**IAgentsFactory** é a evolução do ISGT para um produto de automação e orquestração de agentes com memória persistente.

Ele organiza agentes, prompts, patterns, skills e scripts operacionais para suportar geração multi-processo, busca de conhecimento local, captura de soluções e reuso entre múltiplos projetos.

**Casos de uso principais:**

### 1️⃣ Knowledge-First Delivery
```
Objetivo:     Reutilizar conhecimento antes de consumir tokens externos
Entrada:      Query do desenvolvedor, contexto do projeto, domínio e pattern
Saída:        Solução encontrada no Knowledge Hub ou decisão de gerar algo novo
Frequência:   Diária, antes de coding/debugging/design
Exemplo:      "Buscar uma solução de ROI ou integração já resolvida antes"
```

### 2️⃣ Multi-Project Knowledge Capture
```
Objetivo:     Capturar respostas úteis de agentes e armazenar para reuso futuro
Entrada:      Prompt original, solução gerada, metadados de domínio/language/framework
Saída:        Entrada indexada no Knowledge Hub com score, tags e hash
```

---

## 📍 Fluxo Mental

<!-- Diagrama mostrando o fluxo principal do sistema -->

```
┌──────────────────────────────┐
│  1. Need / Query             │
│     "ja resolvemos isso?"   │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│  2. Search / Route           │
│     search, search-cross     │
│     ou chamada externa       │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│  3. Capture / Reuse          │
│     knowledge hub cresce     │
│     e a fabrica aprende      │
└──────────────────────────────┘
```

---

## 🗂️ Conceitos-Chave (Glossário do Domínio)

<!-- Liste os termos do domínio que a IA precisa entender -->

| Termo | Definição | Exemplo |
|-------|-----------|---------|
| ADK | Base original de templates e contexto do ISGT | Agents, skills e patterns herdados do ISGT |
| Factory | Produto operacional com memória, captura e reuso | `iagents-factory.ps1 search-cross` |
| Knowledge Hub | Banco local SQLite com soluções aprendidas | `%USERPROFILE%\.iagents-factory\knowledge.db` |
| Multi-process generation | Geração coordenada entre vários agentes/processos/fases | search → architect → backend → qa → capture |
| Cross-project reuse | Reaproveitamento de solução entre repositórios | usar padrão do ToDo no LotoScope |

---

## 🏗️ Estrutura do Projeto

```
IAgentsFactory/
├── .github/                 # Instruções, agentes, contexto
├── config/                  # Settings, exemplos, sync guide
├── docs/                    # Manuais, arquitetura e ADRs
├── patterns/                # Templates de design e estrutura
├── prompts/                 # Prompts prontos para operação
├── skills/                  # Guias técnicos reutilizáveis
├── seed-solutions/          # Soluções iniciais para alimentar a base
├── tools/factory-dashboard/ # Dashboard local da fábrica
├── iagents-factory.ps1         # CLI de orquestração
└── capture-pipeline.ps1     # Pipeline de captura
```

---

## 🔄 Fluxo de Dados

<!-- Descreva como dados fluem pelo sistema -->

```
Query do dev → Busca local → Match / No match → Captura / Reuso → Métricas

Exemplo:
  "preciso de ETL" → search-cross → solução encontrada → adaptação → usage_count++
```

---

## 🏢 Integrações Externas

<!-- Liste sistemas externos que este projeto se comunica -->

| Sistema | Protocolo | Propósito | Criticidade |
|---------|-----------|-----------|-------------|
| MCP Graph Workflow | MCP + Node CLI | Busca, dashboard complementar e apoio ao grafo | Alta |
| GitHub | Git + GitHub API/CLI | Versionamento e segregação do novo produto | Alta |
| OpenClaude | CLI + MCP | Routing multi-provider planejado | Média |
| VS Code Copilot | Workspace instructions | Operação assistida por agentes | Alta |

---

## 👥 Stakeholders

| Quem | Papel | Interesse |
|------|-------|-----------|
| AR CALHAU | Owner e arquiteto do produto | Transformar o ADK em fábrica reutilizável multiprojeto |
| Devs locais | Usuários da factory | Reduzir retrabalho e ganho de produtividade |
| Agentes IA | Operadores da geração | Acessar contexto, padrões e memória persistente |

