# Skill: Multi-Agent Orchestration

> **Gerado pela IAgentsFactory** — documenta o modelo de orquestração multi-agente paralela.

---

## O que é

Todo projeto criado ou importado pela factory inicia **automaticamente** uma sessão multi-agente.
Cada agente recebe:
- Contexto específico da sua especialidade
- Conhecimento do stack tecnológico do projeto
- Acesso ao Knowledge Hub para reuso de soluções anteriores

---

## Mapa de paralelismo

```
[FASE 1] — SEQUENCIAL
  KNOWLEDGE → Consulta o Hub antes de qualquer geração

[FASE 2] — PARALELO (rodam simultaneamente)
  ├── ARCHITECT    → Design e validação de arquitetura
  ├── QA           → Plano de testes e cobertura
  └── OBSERVABILITY → Estratégia de logs e métricas

[FASE 3] — SEQUENCIAL (aguarda FASE 2)
  BACKEND → Implementa com o contexto completo das fases anteriores

[FASE 4] — PARALELO
  ├── QA      → Gera testes unitários para o código gerado
  └── REFACTOR → Analisa code smells e sugere melhorias

[FASE 5] — SEQUENCIAL (gate obrigatório)
  BUILD  → build + test (0 erros + 0 falhas = pré-requisito)
  COMMIT → commit semântico (Conventional Commits)
  DEPLOY → local/dev + health check + rollback documentado
```

**Regra de paralelismo:** dois agentes podem rodar em paralelo se nenhum consumir saída do outro como entrada direta.

---

## Arquivos gerados por projeto

| Arquivo | Propósito |
|---------|-----------|
| `.github/copilot-instructions.md` | Instruções de sessão com stack + contexto por agente |
| `specs/agent-session.md` | Plano de orquestração com tabela de dependências e queries Hub |

Esses arquivos são gerados automaticamente pelo `new-project.ps1` via `Initialize-MultiAgentSession`.

---

## Knowledge Hub — vinculação por projeto

Toda solução capturada deve ser tagueada com o projeto de origem:

```powershell
.\capture-pipeline.ps1 -FromFile <arquivo.solution.md> -Project "NomeDoProjeto"
```

Isso garante que:
1. A solução fica disponível para todos os projetos futuros (cross-project learning)
2. O campo `source_project` no Hub registra a origem
3. Buscas futuras retornam o contexto completo de onde a solução veio

### Query de aprendizados por projeto

```sql
SELECT domain, pattern, solution_summary, created_at
FROM learned_solutions
WHERE source_project = 'NomeDoProjeto'
ORDER BY created_at DESC;
```

---

## Contexto por agente — como é provisionado

O `new-project.ps1` chama helper functions específicas por stack:

| Função | Agente | Conteúdo |
|--------|--------|----------|
| `Get-BackendAgentContext` | BACKEND | Estrutura de pastas, endpoint base, async pattern, validação |
| `Get-QaAgentContext` | QA | Framework de teste, pasta, comando, foco de cobertura |
| `Get-BuildAgentContext` | BUILD | Comandos de build/test, gate de qualidade |
| `Get-DeployAgentContext` | DEPLOY | Comando run, pre-condições, health check |

Para stacks sem scaffold nativo (N/A/custom), os contextos são gerados com o `Label`, `Language`, `Framework` e comandos informados pelo usuário.

---

## Adicionando suporte a novo stack

Para adicionar contexto específico a um novo stack (ex: `go`, `rust`, `django`):

1. Abrir `new-project.ps1`
2. Adicionar novo `case` em `Get-BackendAgentContext`, `Get-QaAgentContext`
3. O `Initialize-MultiAgentSession` e `Register-ProjectInHub` funcionam automaticamente

---

## Regras obrigatórias da sessão

1. **KNOWLEDGE sempre primeiro** — consultar Hub antes de gerar código
2. **BUILD gate** — BUILD deve passar antes de COMMIT (0 erros + 0 falhas)
3. **Segredos via env vars** — nunca hardcoded no código ou nos arquivos de sessão
4. **Captura obrigatória** — toda solução nova deve ser registrada no Hub com `-Project`
5. **Logs estruturados** — sem `print`/`console.log` direto; usar logger configurado
