# 📋 Architecture Decision Records (ADRs)

Esta pasta armazena **decisões arquiteturais** do projeto no formato ADR.

## O Que É um ADR?

Um ADR documenta uma decisão técnica importante, incluindo:
- **Contexto:** Por que a decisão foi necessária
- **Decisão:** O que foi escolhido
- **Alternativas:** O que foi considerado e descartado
- **Consequências:** Impacto positivo e negativo

## Quando Criar um ADR?

- Escolha de framework, banco de dados, linguagem
- Mudança de padrão arquitetural
- Adoção de nova dependência significativa
- Decisão que afeta múltiplos componentes
- Quebra de compatibilidade (breaking change)

## Como Criar

1. Use o prompt em [prompts/documentation.md](../../prompts/documentation.md) (PROMPT #1)
2. Nomeie como `ADR-[NUMBER]-[titulo-kebab-case].md`
3. Exemplo: `ADR-001-escolha-do-banco-de-dados.md`

## Template Rápido

```markdown
# ADR-[NUMBER]: [TÍTULO]

- **Status:** Proposed | Accepted | Deprecated | Superseded
- **Data:** [YYYY-MM-DD]
- **Decisores:** [Nomes]

## Contexto
[Por que essa decisão precisa ser tomada?]

## Decisão
[O que foi decidido?]

## Alternativas Consideradas
| Alternativa | Prós | Contras |
|------------|------|---------|

## Consequências
- ✅ Positivas: [...]
- ⚠️ Negativas: [...]
```
