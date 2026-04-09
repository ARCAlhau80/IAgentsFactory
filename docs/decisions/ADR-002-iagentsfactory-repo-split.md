# ADR-002: Separar IAgentsFactory do Repositório ISGT

- **Status:** Accepted
- **Data:** 2026-04-09
- **Decisores:** AR CALHAU

## Contexto

O ISGT nasceu como um ADK, centrado em templates, agents, skills e prompts reutilizáveis. A evolução recente adicionou capacidades operacionais que extrapolam um template: Knowledge Hub, captura persistente, search-cross, dashboard, automação multiprojeto e início de geração multi-processo.

Manter tudo sob o nome e o repositório do ISGT mistura dois produtos diferentes:

1. **ISGT** como base conceitual e kit de engenharia.
2. **IAgentsFactory** como produto operacional de orquestração e memória.

## Decisão

Separar a evolução para um novo repositório chamado **IAgentsFactory**, com identidade própria local e no GitHub, inicialmente privado.

## Consequências

### ✅ Positivas
- Clareza de produto: ADK e factory deixam de disputar o mesmo naming.
- Roadmap mais limpo para multi-process generation.
- Possibilidade de governança, issues e versionamento próprios.
- Menor risco de contaminar o ISGT original com decisões de runtime.

### ⚠️ Negativas
- Necessidade de manter referência explícita de origem.
- Duplicação inicial de arquivos enquanto a separação é consolidada.
- Ajustes de documentação, naming e remote Git.

## Diretrizes de Implementação

1. O ISGT permanece como origem conceitual e pode ser baixado novamente do Git quando necessário.
2. O novo produto passa a usar o nome `IAgentsFactory`.
3. Scripts legados podem permanecer temporariamente com nomes antigos quando a troca imediata gerar atrito operacional.
4. Toda documentação nova deve explicitar que a factory é evolução do ADK, mas não o substitui semanticamente.