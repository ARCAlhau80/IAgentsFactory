# 💻 PROMPTS: Code Generation

**Uso:** Gerar código novo (controllers, services, repositories, entities, DTOs)  
**Agente:** BACKEND  
**Aplicabilidade:** Qualquer stack (Java, TypeScript, Python, C#)

---

## PROMPT #1 — Gerar Controller/Endpoint Completo

**Quando usar:** Criar um novo endpoint REST com validação, error handling e documentação.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Padrões: ver patterns/controller-pattern.md
- Standards: ver .github/copilot/coding-standards.md

TAREFA:
Gerar um controller REST completo para a entidade [ENTITY_NAME] com:
1. CRUD completo (GET, GET by ID, POST, PUT, DELETE)
2. Paginação no GET (lista)
3. Validação de input (DTO com anotações)
4. Error handling (404, 400, 409)
5. Logs estruturados em cada operação

REQUISITOS:
- Seguir naming convention do projeto
- Usar DTOs separados para Request e Response
- Injetar service (DI), nunca repository direto
- Retornar status codes corretos (201, 204, etc.)
- Adicionar comentários apenas onde a lógica não é óbvia

OUTPUT:
- [Entity]Controller (com todos os endpoints)
- [Entity]Request (DTO de entrada com validações)
- [Entity]Response (DTO de saída)
```

---

## PROMPT #2 — Gerar Service com Lógica de Negócio

**Quando usar:** Criar service com regras de negócio específicas.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Padrões: ver patterns/service-pattern.md
- Entidade: [ENTITY_NAME] com campos: [LISTA_DE_CAMPOS]

TAREFA:
Gerar um service para [ENTITY_NAME] que implementa:
1. CRUD básico (create, findById, findAll, update, delete)
2. Regras de negócio:
   - [REGRA_1: ex: "não permitir duplicata por email"]
   - [REGRA_2: ex: "status só pode mudar de DRAFT para ACTIVE"]
   - [REGRA_3: ex: "calcular total baseado nos itens"]
3. Validações de domínio (além da validação de DTO)
4. Logging estruturado (info para sucesso, error para falha)

REQUISITOS:
- Usar repository interface (injeção por constructor)
- Lançar exceções específicas (não RuntimeException genérica)
- Cada método public tem log de entrada e saída
- Transactional onde necessário
- Testável (sem static, sem new direto de dependências)

OUTPUT:
- [Entity]Service (com toda a lógica)
- [Entity]NotFoundException (exceção específica)
- Sugerir testes unitários para cada método
```

---

## PROMPT #3 — Gerar Repository/DAO

**Quando usar:** Criar acesso a dados com queries customizadas.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK] + [DATABASE]
- Padrões: ver patterns/repository-pattern.md
- Entidade: [ENTITY_NAME]
- Tabela: [TABLE_NAME]

TAREFA:
Gerar repository para [ENTITY_NAME] com:
1. CRUD padrão (save, findById, findAll, delete)
2. Queries customizadas:
   - [QUERY_1: ex: "buscar por email"]
   - [QUERY_2: ex: "listar por status com paginação"]
   - [QUERY_3: ex: "buscar por período de data"]
3. Paginação e ordenação
4. Batch operations (se aplicável)

REQUISITOS:
- Queries parametrizadas (NUNCA concatenar strings)
- Paginação em toda listagem
- Índices sugeridos para queries de busca
- Evitar N+1 (JOIN FETCH quando necessário)

OUTPUT:
- [Entity]Repository (interface + implementação se necessário)
- Script SQL com índices sugeridos
```

---

## PROMPT #4 — Gerar Entity/Model Completa

**Quando usar:** Criar entidade de domínio com mapeamento para banco.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Padrões: ver patterns/entity-pattern.md
- Tabela: [TABLE_NAME]

TAREFA:
Gerar entity para a tabela [TABLE_NAME] com:
1. Campos:
   [CAMPO_1]: [TIPO] (obrigatório/opcional)
   [CAMPO_2]: [TIPO] (obrigatório/opcional)
   ...
2. Audit fields (createdAt, updatedAt, createdBy)
3. Relacionamentos:
   - [REL_1: ex: "ManyToOne com Department"]
   - [REL_2: ex: "OneToMany com OrderItem"]
4. Enums para campos de status/tipo
5. Constraints (unique, not null, check)

REQUISITOS:
- equals/hashCode por ID de negócio (não por PK auto-gerada)
- toString sem lazy-loaded relationships
- Validações a nível de entity (Bean Validation)
- Imutabilidade onde possível (Value Objects)

OUTPUT:
- [Entity] completa com mapeamento
- [Entity]Status enum (se aplicável)
- Script SQL CREATE TABLE + índices
```

---

## PROMPT #5 — Gerar Módulo Completo (Full Stack)

**Quando usar:** Gerar todas as camadas de uma feature de uma vez.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK] + [DATABASE]
- Padrões: ver patterns/ (todos)
- Standards: ver .github/copilot/coding-standards.md

TAREFA:
Gerar módulo completo para a entidade [ENTITY_NAME]:

1. ENTITY: [ENTITY_NAME] com campos [...], relationships [...]
2. REPOSITORY: CRUD + queries customizadas [...]
3. SERVICE: lógica de negócio + regras [...]
4. CONTROLLER: REST endpoints CRUD + filtros
5. DTOs: Request (com validação) + Response
6. MAPPER: Entity ↔ DTO
7. EXCEPTIONS: [Entity]NotFoundException, [Entity]DuplicateException
8. TESTS: Unit test para service (mock repo) + sugestions para integration

REQUISITOS:
- Cada camada em arquivo separado
- Seguir padrões do projeto (patterns/)
- Código compilável e pronto para usar
- Sem over-engineering (mínimo necessário)

OUTPUT:
Listar cada arquivo com path completo e conteúdo.
```
