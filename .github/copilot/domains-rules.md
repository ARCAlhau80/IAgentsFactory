# 🏛️ DOMAIN RULES — IAgentsFactory

**Propósito:** Regras "golden rules" que NÃO podem ser quebradas  
**Escopo:** Projeto inteiro  
**Prioridade:** Máxima — violar qualquer regra aqui é um bug

---

## 🚨 Como Usar Este Arquivo

Cada regra aqui é **inviolável**. A IA (Copilot/Claude/ChatGPT) deve:
1. Verificar contra estas regras ANTES de gerar código
2. Rejeitar sugestões que violem qualquer regra
3. Alertar o desenvolvedor se código existente violar

---

## 🚨 REGRA 1: Knowledge-First Antes de Chamar IA Externa

### Descrição
Toda solução nova deve verificar primeiro se já existe match útil no Knowledge Hub. Isso evita retrabalho, reduz custo e preserva consistência entre projetos.

### ❌ Violação (NUNCA fazer)

```
.
\iagents-factory.ps1 capture
# gerar algo novo sem antes tentar search/search-cross
```

### ✅ Correto (SEMPRE fazer)

```
.
\iagents-factory.ps1 search "auth jwt"
.
\iagents-factory.ps1 search-cross "auth jwt"
# so depois disso decidir por nova geracao
```

### Impacto de Violação
- **Custo:** gasto desnecessário de tokens e tempo.
- **Qualidade:** duplicação de soluções e divergência entre projetos.

---

## 🚨 REGRA 2: Toda Captura Reutilizável Deve Ser Classificada

### Descrição
Nenhuma solução deve entrar na base sem `domain`, `pattern`, `language`, `framework`, `quality` e `tags`. Sem metadados, a factory perde valor operacional.

### ❌ Violação

```
---
domain: general
---

## Solution
<resposta qualquer>
```

### ✅ Correto

```
---
domain: integration
pattern: api-sync
language: csharp
framework: .net 8.0
quality: 0.89
tags: api, retry, sql-server
---
```

### Impacto de Violação
- Busca ruim, falsos matches e degradação da base de conhecimento.

---

## 🚨 REGRA 3: IAgentsFactory é Produto Separado do ISGT Original

### Descrição
ISGT continua sendo o ADK de origem. IAgentsFactory deve ser tratado como produto próprio, com naming, roadmap e decisões orientadas a fábrica multi-processo.

### ❌ Violação

```
Projeto: ISGT
Produto final: ISGT
Objetivo: copiar templates
```

### ✅ Correto

```
Projeto base: ISGT (ADK)
Produto final: IAgentsFactory
Objetivo: orquestracao, knowledge hub, multi-process generation
```

---

<!-- 
EXEMPLOS DE REGRAS COMUNS (copie as relevantes):

## Segurança
- Nunca logar dados sensíveis (CPF, senha, token)
- Nunca construir SQL por concatenação de strings
- Credenciais sempre via variáveis de ambiente
- Todo input externo deve ser validado

## Arquitetura  
- Camada X nunca depende de camada Y diretamente
- Entity/Model nunca exposto na API (usar DTO)
- Lógica de negócio NUNCA no controller/handler
- Um service não pode chamar outro service diretamente (usar events/mediator)

## Dados
- Soft delete obrigatório (nunca DELETE físico)
- Todo registro tem created_at e updated_at
- IDs são UUID, nunca auto-increment exposto
- Paginação obrigatória em listagens

## Qualidade
- Métodos com no máximo [N] linhas
- Complexidade ciclomática máxima: [N]
- Todo branch novo precisa de testes
- Code review obrigatório antes de merge
-->

---

## � REGRA 4: Security by Design em Todo Projeto Gerado

### Descrição
Todo projeto scaffoldado pela factory deve aplicar princípios de segurança desde o início. Segurança não é opcional nem pode ser adicionada depois.

### ❌ Violação

```
API_KEY = "abc123"                          # hardcode de segredo
query = "SELECT * WHERE id = " + userId     # SQL Injection
app.use(cors({ origin: '*' }))              # CORS aberto
```

### ✅ Correto

```
API_KEY = process.env.API_KEY               # variável de ambiente
query = "SELECT * WHERE id = ?", [userId]   # query parametrizada
app.use(cors({ origin: ALLOWED_ORIGINS }))  # origens explícitas
```

### Impacto de Violação
- Vulnerabilidades OWASP Top 10, exposição de dados, comprometimento da aplicação.

---

## 🚨 REGRA 5: Nomes Semânticos e Pirâmide de Testes

### Descrição
Código gerado pela factory deve usar nomes descritivos e incluir estrutura de testes desde a fundação.

### ❌ Violação

```
const d = 86400;
function fn(x) { return x * d; }
// sem arquivos de teste
```

### ✅ Correto

```
const SECONDS_IN_A_DAY = 86400;
function calculateTotalSeconds(days) { return days * SECONDS_IN_A_DAY; }
// + calculateTotalSeconds.test.js
```

### Impacto de Violação
- Código ilegível, difícil de manter, regressões não detectadas.

---

## 🚨 REGRA 6: CI/CD e Observabilidade São Obrigatórios

### Descrição
Todo projeto que vai para produção deve ter pipeline de CI/CD e mecanismos de log/monitoramento. Nenhum projeto pode ir a produção sem saber que está funcionando.

### ❌ Violação
- Sem arquivo `.github/workflows/ci.yml` ou equivalente
- Sem estratégia de logging além de `console.log`
- Deploy manual sem validação automatizada

### ✅ Correto
- Pipeline CI que executa testes antes de qualquer merge
- Logs estruturados com nível (info/warn/error) e contexto
- Health check endpoint em toda API

### Impacto de Violação
- Bugs chegam em produção sem detecção, downtime sem diagnóstico.

---

## 📋 Checklist Rápido

Antes de fazer merge/commit, verifique:

- [ ] Houve busca local antes de gerar solução nova
- [ ] Toda captura importante foi classificada corretamente
- [ ] A mudança reforça a identidade de produto da factory
- [ ] Sem secrets/credentials no código
- [ ] Sem caminhos absolutos novos sem justificativa
- [ ] Input externo validado e sanitizado
- [ ] Nomes de variáveis e funções são descritivos
- [ ] Existe estrutura de teste para a lógica nova
- [ ] Pipeline CI configurado ou atualizado
- [ ] Logs estruturados para operações críticas

