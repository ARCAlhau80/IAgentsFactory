# 📐 Patterns — Guia de Uso

Esta pasta contém **templates de design patterns** específicos para [PROJECT_NAME].

## Como Usar

1. **Identifique** qual tipo de componente precisa criar
2. **Copie** o pattern relevante como base
3. **Adapte** para o caso de uso específico
4. **Remova** os placeholders e comentários de instrução

## Patterns Disponíveis

| Arquivo | Quando Usar | Componente |
|---------|-------------|------------|
| `controller-pattern.md` | Criar endpoint REST | Controller, Router, Handler |
| `service-pattern.md` | Lógica de negócio | Service, Use Case |
| `repository-pattern.md` | Acesso a dados | Repository, DAO |
| `entity-pattern.md` | Modelo de domínio | Entity, Model |
| `dto-pattern.md` | Transfer objects | Request, Response, DTO |
| `visitor-pattern.md` | Percorrer estruturas (arquivos, árvores) | Visitor, Element, Walker |
| `_example-pattern.md` | Exemplo/referência para novos patterns | Qualquer |

## Como Criar um Novo Pattern

1. Copie `_example-pattern.md` como base
2. Renomeie para `[componente]-pattern.md`
3. Preencha com o template específico do seu projeto
4. Adicione exemplos ✅ (correto) e ❌ (errado)

## Sugestões de Patterns por Stack

| Stack | Patterns Sugeridos |
|-------|--------------------|
| Java + Spring | controller, service, repository, entity, dto, mapper, exception |
| Node + Express | router, controller, service, model, middleware, validator |
| Python + FastAPI | router, service, repository, schema, model |
| React/Vue/Angular | component, hook, store, service, page |
| .NET | controller, service, repository, entity, dto |
