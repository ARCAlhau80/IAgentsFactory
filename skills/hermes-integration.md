# Hermes Agent Integration — How-to Guide

## Visao Geral

A integração Hermes adiciona um agente local de IA à IAgentsFactory, criando uma arquitetura de resolução em 3 camadas que elimina dependências de APIs externas pagas para consultas recorrentes:

```
Camada 1 — Knowledge Hub local   (SQLite FTS5, 0 tokens, threshold ≥ 0.75)
          ↓ sem match?
Camada 2 — Hermes + Ollama local (0 custo externo, timeout 90s)
          ↓ sem resposta?
Camada 3 — Provider externo      (Claude/GPT, consumo medido)
```

Resultados das camadas 2 e 3 são capturados automaticamente no Hub, tornando respostas futuras gratuitas.

---

## Instalação

### Pré-requisitos

- Windows 10/11 com WSL2 habilitado
- 8 GB RAM (mínimo), 4+ GB de disco livre
- Node.js instalado
- Acesso à internet (instalação inicial apenas)

### Instalação automática

```powershell
.\setup-hermes.ps1
```

Parâmetros opcionais:
| Parâmetro | Descrição |
|-----------|-----------|
| `-Auto` | Instala sem confirmações interativas |
| `-CheckOnly` | Apenas verifica o ambiente, sem instalar |
| `-Uninstall` | Remove Hermes e configurações |
| `-SkipOllama` | Pula instalação do Ollama |
| `-WslDistro Ubuntu` | Especifica a distro WSL (padrão: Ubuntu) |
| `-OllamaModel llama3.2:3b` | Modelo local a usar |

### O que o setup faz

1. Valida WSL2, RAM, disco e internet
2. Instala Hermes Agent via script oficial
3. Instala Ollama + modelo `llama3.2:3b` no WSL
4. Copia `hermes-config.json` para `~/.iagents-factory/`
5. Desabilita `HERMES_DISABLED` no perfil PowerShell
6. Registra duas tarefas no Task Scheduler:
   - `IAgentsFactory-HermesUpdate` — atualização diária às 06:00
   - `IAgentsFactory-HermesSync` — sincronização de memória às 06:30

---

## Uso

### Consulta básica

```powershell
.\iagents-factory.ps1 ask "como implementar jwt em fastapi"
```

### Consulta com contexto

```powershell
.\iagents-factory.ps1 ask "padrão repository em java" -Domain backend -Language java

.\iagents-factory.ps1 ask "como estruturar testes unitários" -Framework nestjs
```

### Forçar uma camada específica

```powershell
# Sempre usar camada local
.\hermes-bridge.ps1 -Query "..." -ForceLayer 1

# Sempre usar Hermes
.\hermes-bridge.ps1 -Query "..." -ForceLayer 2

# Sempre escalar para externo
.\hermes-bridge.ps1 -Query "..." -ForceLayer 3
```

### Output em JSON (para scripts)

```powershell
.\hermes-bridge.ps1 -Query "..." -JsonOutput
# { "query": "...", "layer_used": 1, "resolved_by": "local-hub", "content": "...", "elapsed_sec": 0.12 }
```

### Simular sem executar

```powershell
.\hermes-bridge.ps1 -Query "..." -DryRun
```

---

## Status e Manutenção

### Verificar status

```powershell
.\iagents-factory.ps1 hermes-status
# ou
.\setup-hermes.ps1 -CheckOnly
```

### Atualizar Hermes manualmente

```powershell
.\iagents-factory.ps1 hermes-update
# ou
.\hermes-update.ps1 -Force
```

### Verificar versão instalada

```powershell
wsl -d Ubuntu -- hermes --version
```

### Sincronizar memória manualmente

```powershell
# Hermes -> Knowledge Hub
.\hermes-sync.ps1 -ToHub

# Knowledge Hub -> contexto Hermes
.\hermes-sync.ps1 -ToHermes

# Bidirecional
.\hermes-sync.ps1
```

### Rollback para versão anterior

