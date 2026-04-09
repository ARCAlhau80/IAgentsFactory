# 🧩 SKILL: Domain-Driven Design (DDD) Essentials

**Propósito:** Modelar software alinhado ao domínio de negócio  
**Aplicabilidade:** Projetos com lógica de negócio complexa  
**Esforço:** Contínuo (muda a forma de pensar, não só o código)

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Domínio de negócio é complexo (muitas regras)
- Equipe precisa se comunicar com stakeholders
- Vários subdomínios interagem
- Código está virando "big ball of mud"

❌ **NÃO use quando:**
- CRUD simples (sem regras de negócio)
- Projeto pequeño (1-3 entities)
- Prototype / proof of concept

---

## 🎯 Conceitos Essenciais

### 1. Ubiquitous Language (Linguagem Ubíqua)

```
CONCEITO: Usar os MESMOS termos que o negócio usa, no código.

❌ RUIM:
  class DataProcessor { process(data) }     // O que é "data"?
  class RecordHandler { handle(record) }    // O que é "record"?

✅ BOM:
  class OrderService { placeOrder(cart) }   // Negócio fala "place order"
  class InvoiceService { issueInvoice(order) } // Negócio fala "issue invoice"

O termo no código = o termo na reunião = o termo no Jira
```

### 2. Bounded Context (Contexto Delimitado)

```
CONCEITO: Cada subdomínio tem sua própria definição dos mesmos termos.

Exemplo: "User" significa coisas diferentes em cada contexto:

┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  AUTH Context │  │ SALES Context│  │ BILLING Ctx  │
│              │  │              │  │              │
│ User:        │  │ Customer:    │  │ Account:     │
│ - login      │  │ - name       │  │ - balance    │
│ - password   │  │ - address    │  │ - invoices   │
│ - roles      │  │ - orders     │  │ - payments   │
└──────────────┘  └──────────────┘  └──────────────┘

REGRA: Contextos se comunicam por interfaces, nunca acessam DB um do outro.
```

### 3. Entity vs Value Object

```
ENTITY: Tem identidade única. Dois com mesmo conteúdo SÃO diferentes.
  → User (id=1), Order (id=42), Product (id=99)
  → Comparação por ID
  → Mutável (pode mudar de nome)

VALUE OBJECT: Sem identidade. Dois com mesmo conteúdo SÃO iguais.
  → Money(100, "BRL"), Address("Rua A", "SP"), Email("a@b.com")
  → Comparação por todos os campos
  → Imutável (criar novo em vez de alterar)

Código:
  // Entity — equals by ID
  user1 = new User(id=1, name="João")
  user2 = new User(id=1, name="João Atualizado")
  user1.equals(user2) → TRUE (mesmo ID)

  // Value Object — equals by content
  money1 = new Money(100, "BRL")
  money2 = new Money(100, "BRL")
  money1.equals(money2) → TRUE (mesmo valor)
```

### 4. Aggregate (Agregado)

```
CONCEITO: Grupo de entities/VOs que mudam juntas como unidade.

Exemplo: Order é o aggregate root
┌─────────────────────────────┐
│  Order (Aggregate Root)      │
│  ├── OrderItem (entity)      │
│  ├── OrderItem (entity)      │
│  └── ShippingAddress (VO)    │
└─────────────────────────────┘

REGRAS:
1. Acesso externo APENAS pelo aggregate root (Order)
2. Nunca referenciar OrderItem diretamente de fora
3. Transação = 1 aggregate por vez
4. Repository = 1 por aggregate root
```

### 5. Domain Service

```
CONCEITO: Lógica que não pertence a nenhuma entity específica.

❌ ERRADO: Order.transfer(otherOrder) — transferência não é da Order
✅ CORRETO: TransferService.transfer(orderA, orderB) — é do domínio, não da entity
```

---

## 📐 Estrutura Prática

```
src/
├── order/                      # Bounded Context: Orders
│   ├── domain/
│   │   ├── Order.java          # Aggregate Root
│   │   ├── OrderItem.java      # Entity (dentro do aggregate)
│   │   ├── OrderStatus.java    # Value Object (enum)
│   │   ├── Money.java          # Value Object
│   │   ├── OrderRepository.java # Interface (port)
│   │   └── PricingService.java  # Domain Service
│   ├── application/
│   │   ├── PlaceOrderUseCase.java
│   │   └── OrderDTO.java
│   └── infrastructure/
│       ├── JpaOrderRepository.java  # Implementação
│       └── OrderController.java
│
├── billing/                    # Bounded Context: Billing
│   ├── domain/
│   │   ├── Invoice.java        # Aggregate Root (diferente)
│   │   └── ...
│   └── ...
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| DDD em CRUD simples | Over-engineering | Usar DDD só com lógica complexa |
| Anemic Domain Model | Entities sem métodos (só getters/setters) | Mover lógica para dentro da entity |
| Aggregate muito grande | Transaction locks, performance | Menor aggregate possível |
| Sem ubiquitous language | Termos do código ≠ termos do negócio | Alinhar com stakeholders |
| Compartilhar DB entre contexts | Acoplamento forte | Cada context tem seu schema/banco |

---

## 📊 Quando NÃO Usar DDD

```
Complexidade do Domínio:

  Simples (CRUD)    → Não usar DDD. Controller → Service → Repository basta.
  Médio (regras)    → DDD Lite: entities com comportamento + value objects
  Complexo (muitas  → DDD Completo: bounded contexts, aggregates, 
   regras, eventos)    domain events, sagas
```
