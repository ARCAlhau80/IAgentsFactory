# 📚 Skills — Guia de Uso

Esta pasta contém **how-to guides técnicos** para tarefas recorrentes.

## Como Usar

1. Quando precisar fazer algo técnico, procure aqui primeiro
2. Siga o passo-a-passo documentado
3. Adapte para o contexto específico do seu projeto

## Skills Disponíveis

| Arquivo | Quando Usar |
|---------|-------------|
| `testing-strategies.md` | Pirâmide de testes (unit/integration/E2E), frameworks, decision matrix |
| `clean-architecture.md` | Separar camadas, regras de dependência, migração gradual |
| `observability.md` | Logs estruturados, métricas (Prometheus), tracing, correlation IDs |
| `security-basics.md` | OWASP Top 10, autenticação, validação de input, secrets |
| `api-design.md` | REST best practices, URLs, status codes, paginação, error format |
| `performance-tuning.md` | N+1 queries, cache, batch processing, indexing, connection pool |
| `domain-driven-design.md` | Bounded contexts, aggregates, entities, value objects |
| `ci-cd.md` | GitHub Actions, Docker multi-stage, pipeline, .dockerignore |
| `_example-skill.md` | Exemplo/referência para criar novas skills |

## Como Criar uma Nova Skill

1. Copie `_example-skill.md` como base
2. Renomeie para `[tópico].md`
3. Preencha com o passo-a-passo testado e validado
4. Inclua exemplos de código que funcionam

## Sugestões de Skills por Necessidade

| Necessidade | Skill Sugerida |
|-------------|----------------|
| Adicionar testes | `testing-strategies.md` |
| Melhorar performance | `performance-tuning.md` |
| Adicionar logs/métricas | `observability.md` |
| Migrar versão de linguagem | `[language]-modernization.md` |
| Separar camadas | `clean-architecture.md` |
| Configurar CI/CD | `ci-cd.md` |
| Dockerizar | `containerization.md` |
| Configurar segurança | `security.md` |
| Escrever APIs | `api-design.md` |
| Configurar banco | `database.md` |