```powershell
.\hermes-update.ps1 -Rollback
```

---

## Configuração

O arquivo de configuração fica em: `~/.iagents-factory/hermes-config.json`

Principais configurações:

```json
{
  "hermes": {
    "enabled": true,
    "auto_update": true,
    "backup_before_update": true,
    "update_check_interval_hours": 24
  },
  "resolution_flow": {
    "local_hub_threshold": 0.75,
    "hermes_local_timeout_seconds": 90,
    "auto_capture_hermes_responses": true,
    "auto_capture_external_responses": true
  },
  "local_model": {
    "provider": "ollama",
    "model": "llama3.2:3b"
  }
}
```

Para usar um modelo maior (mais preciso, mais lento):

```json
"local_model": {
  "provider": "ollama",
  "model": "qwen2.5-coder:7b"
}
```

---

## Variáveis de Ambiente

| Variável | Valor | Efeito |
|----------|-------|--------|
| `HERMES_DISABLED` | `1` | Desabilita camada 2 (Hermes), vai direto para externo |
| `HERMES_DISABLED` | `0` | Habilita Hermes normalmente |

Kill switch rápido para depuração:

```powershell
$env:HERMES_DISABLED = "1"
.\iagents-factory.ps1 ask "..."
$env:HERMES_DISABLED = "0"
```

---

## Logs

| Arquivo | Conteúdo |
|---------|----------|
| `~/.iagents-factory/bridge.log` | Fluxo de resolução (camada 1/2/3) |
| `~/.iagents-factory/hermes-sync.log` | Sincronizações de memória |
| `~/.iagents-factory/hermes-update.log` | Histórico de atualizações |

---

## Troubleshooting

### "WSL nao disponivel"
- Verifique se WSL2 está habilitado: `wsl --status`
- Instale WSL2: `wsl --install`
- Reinicie o computador após instalação

### "Hermes nao instalado no WSL"
- Execute: `.\setup-hermes.ps1`
- Se falhar, tente manualmente: `wsl -- bash -c "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"`

### "Hermes timeout (90s)"
- O modelo Ollama pode estar carregando pela primeira vez
- Aguarde e tente novamente; o modelo é cacheado após o primeiro uso
- Para resolver aumentar o timeout: edite `hermes_local_timeout_seconds` em `hermes-config.json`
- Para usar modelo menor/mais rápido: mude para `llama3.2:1b` em `hermes-config.json`

### "Sem match local (camada 1)"
- Normal para consultas novas
- Após a resposta da camada 2 ou 3, a resposta é capturada automaticamente
- Próximas consultas similares resolverão pela camada 1

### "HERMES_DISABLED=1 ignorando Hermes"
- Verifique se a variável não está definida no seu perfil: `$env:HERMES_DISABLED`
- Para resetar: `$env:HERMES_DISABLED = "0"` e atualize o perfil

### Teste manual do Hermes

```powershell
wsl -d Ubuntu -- bash -c 'hermes ask "olá, responda em português" 2>/dev/null'
```

---

## Operação sem WSL2 / Virtualização Indisponível

Ambientes onde a virtualização está **desabilitada** (política corporativa, BIOS sem suporte, VMs aninhadas) não conseguem instalar distros WSL2 — e portanto não executam o Hermes Agent CLI.

O `hermes-bridge.ps1` detecta isso automaticamente e usa **Ollama Windows nativo** como Camada 2, sem depender do WSL.

### Opções disponíveis

| Situação | Camadas ativas | Como configurar |
|----------|---------------|----------------|
| WSL2 indisponível, Ollama Windows instalado | 1 + 2 (nativo) + 3 | `mode: windows-native` no config |
| WSL2 e Ollama ambos indisponíveis | 1 + 3 | `HERMES_DISABLED=1` |
| Máquina air-gapped (sem internet) | 1 + 2 (nativo) | desabilitar providers externos no config |

---

### Opção A — Ollama Windows nativo (recomendado)

> **Pré-requisitos:** Ollama instalado em `C:\...\Ollama\ollama.exe` + pelo menos um modelo baixado.

