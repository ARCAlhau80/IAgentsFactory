# ⚡ SKILL: Performance Tuning

**Propósito:** Identificar e resolver gargalos de performance  
**Aplicabilidade:** Qualquer aplicação com problemas de latência, memória ou throughput  
**Esforço:** Pontual (dias) a contínuo

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Endpoints lentos (> 500ms para API, > 2s para batch)
- Alto consumo de memória
- Banco de dados sobrecarregado
- Usuários reclamando de lentidão

❌ **NÃO use quando:**
- Código novo sem métricas (otimização prematura)
- Performance é "boa o suficiente" (não otimizar sem motivo)

---

## 🎯 Regra de Ouro

```
"Measure first, optimize second"
 — Nunca otimize sem dados. Medir ANTES e DEPOIS.
```

---

## 📐 Checklist de Performance (por camada)

### 1. Database (80% dos problemas de performance)

```
▶ N+1 QUERIES (problema #1 mais comum)

  ❌ RUIM: (100 queries para listar 100 users com orders)
    users = findAllUsers();          // 1 query
    for (user : users) {
      orders = findOrdersByUser(user.id);  // N queries!
    }

  ✅ BOM: (1-2 queries)
    users = findAllUsersWithOrders();  // JOIN FETCH
    // JPA:  "SELECT u FROM User u JOIN FETCH u.orders"
    // SQL:  "SELECT u.*, o.* FROM users u LEFT JOIN orders o ON u.id = o.user_id"

▶ ÍNDICES

  ❌ RUIM: Query em coluna sem índice em tabela com 1M+ registros
  ✅ BOM: Índice nas colunas usadas em WHERE, JOIN, ORDER BY
  
  -- Verificar queries lentas:
  -- PostgreSQL: EXPLAIN ANALYZE SELECT ...
  -- MySQL:      EXPLAIN SELECT ...
  -- Oracle:     EXPLAIN PLAN FOR SELECT ...

▶ PAGINAÇÃO

  ❌ RUIM: SELECT * FROM orders (retorna 10M registros)
  ✅ BOM: SELECT * FROM orders LIMIT 20 OFFSET 0
  
▶ SELECT APENAS O NECESSÁRIO

  ❌ RUIM: SELECT * FROM users (30 colunas)
  ✅ BOM: SELECT id, nome, email FROM users (3 colunas)
```

### 2. Application

```
▶ CACHE (quando dados não mudam frequentemente)

  Candidatos para cache:
  - Configurações (mudam raramente)
  - Listagens de referência (status, categorias)
  - Resultados de queries complexas
  
  NÃO cachear:
  - Dados que mudam a cada request
  - Dados sensíveis (tokens, senhas)
  - Dados com alta variabilidade

▶ PROCESSAMENTO ASSÍNCRONO

  ❌ RUIM: Enviar email no request (user espera 5s)
  ✅ BOM: Enfileirar email e retornar 202 Accepted

  Candidatos para async:
  - Envio de email/SMS
  - Geração de relatórios
  - Processamento de arquivos
  - Notificações

▶ BATCH PROCESSING

  ❌ RUIM: Inserir 10K registros um por um (10K commits)
  ✅ BOM: Inserir em batches de 50-100 (200 commits)
  
  for (int i = 0; i < items.size(); i++) {
      em.persist(items.get(i));
      if (i % 50 == 0) { em.flush(); em.clear(); }
  }
```

### 3. Infrastructure

```
▶ CONNECTION POOL

  Configurar pool de conexões com banco:
  - Min: 5 (mantém conexões quentes)
  - Max: 20-50 (não sobrecarrega o banco)
  - Timeout: 30s (não esperar eternamente)

▶ COMPRESSÃO

  - Habilitar gzip/brotli nas responses HTTP
  - Reduz bandwidth em 60-80%

▶ TIMEOUT

  - Definir timeout em TODAS as chamadas externas
  - HTTP client: 10-30s
  - Database: 30-60s
  - Nunca timeout infinito
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| N+1 queries | 100+ queries por request | JOIN FETCH / eager loading |
| Sem índice | Query de 30s em tabela grande | CREATE INDEX no WHERE |
| Cache sem invalidação | Dados desatualizados | TTL + invalidação por evento |
| Otimização prematura | Código complexo sem ganho real | Medir primeiro |
| SELECT * | Transferir 30 colunas por linha | Selecionar apenas colunas necessárias |
| Sem paginação | OutOfMemoryError | LIMIT/OFFSET em toda listagem |
| Sem connection pool | Conexão nova a cada request | HikariCP / pgbouncer |
