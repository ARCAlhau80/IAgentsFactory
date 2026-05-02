# Implementation Plan - [FEATURE_TITLE]

**Project:** [PROJECT_NAME]  
**Feature Key:** [FEATURE_KEY]  
**Date:** [FEATURE_DATE]

## Summary

[FEATURE_DESCRIPTION]

## Technical Context

[TECH_CONTEXT]

## Architecture Notes

- Preferir simplicidade e baixo acoplamento.
- Integrar com o Knowledge Hub quando fizer sentido.
- Manter compatibilidade com operacao local-first.
- Clean Architecture: regras de negocio desacopladas de detalhes tecnicos (DB, HTTP, frameworks).
- Dependencias sempre injetadas (DI), nunca instanciadas diretamente.

## Security Design

- Superfície de ataque: [listar endpoints/inputs externos]
- Autenticação/Autorização: [mecanismo escolhido, roles envolvidas]
- Segredos: [como serão gerenciados — env vars, vault, etc.]
- Validação de input: [quais campos, onde é feita a sanitização]
- Criptografia: [TLS em trânsito; hashing de senhas se aplicável]

## Observability Plan

- Logs: [operações que emitirão log, nível (info/warn/error), campos obrigatórios]
- Health check: [endpoint /health se for API]
- Monitoramento: [alertas, métricas relevantes]

## Test Strategy

- Unitários: [componentes alvo, mocks necessários]
- Integração: [fluxos críticos a cobrir]
- E2E: [jornadas do usuário essenciais, se aplicável]

## Implementation Slices

1. Slice 1 - Fundacao funcional minima.
2. Slice 2 - Integracoes, validacoes e seguranca.
3. Slice 3 - Observabilidade, testes e captura.

## Validation Gate

- Spec sem placeholders.
- Plan sem lacunas estruturais.
- Tasks em formato checklist.
- Engineering Pillars verificados (security-basics.md + engineering-pillars.md).
- Publicacao no Knowledge Hub somente apos `analyze` aprovado.
