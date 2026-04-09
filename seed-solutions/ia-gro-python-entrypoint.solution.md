---
domain: automation
pattern: single-entrypoint
language: python
framework: python-tools
agent: factory-seed
quality: 0.82
tags: python, pyproj, visual-studio, entrypoint
---

## Prompt

Documente a caracteristica principal do projeto IA-Gro para fins de registro e reuso na Factory.

## Solution

```text
O IA-Gro aparece como solution do Visual Studio, mas o nucleo executavel esta em um projeto Python (.pyproj).
Esse tipo de repositorio exige heuristica de registro que nao dependa apenas de requirements.txt ou package.json.
Ao detectar .pyproj e StartupFile, a Factory consegue classificar corretamente o projeto como Python e preservar seu contexto de entrada unica.
```

## Summary

Exemplo de projeto Python empacotado em solution do Visual Studio, importante para validar auto-deteccao por .pyproj na Factory.