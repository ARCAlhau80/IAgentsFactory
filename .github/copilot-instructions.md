# Copilot Instructions — IAgentsFactory

## 🎯 Quick Reference

**Project:** Evolução do ISGT para uma fábrica de agentes com foco em geração multi-processo, Knowledge Hub e operação multiprojeto.  
**Architecture:** Layered + Orchestration + Local Knowledge Hub  
**Language:** PowerShell 5.1+, JavaScript (Node.js), Markdown  
**Framework:** Node HTTP dashboard + SQLite local + MCP integration  
**Build:** `npm install` no MCP Graph quando necessário  
**Test:** Validação funcional via scripts e dashboard  
**Run:** `./iagents-factory.ps1 dashboard`

---

## 📌 Core Rules (ALWAYS follow)

<!-- Liste aqui as 3-7 regras mais críticas do seu projeto. 
     Estas regras NUNCA devem ser violadas pelo Copilot. -->

1. ✅ Sempre tratar `IAgentsFactory` como produto separado do ISGT original; o ISGT é a base conceitual, não o nome do produto final.
2. ✅ Priorizar fluxo knowledge-first: buscar localmente antes de propor chamada a agente externo.
3. ✅ Não acoplar soluções a um projeto único; tudo novo deve considerar reuso multiprojeto e multi-processo.
4. ✅ Não hardcodar credenciais nem depender de caminhos absolutos em lógica nova quando houver alternativa configurável.
5. ✅ Scripts, funções e nomes técnicos em inglês; explicações e documentação podem permanecer em português.
6. ✅ Para mudanças novas ou ambíguas, preferir o fluxo `constitution -> specify -> plan -> tasks -> analyze` antes de capturar ou implementar.

---

## 📚 Documentation Map

| Category | Location | Purpose |
|----------|----------|---------|
| **Project Context** | [.github/copilot/](copilot/) | O que o projeto faz, stack, padrões |
| **Domain Rules** | [.github/copilot/domains-rules.md](copilot/domains-rules.md) | Regras de negócio invioláveis |
| **Architecture** | [.github/context/](context/) | AS-IS, TO-BE, análise estratégica |
| **Agents** | [.github/agents/](agents/) | Agentes IA especializados |
| **Patterns** | [patterns/](../../patterns/) | Templates de design patterns |
| **Skills** | [skills/](../../skills/) | How-to guides técnicos |
| **Prompts** | [prompts/](../../prompts/) | Prompts prontos para IA |
| **Docs** | [docs/](../../docs/) | Arquitetura, legacy analysis, ADRs |
| **Type Matrix** | [.github/context/type_matrix.md](context/type_matrix.md) | Inventário de componentes |

---

## 🤖 AI Agents

| Agent | Responsabilidade | Usar quando |
|-------|-----------------|-------------|
| 🏛️ **ARCHITECT** | Design, Padrões, Performance | Revisar arquitetura de novo código |
| 💻 **BACKEND** | Geração de código | Gerar novo componente |
| 🧪 **QA** | Testes, Cobertura, Qualidade | Criar testes |
| 🔧 **REFACTOR** | Code smells, Limpeza | Melhorar código existente |
| 🎯 **COORDINATOR** | Planejamento, Sequenciamento | Planejar sprint/tarefas |
| 📊 **OBSERVABILITY** | Logs, Métricas, Tracing | Instrumentar código, debugar produção |
| 🧠 **KNOWLEDGE** | Memória persistente, Reuso | Buscar/capturar soluções, economizar tokens |

---

## 🏗️ Project Structure

<!-- Descreva a estrutura de pastas do seu projeto -->

```
IAgentsFactory/
├── .github/                   # Instruções, agentes e contexto Copilot
├── config/                    # Configurações da factory e examples
├── docs/                      # Arquitetura, ADRs, operação e onboarding
├── patterns/                  # Patterns reutilizáveis
├── prompts/                   # Prompts operacionais
├── specs/                     # Workflow SPEC leve, presets e extensions
├── skills/                    # Skills técnicas do ADK/factory
├── seed-solutions/            # Soluções iniciais para o Knowledge Hub
├── tools/                     # Dashboard e utilitários locais
├── iagents-factory.ps1        # CLI principal da factory
├── capture-pipeline.ps1       # Captura e ingestão de soluções
└── setup-ia-squad.ps1         # Setup legado para aplicação do ADK
```

---

## ⚙️ How to Use Agents

### Generate Code:
```
1. Ask BACKEND: "Generate [component type] for [requirement]"
2. Copilot reads patterns/ + coding-standards.md
3. Get: Complete, compilable code following project standards
```

### Code Review:
```
1. Ask ARCHITECT: "Review the design of [component]"
2. Copilot reads domains-rules.md + coding-standards.md
3. Get: Review report (approved/conditional/rejected)
```

### Create Tests:
```
1. Ask QA: "Create tests for [component]"
2. Copilot reads skills/ + testing patterns
3. Get: Complete test class with coverage
```

### Improve Code:
```
1. Ask REFACTOR: "Identify code smells in [file/component]"
2. Get: Report with prioritized improvements
```

