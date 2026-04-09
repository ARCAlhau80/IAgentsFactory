# 🔒 SKILL: Security Basics (OWASP Top 10)

**Propósito:** Prevenir vulnerabilidades comuns em aplicações web/API  
**Aplicabilidade:** Qualquer aplicação exposta (API, web, mobile backend)  
**Esforço:** Contínuo (deve ser aplicado desde o início)

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Desenvolvendo API pública ou interna
- Recebendo input de usuários
- Autenticando/autorizando usuários
- Armazenando dados sensíveis
- Code review de segurança

❌ **NÃO use quando:**
- Script local de uso único (sem exposição de rede)

---

## 🎯 OWASP Top 10 — Checklist Prático

### 1. Injection (SQL, NoSQL, Command)

```
❌ VULNERÁVEL:
   query = "SELECT * FROM users WHERE id = " + userId;         // SQL Injection
   db.collection.find({ $where: "this.name == '" + name + "'" }) // NoSQL Injection
   exec("ping " + userInput);                                   // Command Injection

✅ SEGURO:
   query = "SELECT * FROM users WHERE id = ?";  params = [userId]  // Parametrizado
   db.collection.find({ name: name })                              // Driver seguro
   // Nunca executar comandos do SO com input do usuário
```

### 2. Broken Authentication

```
✅ OBRIGATÓRIO:
- Senhas: bcrypt/argon2 (NUNCA MD5/SHA1)
- JWT: validar assinatura, expiração, issuer
- Rate limiting: limitar tentativas de login
- MFA: para operações críticas
- Session: invalidar no logout

❌ NUNCA:
- Armazenar senha em texto plano
- JWT sem expiração
- Enviar senha por URL/query string
```

### 3. Broken Access Control

```
✅ OBRIGATÓRIO:
- Verificar permissão em CADA endpoint
- IDOR: verificar se o recurso pertence ao usuário
  if (order.getUserId() != currentUser.getId()) throw new ForbiddenException();
- Default: deny-all (negar tudo, permitir explicitamente)

❌ NUNCA:
- Confiar em IDs do request sem verificar ownership
- Endpoints sem autenticação (exceto /health, /login)
- Admin endpoints sem verificação de role
```

### 4. Security Misconfiguration

```
✅ OBRIGATÓRIO:
- CORS: configurar origens permitidas (nunca *)
- Headers: X-Content-Type-Options, X-Frame-Options
- HTTPS: obrigatório em produção
- Error pages: não expor stack traces em produção
- Credenciais: via environment variables (nunca no código)
```

### 5. Input Validation

```
✅ OBRIGATÓRIO:
- Validar TUDO que vem do usuário (DTO validation)
- Sanitizar HTML (prevenir XSS)
- Limitar tamanho de upload
- Validar Content-Type
- Whitelist > Blacklist

❌ NUNCA:
- Confiar em validação do frontend (sempre validar no backend)
- Aceitar input sem limite de tamanho
```

---

## 📐 Checklist de Segurança por Endpoint

```
Para CADA endpoint, verificar:

[ ] Autenticação? (quem é o usuário?)
[ ] Autorização? (tem permissão?)
[ ] Input validado? (formato, tamanho, tipo)
[ ] Output sanitizado? (sem dados sensíveis)
[ ] Rate limited? (prevenir brute force)
[ ] Logado? (auditoria)
```

---

## 🔑 Senhas & Secrets

```
ARMAZENAMENTO:
- Senha: bcrypt com salt (cost 12+)
- API keys: hash SHA-256 (comparação apenas)
- Tokens: opaco + assinado (JWT RS256 ou ES256)

TRANSMISSÃO:
- HTTPS obrigatório
- Headers (Authorization), nunca query string
- Short-lived tokens (15-60 min)

CÓDIGO:
- .env / secrets manager (nunca hardcoded)
- .gitignore inclui .env, *.key, *.pem
- Rotate periodicamente
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Impacto | Solução |
|-----------|---------|---------|
| SQL por concatenação | Data breach total | Usar queries parametrizadas SEMPRE |
| Senha em MD5/SHA1 | Crackers decifram em minutos | Usar bcrypt/argon2 |
| CORS: `*` | Qualquer site acessa sua API | Listar origens explicitamente |
| Stack trace em produção | Expõe internals do sistema | Error handler genérico |
| JWT sem expiração | Token roubado = acesso eterno | max 1h, refresh token separado |
| Upload sem limite | DoS por arquivo gigante | Limitar tamanho + tipo |
