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

Implementar um fluxo de resolucao progressivo em 4 etapas, priorizando sempre o
conhecimento local antes de qualquer custo externo. A arquitetura real e:

```
[1a] FTS5 keyword search        -> match >= 0.75 -> resposta instantanea (0 tokens, <0.5s)
[1b] Busca vetorial/semantica   -> sim  >= 0.72 -> resposta instantanea (0 tokens, ~1s)
     (Ollama nomic-embed-text gera embedding da query; busca por cosine sim no Hub)
[2]  Ollama generativo          -> resolve?     -> captura no Hub       (0 custo externo)
     (gpt-oss:20b gera resposta nova via HTTP localhost:11434, Windows nativo)
[3]  Provider externo           -> fallback     -> captura no Hub       (custo medido)
     (Claude/GPT, ultimo recurso, sempre capturado para eliminar reuso futuro)
```

### Loop de aprendizado continuo

O principio central e: **o sistema fica mais inteligente e capaz a cada execucao.**

- Camadas 1a e 1b buscam no Hub (conhecimento acumulado)
- Camadas 2 e 3 geram respostas novas E as capturam automaticamente no Hub com embedding
- A cada ciclo, o Hub cresce: proximas consultas similares resolvem via 1a ou 1b
- A proporcao de resolucoes locais aumenta continuamente sem intervencao manual

Todo resultado das camadas 2 e 3 e automaticamente capturado no Knowledge Hub para
eliminar chamadas futuras redundantes.

## Consequências Positivas

- Redução drástica de tokens externos consumidos
- Aprendizado 100% local — nenhum dado sai da máquina sem autorização
- Autonomia: automações agendadas sem intervenção humana
- Subagentes isolados por projeto — contextos não se misturam
- Auto-update do Hermes via `hermes-update.ps1` sem intervenção manual

## Consequências Negativas / Riscos

- Camadas 1b e 2 dependem do Ollama estar rodando (Windows nativo ou WSL)
- Modelo gpt-oss:20b consome ~13 GB de RAM/VRAM na camada 2
- Hub cresce indefinidamente — exige manutencao periodica (`cleanup` command)
- WSL2 requerido apenas para o Hermes Agent CLI opcional (nao para o fluxo principal)

## Mitigacoes

- `hermes-bridge.ps1` detecta Ollama indisponivel e faz fallback silencioso para camada 3
- Flag `$env:HERMES_DISABLED = "1"` pula camada 2 diretamente
- Para ambientes sem Ollama: fluxo opera em 2 camadas (1a/1b hub + externo)
- Para ambientes air-gapped: providers externos desabilitados no config
- `setup-hermes.ps1` valida requisitos antes de instalar (WSL2, RAM, espaco em disco)

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
