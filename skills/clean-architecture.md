# 🏛️ SKILL: Clean Architecture Implementation

**Propósito:** Separar camadas para facilitar testes, manutenção e evolução  
**Aplicabilidade:** Qualquer projeto backend (Java, TypeScript, Python, C#)  
**Esforço:** Gradual — 2-8 semanas dependendo do tamanho

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Código ficou difícil de testar (muitas dependências)
- Lógica de negócio está espalhada (controller, service, repository)
- Quer separar framework do domínio
- Preparando para microserviços

❌ **NÃO use quando:**
- Projeto muito pequeno (1-3 endpoints simples — CRUD puro)
- Apenas adicionando testes (use testing-strategies.md)
- Apenas otimizando performance (use performance-tuning.md)

---

## 🎯 Conceito

```
┌────────────────────────────────────────────────┐
│  PRESENTATION (Controllers, CLI, Events)       │ ← Recebe input
│  Depende de: Application                       │
├────────────────────────────────────────────────┤
│  APPLICATION (Services, Use Cases, DTOs)       │ ← Orquestra
│  Depende de: Domain                            │
├────────────────────────────────────────────────┤
│  DOMAIN (Entities, Value Objects, Rules)       │ ← Lógica pura
│  Depende de: NADA (zero imports externos)      │
├────────────────────────────────────────────────┤
│  INFRASTRUCTURE (Repos, DB, APIs, Files)       │ ← Implementa
│  Depende de: Domain (implementa interfaces)    │
└────────────────────────────────────────────────┘

REGRA DE OURO: Dependências apontam para DENTRO (→ Domain)
               Domain NUNCA depende de nada externo
```

---

## 📐 Estrutura de Pastas

### Por Camada (simples)

```
src/
├── controller/          # Presentation
│   └── UserController
├── service/             # Application
│   └── UserService
├── domain/              # Domain (entities, rules)
│   ├── User
│   └── UserStatus
├── repository/          # Infrastructure
│   └── UserRepository
├── dto/                 # Application (DTOs)
│   ├── UserRequest
│   └── UserResponse
├── mapper/              # Application
│   └── UserMapper
├── exception/           # Domain (exceções de negócio)
│   └── UserNotFoundException
└── config/              # Infrastructure
    └── SecurityConfig
```

### Por Feature/Módulo (avançado — projetos grandes)

```
src/
├── user/
│   ├── controller/
│   │   └── UserController
│   ├── service/
│   │   └── UserService
│   ├── domain/
│   │   └── User
│   ├── repository/
│   │   └── UserRepository
│   ├── dto/
│   │   ├── UserRequest
│   │   └── UserResponse
│   └── exception/
│       └── UserNotFoundException
├── order/
│   ├── controller/
│   ├── service/
│   ├── domain/
│   ├── repository/
│   └── dto/
└── shared/
    ├── exception/
    │   └── GlobalExceptionHandler
    └── config/
```

---

## 📐 Regras de Dependência

```
✅ PERMITIDO:
Controller → Service → Repository
Controller → DTO
Service → Domain Entity
Service → Repository (interface)
Infrastructure → Domain (implementa interface)

❌ PROIBIDO:
Controller → Repository (pular service)
Domain → Infrastructure (inversão!)
Service → Controller (camada de cima)
Repository → Service (camada de cima)
Domain → DTO (domain não conhece DTOs)
```

---

## 🔄 Como Migrar Gradualmente

### Step 1: Extrair DTOs (1-2 dias por endpoint)

```
ANTES: Controller retorna Entity do banco
DEPOIS: Controller retorna DTO (Response)

1. Criar [Entity]Response DTO
2. Criar [Entity]Mapper (entity → response)
3. Service retorna DTO em vez de Entity
4. Controller não muda (já recebia do service)
```

### Step 2: Extrair Exceções de Domínio (1 dia)

```
ANTES: throw new RuntimeException("User not found")
DEPOIS: throw new UserNotFoundException(id)

1. Criar exceções específicas (UserNotFoundException, etc.)
2. Criar GlobalExceptionHandler / error middleware
3. Substituir exceções genéricas pelas específicas
```

### Step 3: Separar Service de Repository (2-3 dias)

```
ANTES: Service acessa banco diretamente
DEPOIS: Service usa Repository interface

1. Criar interface Repository (no domain)
2. Implementar com JPA/TypeORM/SQLAlchemy (infrastructure)
3. Service depende da interface, não da implementação
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| Over-engineering | 50 classes para um CRUD simples | YAGNI — só separar quando necessário |
| Camadas vazias | Service que só delega para repository | Service sem lógica pode ser eliminado |
| Acoplamento via DTO | Domain depende de DTO | Domain tem suas próprias classes |
| Interface prematura | Interface com 1 implementação | Criar interface quando tiver 2+ ou para testing |

---

## 📊 Resultado Esperado

Após aplicar Clean Architecture:
- ✅ Domain testável sem framework (pure unit tests)
- ✅ Trocar banco de dados sem mudar lógica
- ✅ Trocar framework sem mudar domínio
- ✅ Cada camada testável isoladamente
- ✅ Código mais legível (cada arquivo tem 1 responsabilidade)
