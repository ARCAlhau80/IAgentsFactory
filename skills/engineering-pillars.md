# 🏛️ SKILL: Engineering Pillars — Checklist de Qualidade

**Propósito:** Garantir que todo projeto gerado pela factory aplique os 4 pilares de engenharia.  
**Aplicabilidade:** Todos os projetos criados com IAgentsFactory  
**Esforço:** Contínuo — aplicar desde o scaffold inicial

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Iniciando um novo projeto (scaffold)
- Revisando código antes de merge/deploy
- Planejando uma nova feature
- Fazendo code review (PR)
- Executando o gate `analyze`

---

## 🔒 Pilar 1 — Security by Design

### Princípio do Menor Privilégio
```
❌ Serviço com admin no banco para operação de leitura
✅ Usuário de banco com SELECT apenas na tabela necessária

❌ Token de API com acesso full a todos os serviços
✅ Token com escopo mínimo (ex: read:orders apenas)
```

### Nunca Confiar na Entrada do Usuário
```
❌ query = "SELECT * FROM users WHERE name = '" + name + "'"
✅ query = "SELECT * FROM users WHERE name = ?", [name]

❌ eval(userInput)
✅ Validar formato, tipo e tamanho antes de qualquer uso
```

### Gestão de Segredos
```
❌ const API_KEY = "sk-abc123..."           # hardcode no código
❌ apiKey: "abc"  no appsettings.json       # commitado no repo

✅ const API_KEY = process.env.API_KEY      # variável de ambiente
✅ Usar .env (não commitado) + .env.example (commitado sem valores)
✅ Em produção: HashiCorp Vault / AWS Secrets Manager / Azure Key Vault
```

### Criptografia
```
✅ HTTPS/TLS obrigatório em produção (nunca HTTP para dados sensíveis)
✅ Senhas: bcrypt (cost >= 12) ou Argon2id — NUNCA MD5/SHA1 sem salt
✅ JWT: validar assinatura + expiração + issuer; usar RS256 em produção
✅ Dados sensíveis em repouso: criptografar campos críticos (PII, cartões)
```

### Checklist de Segurança
- [ ] Sem secrets no código ou em arquivos commitados
- [ ] Inputs externos validados e sanitizados
- [ ] Queries parametrizadas (sem concatenação)
- [ ] CORS configurado com origens explícitas
- [ ] Autenticação e autorização verificadas em cada endpoint
- [ ] Erros genéricos em produção (sem stack trace exposto)
- [ ] Dependências verificadas por vulnerabilidades (npm audit / safety / OWASP Dependency Check)

---

## 🏗️ Pilar 2 — Arquitetura e Design

### SOLID em Prática
```
S — Single Responsibility: cada classe/módulo faz UMA coisa
O — Open/Closed: aberto para extensão, fechado para modificação
L — Liskov Substitution: subclasses podem substituir a base sem quebrar
I — Interface Segregation: interfaces específicas > interfaces gordas
D — Dependency Inversion: depender de abstrações, não de implementações
```

### Clean Architecture — Regras de Dependência
```
Camadas (de fora para dentro):
  [Framework/Drivers] → [Interface Adapters] → [Use Cases] → [Entities]

Regra: dependências apontam SEMPRE para dentro.
Entities NÃO conhecem banco de dados.
Use Cases NÃO conhecem HTTP/REST.
```

### DRY e KISS
```
❌ Lógica de validação de email em 3 lugares diferentes
✅ Uma função validateEmail() importada onde necessário

❌ Pipeline de 12 camadas para "hello world"
✅ Solução mais simples que funciona; complexidade adicionada só quando necessário
```

### Checklist de Arquitetura
- [ ] Regras de negócio no service/use-case (não no controller)
- [ ] Controller/Handler apenas orquestra (sem lógica de domínio)
- [ ] Entity/Model não exposta diretamente na API (usar DTO)
- [ ] Injeção de dependência via constructor (não new direto)
- [ ] Sem dependências circulares entre módulos
- [ ] Lógica duplicada abstraída (DRY aplicado)

---

## 🧪 Pilar 3 — Qualidade do Código

