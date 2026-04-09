# 📊 PROMPTS: Observability

**Uso:** Adicionar logging estruturado, métricas e tracing ao código  
**Agente:** OBSERVABILITY  
**Aplicabilidade:** Qualquer aplicação em produção

---

## PROMPT #1 — Adicionar Logging Estruturado a Service

**Quando usar:** Instrumentar um service existente com logs de qualidade.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Skills: ver skills/observability.md
- Source: [COLE O CÓDIGO DO SERVICE AQUI]

TAREFA:
Adicionar logging estruturado ao service acima:

1. Log de ENTRADA em cada método público:
   - Nome do método
   - Parâmetros relevantes (sem dados sensíveis)
   - Correlation ID (se disponível)

2. Log de SUCESSO na saída:
   - Resultado resumido (ID criado, contagem retornada)
   - Tempo de execução (opcional)

3. Log de ERRO em catch blocks:
   - Mensagem do erro
   - Stack trace completo
   - Contexto (qual operação falhou, com quais dados)

4. NÍVEIS corretos:
   - DEBUG: detalhes internos, queries
   - INFO: eventos de negócio (criou, atualizou, deletou)
   - WARN: situações recuperáveis (retry, fallback)
   - ERROR: falhas que precisam de ação

REQUISITOS:
- Usar structured logging (key=value ou JSON), NÃO string concatenation
- NÃO logar: senhas, tokens, CPF, dados pessoais
- Correlation ID em TODOS os logs (MDC / AsyncLocalStorage / contextvars)
- Log messages em inglês, snake_case para event names

OUTPUT:
- Código do service com logs adicionados
- Configuração de logging sugerida (logback.xml / winston config / structlog config)
```

---

## PROMPT #2 — Definir Métricas para Componente

**Quando usar:** Instrumentar componente com métricas de negócio e técnicas.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Componente: [NOME DO COMPONENTE]
- Funcionalidade: [O QUE ELE FAZ]

TAREFA:
Definir e implementar métricas para o componente:

1. MÉTRICAS TÉCNICAS:
   - request_duration_seconds (histogram) — latência por endpoint
   - errors_total (counter) — erros por tipo/método
   - active_requests (gauge) — requests em andamento

2. MÉTRICAS DE NEGÓCIO:
   - [entity]_created_total (counter) — entidades criadas
   - [entity]_processed_total (counter) — processamentos concluídos
   - [operacao]_duration_seconds (histogram) — tempo de operações críticas

3. ALERTAS SUGERIDOS:
   - Error rate > 5% nos últimos 5 min
   - P99 latency > 2s
   - [Alerta de negócio específico]

OUTPUT:
- Código instrumentado com métricas
- Dashboard sugerido (Grafana JSON ou descrição dos painéis)
- Alertas recomendados com thresholds
```

---

## PROMPT #3 — Adicionar Correlation ID / Tracing

**Quando usar:** Rastrear requests entre camadas ou serviços.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Arquitetura: [MONOLITO | MICROSERVIÇOS]

TAREFA:
Implementar correlation ID para rastrear requests:

1. GERAR ID: No primeiro ponto de entrada (controller/middleware)
   - Usar X-Correlation-ID do header se existir
   - Gerar UUID se não existir

2. PROPAGAR: Em todas as camadas
   - Controller → Service → Repository
   - Em chamadas HTTP para outros serviços (header)
   - Em mensagens async (payload/header)

3. LOGAR: Em todos os log entries
   - Adicionar ao MDC/context automaticamente
   - Incluir no formato de log (JSON)

4. RETORNAR: Na response
   - Header X-Correlation-ID na response
   - Para que o cliente possa referenciar

OUTPUT:
- Middleware/Filter para gerar e propagar correlation ID
- Configuração de logging para incluir correlation ID
- Exemplo de log output com correlation ID
```

---

## PROMPT #4 — Análise de Logs em Produção

**Quando usar:** Investigar erro ou comportamento inesperado usando logs.

```
CONTEXTO:
- Erro: [DESCREVA O ERRO OU COMPORTAMENTO]
- Correlation ID: [SE DISPONÍVEL]
- Timestamp: [QUANDO OCORREU]
- Logs: [COLE OS LOGS RELEVANTES AQUI]

TAREFA:
Analisar os logs fornecidos e:

1. TIMELINE: Reconstruir a sequência de eventos
2. ROOT CAUSE: Identificar a causa raiz
3. IMPACT: Avaliar o impacto (quantos users, quais dados)
4. FIX: Sugerir correção com código
5. PREVENTION: Como evitar que aconteça novamente

OUTPUT:
## Root Cause Analysis
- **Causa:** [...]
- **Impacto:** [...]
- **Fix:** [código]
- **Prevenção:** [ações]
```

---

## PROMPT #5 — Health Check & Readiness

**Quando usar:** Implementar endpoints de health para monitoramento.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Dependências: [BANCO, CACHE, APIs EXTERNAS]

TAREFA:
Implementar health checks:

1. /health/live (Liveness):
   - Aplicação está rodando? (sempre 200 se responder)
   - Usado pelo Kubernetes para restart

2. /health/ready (Readiness):
   - Banco de dados conectado?
   - Cache conectado?
   - APIs externas acessíveis?
   - Usado pelo K8s para traffic routing

3. /health (geral):
   - Combinação de liveness + readiness
   - Detalhes de cada componente
   - Tempo de resposta de cada check

OUTPUT:
{
  "status": "UP",
  "components": {
    "database": { "status": "UP", "responseTime": "12ms" },
    "cache": { "status": "UP", "responseTime": "2ms" },
    "externalApi": { "status": "DOWN", "error": "timeout" }
  }
}
```
