# 📊 SKILL: Observability (Logging, Metrics, Tracing)

**Propósito:** Implementar logs estruturados, métricas e tracing  
**Aplicabilidade:** Qualquer aplicação que vai para produção  
**Esforço:** 1-2 semanas

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Preparando aplicação para produção
- Debugging é difícil (logs insuficientes)
- Precisa medir performance/throughput
- Precisa rastrear requests entre serviços
- Compliance/auditoria requer logs estruturados

❌ **NÃO use quando:**
- Projeto de estudo/prototype (use `print`/`console.log` e pronto)
- Apenas adicionando testes (use testing-strategies.md)

---

## 🎯 Conceito: 3 Pilares

```
┌─────────────────────────────────────────────┐
│  OBSERVABILITY = Logs + Metrics + Traces    │
└─────────────────────────────────────────────┘

 LOGS (O que aconteceu?)         METRICS (Quanto?)           TRACES (Onde demorou?)
 ├─ Structured JSON              ├─ Counters                 ├─ Request ID
 ├─ Correlation IDs              ├─ Gauges                   ├─ Span context
 ├─ Log levels                   ├─ Histograms               ├─ Timing
 └─ Context (user, request)      └─ Business metrics         └─ Cross-service
```

---

## 📝 PILAR 1: Structured Logging

### Princípios

```
❌ RUIM:  System.out.println("User created");
❌ RUIM:  log.info("Error: " + exception);
❌ RUIM:  console.log("something happened");

✅ BOM:   log.info("User created", Map.of("userId", id, "email", email));
✅ BOM:   logger.info("user_created", extra={"user_id": id, "email": email});
✅ BOM:   logger.info({ msg: 'User created', userId: id, email });
```

### Log Levels

```
TRACE  → Detalhes internos (loops, variáveis internas) — APENAS dev
DEBUG  → Diagnóstico (queries, payloads) — dev/staging
INFO   → Eventos de negócio (user created, order placed) — produção
WARN   → Problemas recuperáveis (retry, fallback) — produção
ERROR  → Falhas que precisam de atenção — produção + alerta
```

### Java (SLF4J + Logback)

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

public class OrderService {
    private static final Logger log = LoggerFactory.getLogger(OrderService.class);

    public Order createOrder(OrderRequest request) {
        MDC.put("correlationId", UUID.randomUUID().toString());
        MDC.put("userId", request.getUserId());
        
        log.info("Creating order for user={}, items={}", 
                 request.getUserId(), request.getItems().size());
        
        try {
            Order order = processOrder(request);
            log.info("Order created successfully, orderId={}, total={}", 
                     order.getId(), order.getTotal());
            return order;
        } catch (Exception e) {
            log.error("Failed to create order for user={}", 
                      request.getUserId(), e);
            throw e;
        } finally {
            MDC.clear();
        }
    }
}
```

### TypeScript (Winston / Pino)

```typescript
import { createLogger, format, transports } from 'winston';

const logger = createLogger({
  level: 'info',
  format: format.combine(format.timestamp(), format.json()),
  transports: [new transports.Console()],
});

class OrderService {
  async createOrder(request: OrderRequest): Promise<Order> {
    const correlationId = randomUUID();
    
    logger.info('Creating order', { 
      correlationId, userId: request.userId, items: request.items.length 
    });

    try {
      const order = await this.processOrder(request);
      logger.info('Order created', { correlationId, orderId: order.id });
      return order;
    } catch (error) {
      logger.error('Failed to create order', { correlationId, error: error.message });
      throw error;
    }
  }
}
```

### Python (structlog)

```python
import structlog

logger = structlog.get_logger()

class OrderService:
    def create_order(self, request: OrderRequest) -> Order:
        log = logger.bind(correlation_id=str(uuid4()), user_id=request.user_id)
        
        log.info("creating_order", items_count=len(request.items))
        
        try:
            order = self._process_order(request)
            log.info("order_created", order_id=order.id, total=order.total)
            return order
        except Exception as e:
            log.error("order_creation_failed", error=str(e))
            raise
```

---

## 📊 PILAR 2: Metrics

### Tipos de Métricas

```
COUNTER   → Conta eventos (requests, errors, orders)
           Só sobe, nunca desce
           Ex: http_requests_total, orders_created_total

GAUGE     → Valor atual (connections, queue size, memory)
           Sobe e desce
           Ex: active_connections, queue_size

HISTOGRAM → Distribuição (latency, response size)
           Buckets de tempo/tamanho
           Ex: request_duration_seconds, response_size_bytes
```

### Métricas Essenciais (qualquer projeto)

```
1. request_duration_seconds   — Latência por endpoint
2. http_requests_total        — Total de requests por status code
3. errors_total               — Erros por tipo
4. active_connections         — Conexões ativas
5. [business]_total           — Métricas de negócio (orders, signups)
```

---

## 🔍 PILAR 3: Tracing

### Correlation ID (mínimo)

Cada request recebe um ID único que aparece em TODOS os logs:

```
Request → Controller → Service → Repository → Response
  │          │            │           │           │
  └── correlationId="abc-123" em todos os logs ──┘

Log output:
  {"correlationId":"abc-123", "msg":"Request received", "path":"/orders"}
  {"correlationId":"abc-123", "msg":"Creating order", "userId":"42"}
  {"correlationId":"abc-123", "msg":"Order saved", "orderId":"99"}
  {"correlationId":"abc-123", "msg":"Response sent", "status":201}
```

---

## ⚠️ O Que NÃO Logar

```
❌ NUNCA logar:
- Senhas, tokens, API keys
- Números de cartão de crédito
- CPF, RG, dados pessoais sensíveis (LGPD/GDPR)
- Conteúdo de arquivos de upload
- Request/response body inteiro (pode ter dados sensíveis)

✅ SEGURO logar:
- IDs (user_id, order_id)
- Timestamps
- Status codes
- Contagens (items_count, não items_content)
- Operações (created, updated, deleted)
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| Log em loop | 1M de linhas por minuto | Logar fora do loop, ou usar sampling |
| String concatenation | `log.info("User " + id)` | Usar placeholders: `log.info("User {}", id)` |
| Logar dados sensíveis | Senhas nos logs | Sanitizar antes de logar |
| Catch sem log | Exceção engolida silenciosamente | Sempre `log.error()` antes de re-throw |
| Log level errado | Tudo em INFO | Usar DEBUG para detalhes, INFO para negócio |
