# 🤖 PROMPT: [CATEGORY — ex: Code Generation, Testing, Refactoring]

**Purpose:** [O que estes prompts fazem]  
**Target:** Usar com Copilot / Claude / ChatGPT

---

## 📋 Quando Usar

```
User: "[SITUAÇÃO QUE DISPARA O USO]"
┌─ Load copilot-instructions.md (automático)
├─ Load [PATTERN_RELEVANTE]
└─ Use: PROMPT abaixo
```

---

## 🎯 PROMPT #1: [NOME DA TAREFA]

### Use Este Prompt:

```
Context: I'm working on [PROJECT_NAME], a [PROJECT_DESC].

Task: [O QUE PRECISA SER FEITO]

Requirements:
  1. [REQUISITO_1]
  2. [REQUISITO_2]
  3. [REQUISITO_3]

Constraints:
  - Follow coding-standards.md conventions
  - Follow domains-rules.md rules
  - [CONSTRAINT_ADICIONAL]

Output:
  - [O QUE ESPERO RECEBER]
  - [FORMATO]
```

### Exemplo:

```
Context: I'm working on OrderAPI, a REST API for e-commerce.

Task: Generate a new Service for processing refunds.

Requirements:
  1. Name: RefundService
  2. Methods: processRefund(), calculateRefundAmount(), validateRefundEligibility()
  3. Dependencies: OrderRepository, PaymentGateway, NotificationService

Output:
  - Complete service class
  - Unit test skeleton
```

---

## 🎯 PROMPT #2: [NOME DA TAREFA]

### Use Este Prompt:

```
Context: [CONTEXTO]

Task: [TAREFA]

Requirements:
  1. [REQ_1]
  2. [REQ_2]

Output:
  - [OUTPUT_ESPERADO]
```

---

<!-- 
DICA: Bons prompts têm:
1. Context (qual projeto, qual stack)
2. Task (o que fazer, específico)
3. Requirements (requisitos detalhados)
4. Constraints (regras a seguir)
5. Output (formato esperado)

Maus prompts:
- "Gere código" (vago)
- "Faça um service" (sem contexto)
- "Crie testes" (sem dizer para quê)
-->
