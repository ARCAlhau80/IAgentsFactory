# Extensions

Extensions adicionam exigencias extras ao gate `analyze`.

O modelo atual e propositalmente simples: `specs/extensions/extensions.json` declara artefatos obrigatorios e secoes obrigatorias adicionais por arquivo.

## Exemplo de uso

```json
{
  "extensions": [
    {
      "id": "security-gate",
      "enabled": true,
      "requiredArtifacts": ["security.md"],
      "requiredSections": {
        "plan.md": ["## Security Notes"]
      }
    }
  ]
}
```

Com isso, o gate passa a cobrar `security.md` e a secao adicional no `plan.md`.
