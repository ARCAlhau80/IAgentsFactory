# 🌐 SKILL: API Design Best Practices

**Propósito:** Projetar APIs REST consistentes, intuitivas e escaláveis  
**Aplicabilidade:** Qualquer API REST/RESTful  
**Esforço:** Adotar desde o início (custo zero se feito cedo)

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Criando nova API
- Adicionando endpoints a API existente
- Revisando design de API
- Definindo contrato com frontend/mobile

❌ **NÃO use quando:**
- API puramente interna entre microserviços (considere gRPC)
- GraphQL (padrões diferentes)

---

## 🎯 Convenções de URL

```
✅ CORRETO:
  GET    /api/v1/users              → Lista usuários (paginado)
  GET    /api/v1/users/123          → Busca usuário por ID
  POST   /api/v1/users              → Cria usuário
  PUT    /api/v1/users/123          → Atualiza usuário
  PATCH  /api/v1/users/123          → Atualiza parcialmente
  DELETE /api/v1/users/123          → Remove usuário
  
  GET    /api/v1/users/123/orders   → Ordens do usuário (sub-resource)
  POST   /api/v1/users/123/orders   → Cria ordem para o usuário

❌ ERRADO:
  GET    /api/getUsers              → Verbo na URL
  POST   /api/createUser            → Verbo na URL
  GET    /api/v1/user               → Singular
  DELETE /api/v1/users/delete/123   → Verbo na URL
```

### Regras

```
1. Substantivos no plural:     /users, /orders, /products
2. Sem verbos na URL:          GET /users (não /getUsers)
3. Kebab-case para compostos:  /order-items (não /orderItems)
4. Versionamento na URL:       /api/v1/  (ou header Accept-Version)
5. Hierarquia lógica:          /users/123/orders (não /user-orders?userId=123)
6. Máximo 3 níveis:            /users/123/orders (não /users/123/orders/456/items)
```

---

## 📊 HTTP Status Codes

```
2xx SUCCESS:
  200 OK              ← GET, PUT, PATCH (com body)
  201 Created         ← POST (com Location header)
  204 No Content      ← DELETE (sem body)

4xx CLIENT ERROR:
  400 Bad Request     ← Validação falhou (input inválido)
  401 Unauthorized    ← Não autenticado (falta token)
  403 Forbidden       ← Autenticado mas sem permissão
  404 Not Found       ← Recurso não existe
  409 Conflict        ← Email já cadastrado, duplicata
  422 Unprocessable   ← Input válido mas viola regra de negócio
  429 Too Many Req    ← Rate limit excedido

5xx SERVER ERROR:
  500 Internal Error  ← Bug no servidor (logar + alertar)
  502 Bad Gateway     ← Serviço downstream falhou
  503 Unavailable     ← Manutenção / overload
```

---

## 📐 Formato de Response

### Sucesso (single)

```json
{
  "id": 123,
  "nome": "João",
  "email": "joao@email.com",
  "status": "ACTIVE",
  "createdAt": "2026-03-16T10:30:00Z"
}
```

### Sucesso (lista paginada)

```json
{
  "content": [
    { "id": 1, "nome": "João" },
    { "id": 2, "nome": "Maria" }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 150,
  "totalPages": 8
}
```

### Erro

```json
{
  "error": "VALIDATION_ERROR",
  "message": "Dados de entrada inválidos",
  "details": [
    { "field": "email", "message": "Email deve ser válido" },
    { "field": "nome", "message": "Nome é obrigatório" }
  ],
  "timestamp": "2026-03-16T10:30:00Z",
  "path": "/api/v1/users"
}
```

---

## 🔍 Query Parameters

```
Paginação:    ?page=0&size=20
Ordenação:    ?sort=createdAt,desc
Filtros:      ?status=ACTIVE&city=SP
Busca:        ?search=joão
Campos:       ?fields=id,nome,email (sparse fieldsets)

Exemplo completo:
GET /api/v1/users?status=ACTIVE&sort=nome,asc&page=0&size=20
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Exemplo | Solução |
|-----------|---------|---------|
| Verbos na URL | POST /createUser | POST /users |
| Singular | /user/123 | /users/123 |
| Status errado | 200 para criação | 201 Created |
| Sem paginação | GET /users retorna 10M registros | Paginação obrigatória |
| Erro sem estrutura | `"algo deu errado"` | JSON com error code + details |
| ID sequencial exposto | /users/1, /users/2 | Usar UUID se segurança importa |
