# 🤖 Prompts — Guia de Uso

Esta pasta contém **prompts prontos** para usar com IA (Copilot, Claude, ChatGPT).

## Como Usar

1. Escolha o prompt adequado para sua tarefa
2. Substitua os `[PLACEHOLDERS]` com seu contexto
3. Cole no chat da IA ou use como instrução

## Prompts Disponíveis

| Arquivo | Quando Usar |
|---------|-------------|
| `code-generation.md` | Gerar controllers, services, repos, entities, módulos completos (5 prompts) |
| `testing.md` | Gerar unit tests, integration tests, test data factories (3 prompts) |
| `refactoring.md` | Identificar code smells, extract method, strategy, code review (5 prompts) |
| `documentation.md` | Gerar ADR, README, API docs, changelog (4 prompts) |
| `observability.md` | Adicionar logs, métricas, tracing, health checks (5 prompts) |
| `_example-prompt.md` | Exemplo/referência para criar novos prompts |

## Como Criar um Novo Prompt

1. Copie `_example-prompt.md`
2. Renomeie para `[ação].md` (ex: `code-generation.md`, `testing.md`)
3. Organize em seções com PROMPT #1, #2, etc.
4. Teste o prompt e ajuste até funcionar bem

## Sugestões de Prompts

| Tarefa | Prompt Sugerido |
|--------|-----------------|
| Gerar componentes novos | `code-generation.md` |
| Criar testes | `testing.md` |
| Refatorar código | `refactoring.md` |
| Documentar código | `documentation.md` |
| Code review | `code-review.md` |
| Debug/troubleshooting | `debugging.md` |
