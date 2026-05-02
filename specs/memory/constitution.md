# [PROJECT_NAME] Constitution

## Purpose

Estabelecer um fluxo leve e reutilizavel de especificacao, planejamento, validacao e captura de conhecimento para [PROJECT_NAME].

## Core Principles

1. Knowledge-first
   Buscar no acervo local antes de gerar algo novo.
2. Product-first
   Tratar [PROJECT_NAME] como produto com identidade clara e contexto proprio.
3. Multi-project reuse
   Tudo novo deve considerar reuso entre projetos e processos.
4. Lightweight governance
   Usar governanca suficiente para reduzir ambiguidade sem burocracia excessiva.
5. Capture after validation
   Publicar artefatos e solucoes no Knowledge Hub somente depois de um gate minimo de qualidade.

## Engineering Pillars (obrigatorio em todos os projetos)

### Pilar 1 — Security by Design
- Principio do Menor Privilegio: cada componente tem apenas as permissoes estritamente necessarias.
- Nunca confiar na entrada do usuario: validar e sanitizar todo input externo (forms, URLs, APIs).
- Gestao de Segredos: jamais hardcodar senhas, chaves de API ou tokens; usar variaveis de ambiente ou vault.
- Criptografia: TLS para dados em transito; Argon2 ou BCrypt (com salt) para senhas.

### Pilar 2 — Arquitetura e Design
- SOLID: seguir os cinco principios em codigo orientado a objetos.
- Clean Architecture: desacoplar regras de negocio de detalhes tecnicos (DB, UI, frameworks).
- DRY (Don't Repeat Yourself): abstrair logica duplicada em funcoes/modulos reutilizaveis.
- KISS (Keep It Simple, Stupid): preferir a solucao mais simples antes de super-otimizar.

### Pilar 3 — Qualidade do Codigo
- Nomes semanticos: variaveis e funcoes devem descrever claramente sua intencao.
- Testes automatizados (piramide): unitarios (70%), integracao (20%), E2E (10%).
- Code reviews: todo PR deve ter pelo menos uma revisao antes do merge.

### Pilar 4 — DevOps e Observabilidade
- CI/CD: automatizar builds, testes e deploys para eliminar erro humano.
- Logs e Monitoramento: o sistema deve alertar antes que o cliente perceba falha.
- Infraestrutura como Codigo (IaC): servidores e containers nao devem ser alterados manualmente.

## Delivery Rules

- Specs devem focar em objetivo e valor, nao em detalhe de implementacao precoce.
- Plans devem explicitar contexto tecnico, restricoes e slices de implementacao.
- Tasks devem estar em formato checklist e permitir execucao incremental.
- O gate `analyze` deve passar antes de implementar uma feature ou capturar artefatos do workflow.
- Presets podem customizar templates; extensions podem adicionar exigencias ao gate.
- Todo projeto gerado deve incluir checklist dos 4 Engineering Pillars antes do primeiro deploy.

## Current Focus

- qualidade, simplicidade, seguranca e reuso multiprojeto

