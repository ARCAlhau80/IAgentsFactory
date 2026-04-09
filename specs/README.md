# [PROJECT_NAME] - Specs Workflow

Esta pasta implementa um fluxo leve inspirado no Spec-Driven Development, adaptado para [PROJECT_NAME].

## Fluxo

1. `constitution`
   Define os principios do projeto e os gates de entrega.
2. `specify`
   Cria a especificacao funcional da feature em `specs/NNN-feature/spec.md`.
3. `plan`
   Traduz a spec em plano tecnico e artefatos auxiliares.
4. `tasks`
   Gera a quebra de execucao, roda o gate `analyze` e publica `constitution/spec/plan/tasks` no Knowledge Hub.
5. `analyze`
   Valida se os artefatos estao completos, sem placeholders e prontos para implementacao.

## Estrutura

```text
specs/
├── memory/
│   └── constitution.md
├── templates/
│   ├── spec-template.md
│   ├── plan-template.md
│   ├── tasks-template.md
│   ├── research-template.md
│   ├── data-model-template.md
│   ├── quickstart-template.md
│   └── contracts-template.md
├── presets/
│   ├── README.md
│   └── active-preset.json
├── extensions/
│   ├── README.md
│   └── extensions.json
└── 001-example-feature/
```

## Presets

Presets sobrescrevem templates sem alterar o core do projeto bootstrapado pela factory.

- Ativacao: `specs/presets/active-preset.json`
- Resolucao: `specs/presets/<preset-id>/templates/*.md`
- Fallback: `specs/templates/*.md`

## Extensions

Extensions adicionam regras extras de analise e artefatos obrigatorios via `specs/extensions/extensions.json`.

O modelo atual e leve: a factory usa esse arquivo para endurecer o gate `analyze` sem introduzir uma engine nova de plugins.
