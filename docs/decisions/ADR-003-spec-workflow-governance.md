# ADR-003: Fluxo SPEC leve como governanca nativa da IAgentsFactory

- **Status:** Accepted
- **Data:** 2026-04-09
- **Decisores:** AR CALHAU, GitHub Copilot

## Contexto

O produto ja possuia memory-first, capture pipeline, search, dashboard e operacao multiprojeto. Faltava uma camada minima e nativa de governanca para reduzir ambiguidade antes da implementacao, sem importar toda a complexidade do `github/spec-kit`.

Tambem havia uma oportunidade clara de transformar nao apenas codigo final, mas tambem `spec`, `plan` e `tasks` em memoria reutilizavel da fabrica.

## Decisao

Adotar um fluxo leve `constitution -> specify -> plan -> tasks -> analyze` dentro da propria IAgentsFactory, com as seguintes regras:

1. `constitution` define principios e foco do projeto.
2. `specify` cria a feature em `specs/NNN-feature/`.
3. `plan` gera contexto tecnico e artefatos auxiliares.
4. `tasks` cria checklist executavel e tenta publicar artefatos no Knowledge Hub.
5. `analyze` atua como gate minimo antes de implementar ou capturar.
6. `presets` sobrescrevem templates sem alterar o core.
7. `extensions` endurecem o gate com regras extras sem criar uma engine complexa de plugins.

## Alternativas Consideradas

| Alternativa | Prós | Contras |
|------------|------|---------|
| Adotar `github/spec-kit` integralmente | Fluxo completo e maduro | Escopo maior que o necessario, mais acoplamento conceitual externo |
| Continuar apenas com search/capture | Simples, sem novos artefatos | Mantem baixa disciplina antes da implementacao |
| Criar engine completa de plugins | Alta extensibilidade | Complexidade acidental desnecessaria para o momento |

## Consequencias

- ✅ Positivas:
  - governanca leve e reutilizavel embutida na factory
  - specs, planos e tarefas passam a virar memoria do produto
  - menor ambiguidade antes de implementar ou capturar
  - customizacao por preset/extension sem reescrever o core
- ⚠️ Negativas:
  - mais artefatos para manter por feature
  - exige disciplina minima da equipe para usar o gate corretamente

## Impacto Operacional

- O comando `capture` passa a bloquear captura da feature ativa quando o gate falha, exceto com `-Force`.
- O `search` passa a cobrir tambem os artefatos `workflow-spec`, `workflow-plan` e `workflow-tasks`.
- O repositório passa a distribuir a pasta `specs/` como parte oficial do produto.