### Nomes Semânticos
```
❌ const d = 86400;
✅ const SECONDS_IN_A_DAY = 86400;

❌ function fn(x, y) { ... }
✅ function calculateOrderTotal(items, discountRate) { ... }

❌ let flag = true;
✅ let isPaymentApproved = true;
```

### Pirâmide de Testes
```
         ▲
        / \        E2E (10%) — Jornada completa do usuário
       /   \       Lento, frágil, caro — usar apenas para fluxos críticos
      /─────\
     /       \     Integration (20%) — Comunicação entre módulos
    / Integr. \    Com banco real, com DI container
   /───────────\
  /             \  Unit (70%) — Lógica isolada
 /    Unit       \ Rápido (<100ms), mock de dependências
/─────────────────\
```

### Code Reviews — O Que Verificar
```
1. Funcionalidade: o código faz o que deveria?
2. Segurança: viola algum dos checks do Pilar 1?
3. Design: viola SOLID ou Clean Architecture?
4. Legibilidade: outro dev entende sem explicação oral?
5. Testes: a lógica nova tem cobertura?
6. Performance: há N+1 queries ou operações O(n²) desnecessárias?
```

### Checklist de Qualidade
- [ ] Variáveis e funções com nomes descritivos
- [ ] Funções com uma responsabilidade (< 30 linhas como diretriz)
- [ ] Testes unitários para toda lógica de negócio
- [ ] Testes de integração para fluxos críticos
- [ ] Logs estruturados (info para sucesso, warn para atenção, error para falha)
- [ ] Sem comentários explicando "o que" (código legível); comentários só para "por que"
- [ ] Code review antes de merge

---

## 🚀 Pilar 4 — DevOps e Observabilidade

### CI/CD Mínimo
```yaml
# Todo projeto deve ter ao menos:
on: [push, pull_request]
jobs:
  validate:
    steps:
      - Checkout
      - Install dependencies
      - Lint / Static analysis
      - Unit tests
      - Build
      - Security scan (dependências)
```

### Logs Estruturados
```
❌ console.log("erro: " + e.message)
✅ logger.error("Order processing failed", { orderId, error: e.message, userId })

Campos obrigatórios em logs de operação:
- timestamp (automático)
- level (info/warn/error)
- service/module
- correlationId (para rastrear request)
- mensagem descritiva
- contexto relevante (IDs, status)
```

### Infraestrutura como Código
```
❌ SSH no servidor e editar manualmente
✅ Toda mudança de infra via PR (Terraform, Ansible, Docker Compose)

❌ Container com estado mutável
✅ Container imutável: destroy + recreate from definition
```

### Health Check (obrigatório em toda API)
```
GET /health → { status: "ok", timestamp: "...", version: "1.0.0" }
GET /health/ready → verifica dependências (DB, cache, serviços externos)
```

### Checklist de DevOps
- [ ] Pipeline CI configurado (`.github/workflows/ci.yml` ou equivalente)
- [ ] Testes executam no CI antes de qualquer merge
- [ ] Health check endpoint implementado
- [ ] Logs estruturados com nível e contexto
- [ ] Configurações via variáveis de ambiente (não hardcode)
- [ ] Infraestrutura definida como código
- [ ] Alertas para falhas críticas em produção

---

## 🎯 Gate de Qualidade — Antes de Publicar no Knowledge Hub

Use este checklist antes do gate `analyze`:

```
SEGURANÇA:
  [ ] Sem secrets hardcoded
  [ ] Inputs validados
  [ ] Queries parametrizadas
  [ ] Autorização verificada

ARQUITETURA:
  [ ] Clean Architecture respeitada
  [ ] Sem duplicação de lógica
  [ ] Dependências injetadas

QUALIDADE:
  [ ] Nomes semânticos
  [ ] Testes unitários presentes
  [ ] Logs estruturados

DEVOPS:
  [ ] CI/CD configurado
  [ ] Health check (se API)
  [ ] Config via env vars
```

Se todos os itens estiverem marcados → **APROVADO para captura e produção**.  
Se qualquer item crítico (segurança) estiver pendente → **BLOQUEADO**.