**1. Instalar Ollama para Windows:**
```
https://ollama.com/download/windows
```

**2. Baixar um modelo local:**
```powershell
# Modelo leve (2 GB, mais rápido)
ollama pull llama3.2:3b

# Modelo robusto (13 GB, mais preciso) — já presente se seguiu o setup
ollama pull gpt-oss:20b
```

**3. Garantir que o config usa modo nativo:**

Em `~/.iagents-factory/hermes-config.json`, ajuste:
```json
"local_model": {
  "provider": "ollama",
  "mode": "windows-native",
  "model": "gpt-oss:20b",
  "ollama_url": "http://localhost:11434"
}
```

**4. Testar:**
```powershell
.\hermes-bridge.ps1 -Query "como criar uma API REST" -ForceLayer 2
```

O bridge acessa `http://localhost:11434` diretamente — sem WSL, sem Hermes CLI.

---

### Opção B — Fluxo 2 camadas (sem Ollama)

Para máquinas sem GPU, com pouca RAM ou onde nenhum modelo local é viável:

```powershell
# Desabilitar Camada 2 permanentemente
$env:HERMES_DISABLED = "1"

# Ou no perfil PowerShell (persistente)
Add-Content $PROFILE "`n`$env:HERMES_DISABLED = '1'"
```

Fluxo resultante:
```
Camada 1 — Knowledge Hub local   (0 tokens, instantaneo)
          ↓ sem match?
Camada 3 — Provider externo       (Claude/GPT, custo medido)
```

Todo resultado da Camada 3 é capturado automaticamente no Hub, tornando futuras consultas gratuitas.

---

### Opção C — Air-gapped (sem internet)

Máquinas isoladas de rede (servidores internos, ambientes de segurança):

```json
"external_providers": [
  { "name": "claude",  "enabled": false },
  { "name": "openai",  "enabled": false }
]
```

Fluxo resultante:
```
Camada 1 — Knowledge Hub local   (0 tokens)
          ↓ sem match?
Camada 2 — Ollama Windows nativo  (0 custo, offline)
          ↓ sem resposta?
[STOP]   — sem fallback externo   (retorna vazio com aviso)
```

Pre-popule o Knowledge Hub com soluções relevantes via seed antes de ir air-gapped:
```powershell
.\iagents-factory.ps1 import --file seeds-export.json
```

---

## Métricas de Economia

O Knowledge Hub registra quais camadas foram usadas:

```powershell
.\iagents-factory.ps1 stats
```

A tabela `hermes_escalations` no SQLite registra todas as vezes que precisou de provider externo. Diminuir esse número é o objetivo:

```sql
SELECT COUNT(*), DATE(escalated_at) as dia
FROM hermes_escalations
GROUP BY dia
ORDER BY dia DESC;
```

---

## Arquitetura dos Componentes

| Arquivo | Função |
|---------|--------|
| `setup-hermes.ps1` | Instalação e validação de ambiente |
| `hermes-bridge.ps1` | Orquestrador das 3 camadas de resolução |
| `hermes-sync.ps1` | Sincronização bidirecional de memória |
| `hermes-update.ps1` | Atualização automática com backup |
| `config/hermes-config.json` | Template de configuração centralizado |
| `docs/decisions/ADR-004-hermes-integration.md` | Decisão arquitetural documentada |

---

## Para Usuários Existentes do IAgentsFactory

Se você já usa o IAgentsFactory e quer adicionar o Hermes:

```powershell
# 1. Atualizar o repositório
git pull

# 2. Instalar Hermes (cerca de 5-15 minutos)
.\setup-hermes.ps1 -Auto

# 3. Verificar
.\iagents-factory.ps1 hermes-status

# 4. Testar
.\iagents-factory.ps1 ask "como criar uma API REST com autenticação JWT"
```

A integração é retrocompatível: se o Hermes não estiver disponível, a factory continua funcionando normalmente com o Knowledge Hub local e provedores externos.
