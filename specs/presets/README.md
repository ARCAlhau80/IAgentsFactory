# Presets

Presets permitem customizar os templates do workflow sem alterar o core do bootstrap da factory.

## Como funciona

1. Crie um diretorio `specs/presets/<preset-id>/templates/`.
2. Copie apenas os templates que deseja sobrescrever.
3. Ative o preset em `specs/presets/active-preset.json`.

## Exemplo

```text
specs/presets/compliance/templates/spec-template.md
specs/presets/compliance/templates/plan-template.md
```

Quando um preset esta ativo, a factory resolve os templates primeiro nele e depois faz fallback para `specs/templates/`.
