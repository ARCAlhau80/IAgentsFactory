# 🧪 SKILL: Testing Strategies (Unit, Integration, E2E)

**Propósito:** Implementar cobertura de testes em 3 níveis  
**Aplicabilidade:** Qualquer projeto (Java, TypeScript, Python, C#, Go)  
**Esforço:** 1-4 semanas (dependendo do tamanho do projeto)

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Adicionando testes a código novo ou existente
- Definindo estratégia de testes para o projeto
- Criando test fixtures e helpers
- Configurando CI/CD com test execution
- Validando refactoring (regressão)

❌ **NÃO use quando:**
- Apenas refatorando (use clean-architecture.md)
- Otimizando queries (use performance-tuning.md)
- Adicionando logs (use observability.md)

---

## 🎯 Pirâmide de Testes

```
         ▲
        ╱ ╲
       ╱   ╲        E2E Tests (10%)
      ╱─────╲       - Full flow (API → DB → Response)
     ╱       ╲      - Lento, caro, frágil
    ╱─────────╲     - Testa integração real
   ╱  E2E      ╲
  ╱_____________╲
  
      ▲
     ╱│╲
    ╱ │ ╲     Integration Tests (20%)
   ╱  │  ╲   - Com banco real (H2, SQLite, TestContainers)
  ╱───┼───╲  - Com Spring context / DI container
 ╱Integration╲ - Médio: 1-5 segundos
╱─────────────╲

       ▲
      ╱│╲
     ╱ │ ╲   Unit Tests (70%)
    ╱  │  ╲  - Sem dependências externas
   ╱───┼───╲ - Mock everything
  ╱  Unit   ╲ - Rápido: < 100ms
 ╱___________╲
```

---

## 📐 Decision Matrix

| Componente | Test Type | Por quê | Framework |
|------------|-----------|---------|-----------|
| **Service** (lógica pura) | Unit | Sem deps externas, mock repository | Mockito/Jest/pytest |
| **Service** (com DI) | Integration | Precisa container | @SpringBootTest/supertest |
| **Repository/DAO** | Integration | Precisa banco real | H2/SQLite/TestContainers |
| **Controller/Handler** | Unit + Integration | Testar roteamento + validação | MockMvc/supertest |
| **Entity/Model** | Unit | POJO, sem deps | JUnit/Jest/pytest |
| **DTO/Schema** | Unit | Validação de campos | JUnit/Jest/pytest |
| **Utility/Helper** | Unit | Funções puras | JUnit/Jest/pytest |
| **Full Workflow** | E2E | Ponta a ponta | TestContainers/Playwright |

---

## 🏗️ Estrutura de Teste

### Naming Convention (Given-When-Then)

```
// Formato: [método]_should[resultado]_when[condição]

void findById_shouldReturnUser_whenUserExists() { }
void findById_shouldThrowNotFound_whenUserDoesNotExist() { }
void create_shouldPersist_whenValidInput() { }
void create_shouldThrowValidation_whenEmailInvalid() { }
void delete_shouldRemove_whenUserExists() { }
```

### Test Structure (AAA / Given-When-Then)

```
void testMethod() {
    // ARRANGE (Given) — preparar dados e mocks
    var input = new Request("test");
    when(repository.findById(1L)).thenReturn(Optional.of(entity));

    // ACT (When) — executar a ação
    var result = service.findById(1L);

    // ASSERT (Then) — verificar resultado
    assertNotNull(result);
    assertEquals("test", result.getName());
    verify(repository).findById(1L);
}
```

---

## 📐 Templates por Stack

### Java (JUnit 5 + Mockito)

```java
// Unit Test
@ExtendWith(MockitoExtension.class)
class [Entity]ServiceTest {

    @Mock private [Entity]Repository repository;
    @Mock private [Entity]Mapper mapper;
    @InjectMocks private [Entity]Service service;

    @Test
    void findById_shouldReturnResponse_whenExists() {
        // Arrange
        var entity = new [Entity]("Test", "test@email.com");
        var response = new [Entity]Response(1L, "Test", "test@email.com");
        when(repository.findById(1L)).thenReturn(Optional.of(entity));
        when(mapper.toResponse(entity)).thenReturn(response);

        // Act
        var result = service.findById(1L);

        // Assert
        assertNotNull(result);
        assertEquals("Test", result.nome());
        verify(repository).findById(1L);
    }

    @Test
    void findById_shouldThrow_whenNotExists() {
        when(repository.findById(1L)).thenReturn(Optional.empty());

        assertThrows([Entity]NotFoundException.class, 
            () -> service.findById(1L));
    }
}
```

```java
// Integration Test
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class [Entity]RepositoryIntegrationTest {

    @Autowired private [Entity]Repository repository;
    @Autowired private EntityManager em;

    @Test
    void save_shouldPersist_whenNewEntity() {
        var entity = new [Entity]("Test", "test@email.com");
        var saved = repository.save(entity);
        em.flush();
        
        assertNotNull(saved.getId());
        assertEquals("Test", saved.getNome());
    }
}
```

### TypeScript (Jest)

```typescript
// Unit Test
describe('[Entity]Service', () => {
  let service: [Entity]Service;
  let repository: jest.Mocked<Repository<[Entity]>>;

  beforeEach(() => {
    repository = { findOne: jest.fn(), save: jest.fn(), delete: jest.fn() } as any;
    service = new [Entity]Service(repository);
  });

  it('should return entity when found', async () => {
    const entity = { id: '1', nome: 'Test' };
    repository.findOne.mockResolvedValue(entity as any);

    const result = await service.findById('1');

    expect(result).toBeDefined();
    expect(result.nome).toBe('Test');
  });

  it('should throw when not found', async () => {
    repository.findOne.mockResolvedValue(null);

    await expect(service.findById('1')).rejects.toThrow(NotFoundException);
  });
});
```

### Python (pytest)

```python
# test_service.py
import pytest
from unittest.mock import Mock, MagicMock
from .service import [Entity]Service
from .exceptions import [Entity]NotFoundError

class TestEntityService:
    def setup_method(self):
        self.db = MagicMock()
        self.service = [Entity]Service(self.db)

    def test_find_by_id_returns_entity_when_exists(self):
        entity = Mock(id=1, nome="Test", email="test@email.com")
        self.db.query.return_value.filter.return_value.first.return_value = entity

        result = self.service.find_by_id(1)

        assert result is not None
        assert result.nome == "Test"

    def test_find_by_id_raises_when_not_exists(self):
        self.db.query.return_value.filter.return_value.first.return_value = None

        with pytest.raises([Entity]NotFoundError):
            self.service.find_by_id(1)
```

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| Mockar demais (DAO test com mock) | 1% coverage real | Usar integration test com banco H2/SQLite |
| Testar implementação (não comportamento) | Testes quebram em refactoring | Testar input → output, não chamadas internas |
| Sem test data builder | Setup gigante em cada teste | Criar factory de test data |
| Teste sem assert | Teste "verde" que não verifica nada | Sempre ter pelo menos 1 assert |
| Testes acoplados | Ordem de execução importa | Cada teste é independente |

---

## 📊 Coverage Targets

| Nível | Target | Componentes |
|-------|--------|-------------|
| **Mínimo** | 40% | Services + core logic |
| **Bom** | 60% | + Repositories + Controllers |
| **Excelente** | 80%+ | + Edge cases + Error paths |

**Meta realista para começar:** 40% em services + lógica de negócio. Depois expandir.
