# 🧪 PROMPTS: Testing

**Uso:** Gerar testes automatizados (unit, integration, E2E)  
**Agente:** QA  
**Aplicabilidade:** Qualquer stack

---

## PROMPT #1 — Gerar Unit Tests para Service

**Quando usar:** Testar lógica de negócio isoladamente (sem banco, sem HTTP).

```
CONTEXTO:
- Stack: [LANGUAGE] + [TEST_FRAMEWORK]
- Skills: ver skills/testing-strategies.md
- Source: [COLE O CÓDIGO DO SERVICE AQUI]

TAREFA:
Gerar testes unitários completos para o service acima:

1. HAPPY PATH: Testar cada método público com input válido
2. EDGE CASES:
   - Input null/vazio
   - Entity não encontrada (throw/return empty)
   - Duplicata (email/nome já existe)
   - Transição de status inválida
3. ERROR PATHS:
   - Repository lança exceção
   - Validação falha
   - Regra de negócio violada

REQUISITOS:
- Mock de TODAS as dependências (repository, mapper, etc.)
- Naming convention: [método]_should[resultado]_when[condição]
- Padrão AAA (Arrange/Act/Assert)
- Verificar chamadas a mocks (verify)
- Um assert por teste (preferencialmente)
- Sem dependência entre testes (cada teste é isolado)

OUTPUT:
- [Entity]ServiceTest com todos os cenários
- Listar cenários cobertos em comentário no início do arquivo
```

---

## PROMPT #2 — Gerar Integration Tests

**Quando usar:** Testar com banco de dados real (H2/SQLite/TestContainers).

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK] + [DATABASE]
- Skills: ver skills/testing-strategies.md
- Source: [COLE O CÓDIGO DO REPOSITORY/CONTROLLER AQUI]

TAREFA:
Gerar testes de integração para:

1. REPOSITORY:
   - save() persiste corretamente
   - findById() retorna entity
   - findAll() com paginação
   - Queries customizadas
   - Constraints (unique, not null)

2. CONTROLLER (se fornecido):
   - GET /entities → 200 + lista paginada
   - GET /entities/:id → 200 ou 404
   - POST /entities → 201 + body
   - PUT /entities/:id → 200 ou 404
   - DELETE /entities/:id → 204 ou 404
   - Validação de input → 400

REQUISITOS:
- Usar banco in-memory ou TestContainers
- @Transactional para rollback entre testes (Java)
- Setup de dados via test fixtures/factories
- Verificar response body e status code
- Testar validation errors (campos obrigatórios)

OUTPUT:
- [Entity]RepositoryIntegrationTest
- [Entity]ControllerIntegrationTest (se aplicável)
- Configuração necessária (application-test.yml, etc.)
```

---

## PROMPT #3 — Gerar Test Data Factory

**Quando usar:** Criar builders/factories para gerar dados de teste reutilizáveis.

```
CONTEXTO:
- Stack: [LANGUAGE]
- Entities: [LISTAR ENTITIES DO PROJETO]

TAREFA:
Gerar uma test data factory/builder para cada entity do projeto:

1. Método com valores DEFAULT válidos (pronto para usar)
2. Métodos builder para customizar campos específicos
3. Método para gerar lista de N entities
4. Relacionamentos preenchidos (lazy → eager nos testes)

EXEMPLO DE USO ESPERADO:
  // Java
  var user = TestDataFactory.aUser().withName("Test").build();
  var users = TestDataFactory.users(10);
  
  // Python
  user = make_user(name="Test")
  users = make_users(10)
  
  // TypeScript
  const user = createTestUser({ name: 'Test' });
  const users = createTestUsers(10);

REQUISITOS:
- Valores padrão SEMPRE válidos (não dão validation error)
- IDs podem ser null (deixar o banco gerar)
- Emails e nomes únicos (usar counter ou UUID)
- Reutilizável entre todos os testes do projeto

OUTPUT:
- TestDataFactory ou função make_* para cada entity
```
