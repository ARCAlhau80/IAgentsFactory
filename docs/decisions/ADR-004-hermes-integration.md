# ADR-004: Hermes Agent como Runtime Local da IAgentsFactory

**Status:** Aceito  
**Data:** 2026-05-17  
**Autores:** IAgentsFactory Team

---

## Contexto

O IAgentsFactory possui um Knowledge Hub (SQLite + FTS5) funcional para reutilização de
soluções. Porém, quando não há match local, a factory ainda depende de agentes externos
pagos (Copilot, GPT-4o, Claude) — gerando custo de tokens e perda de conhecimento gerado.

O **Hermes Agent** (Nous Research, MIT License) é um agente autônomo open source que:
- Roda localmente no servidor (WSL2 no Windows)
- Possui memória persistente própria
- Suporta modelos locais via Ollama (zero custo por chamada)
- Tem subagentes isolados por projeto
- Suporta automações agendadas em linguagem natural

## Decisão

Integrar o Hermes como **segunda camada de resolução** no fluxo da factory, antes de
qualquer chamada a provider externo pago. A arquitetura de resolução passa a ser:

```
[1] Knowledge Hub local (SQLite)   → match ≥ 75%  → resposta instantânea (0 tokens)
[2] Hermes + modelo local (Ollama)  → resolve?      → captura no Hub    (0 custo)
[3] Provider externo (Claude/GPT)   → fallback      → captura no Hub    (custo medido)
```

Todo resultado das camadas 2 e 3 é automaticamente capturado no Knowledge Hub para
eliminar chamadas futuras redundantes.

## Consequências Positivas

- Redução drástica de tokens externos consumidos
- Aprendizado 100% local — nenhum dado sai da máquina sem autorização
- Autonomia: automações agendadas sem intervenção humana
- Subagentes isolados por projeto — contextos não se misturam
- Auto-update do Hermes via `hermes-update.ps1` sem intervenção manual

## Consequências Negativas / Riscos

- Requer WSL2 no Windows — ambientes sem WSL2 fazem fallback direto para camada 3
- Hermes v0.14.0 ainda em maturação — breaking changes possíveis
- Modelos Ollama locais consomem RAM/GPU — ambientes limitados usam providers remotos

## Mitigações

- `setup-hermes.ps1` valida requisitos antes de instalar (WSL2, RAM, espaço em disco)
- Flag `$env:HERMES_DISABLED = "1"` desativa Hermes e pula direto para camada 3
- `hermes-update.ps1` faz backup da config antes de atualizar
- Todos os erros do Hermes são capturados com fallback silencioso para camada 3

## Componentes criados/modificados

| Arquivo | Tipo | Propósito |
|---------|------|-----------|
| `setup-hermes.ps1` | Novo | Instalação automática com validação de ambiente |
| `hermes-bridge.ps1` | Novo | Orquestrador do fluxo 3 camadas |
| `hermes-sync.ps1` | Novo | Sincroniza memória Hermes → Knowledge Hub |
| `hermes-update.ps1` | Novo | Auto-update Hermes com notificação |
| `config/hermes-config.json` | Novo | Configuração centralizada da integração |
| `skills/hermes-integration.md` | Novo | Skill de uso e troubleshooting |
| `iagents-factory.ps1` | Modificado | Novos comandos: ask, hermes-status, hermes-update |
| `new-project.ps1` | Modificado | Provisiona subagente Hermes no bootstrap |
| Schema SQLite | Modificado | Novas tabelas: hermes_sessions, hermes_memory_index |

## Referências

- https://hermes-agent.nousresearch.com/
- ADR-001: Knowledge Hub Architecture
- ADR-002: IAgentsFactory Repo Split
- ADR-003: Spec Workflow Governance
