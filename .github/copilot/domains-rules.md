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

## 📋 Checklist Rápido

Antes de fazer merge/commit, verifique:

- [ ] Houve busca local antes de gerar solução nova
- [ ] Toda captura importante foi classificada corretamente
- [ ] A mudança reforça a identidade de produto da factory
- [ ] Sem secrets/credentials no código
- [ ] Sem caminhos absolutos novos sem justificativa

