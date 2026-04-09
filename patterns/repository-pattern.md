# 🎯 PATTERN: Repository / Data Access Template

**Purpose:** Template reutilizável para criar repositories/DAOs de acesso a dados  
**Applicable To:** Qualquer aplicação com persistência (SQL, NoSQL, arquivos)

---

## 📋 Quick Reference

```
Repository/DAO:
├── Abstrai acesso ao banco de dados
├── CRUD operations (save, find, update, delete)
├── Queries customizadas
├── Batch operations (lote)
├── NÃO contém lógica de negócio
└── NÃO conhece DTOs (trabalha com entities)
```

---

## 🏗️ Templates por Stack

### Java + Spring Data JPA

```java
package [PACKAGE_BASE].repository;

import [PACKAGE_BASE].entity.[Entity];
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface [Entity]Repository extends JpaRepository<[Entity], Long> {

    // ─── Derived Queries (Spring gera automaticamente) ───
    
    Optional<[Entity]> findByEmail(String email);
    
    List<[Entity]> findByStatusOrderByCreatedAtDesc(String status);
    
    boolean existsByEmail(String email);
    
    // ─── Custom Queries (JPQL) ───────────────────────────
    
    @Query("SELECT e FROM [Entity] e WHERE e.status = :status AND e.createdAt >= :since")
    List<[Entity]> findActiveAfterDate(
        @Param("status") String status,
        @Param("since") LocalDateTime since
    );
    
    // ─── Native Queries (SQL) ────────────────────────────
    
    @Query(value = "SELECT * FROM [table] WHERE campo LIKE %:term%", nativeQuery = true)
    List<[Entity]> searchByTerm(@Param("term") String term);
}
```

### Java + DAO Manual (sem Spring Data)

```java
package [PACKAGE_BASE].dao;

import [PACKAGE_BASE].entity.[Entity];
import jakarta.persistence.EntityManager;
import jakarta.persistence.TypedQuery;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Optional;

@Repository
public class [Entity]DAO {

    private final EntityManager em;

    public [Entity]DAO(EntityManager em) {
        this.em = em;
    }

    // ─── CRUD ────────────────────────────────

    @Transactional
    public [Entity] save([Entity] entity) {
        if (entity.getId() == null) {
            em.persist(entity);
            return entity;
        }
        return em.merge(entity);
    }

    public Optional<[Entity]> findById(Long id) {
        return Optional.ofNullable(em.find([Entity].class, id));
    }

    public List<[Entity]> findAll(int page, int size) {
        return em.createQuery("SELECT e FROM [Entity] e ORDER BY e.id", [Entity].class)
            .setFirstResult(page * size)
            .setMaxResults(size)
            .getResultList();
    }

    @Transactional
    public void delete([Entity] entity) {
        em.remove(em.contains(entity) ? entity : em.merge(entity));
    }

    // ─── Custom Queries ──────────────────────

    public List<[Entity]> findByStatus(String status) {
        TypedQuery<[Entity]> query = em.createQuery(
            "SELECT e FROM [Entity] e WHERE e.status = :status", [Entity].class);
        query.setParameter("status", status);
        return query.getResultList();
    }

    // ─── Batch Operations ────────────────────

    @Transactional
    public void saveAll(List<[Entity]> entities) {
        int batchSize = 50;
        for (int i = 0; i < entities.size(); i++) {
            em.persist(entities.get(i));
            if (i > 0 && i % batchSize == 0) {
                em.flush();
                em.clear();
            }
        }
        em.flush();
        em.clear();
    }
}
```

### TypeScript + TypeORM

```typescript
// [entity].repository.ts
import { EntityRepository, Repository } from 'typeorm';
import { [Entity] } from './[entity].entity';

@EntityRepository([Entity])
export class [Entity]Repository extends Repository<[Entity]> {

  async findByEmail(email: string): Promise<[Entity] | null> {
    return this.findOne({ where: { email } });
  }

  async findActiveAfterDate(status: string, since: Date): Promise<[Entity][]> {
    return this.createQueryBuilder('e')
      .where('e.status = :status', { status })
      .andWhere('e.createdAt >= :since', { since })
      .orderBy('e.createdAt', 'DESC')
      .getMany();
  }

  async existsByEmail(email: string): Promise<boolean> {
    const count = await this.count({ where: { email } });
    return count > 0;
  }
}
```

### Python + SQLAlchemy

```python
# repository.py
from typing import List, Optional
from sqlalchemy.orm import Session
from .models import [Entity]

class [Entity]Repository:
    def __init__(self, db: Session):
        self.db = db

    def find_by_id(self, id: int) -> Optional[[Entity]]:
        return self.db.query([Entity]).filter([Entity].id == id).first()

    def find_all(self, page: int = 0, size: int = 20) -> List[[Entity]]:
        return self.db.query([Entity]).offset(page * size).limit(size).all()

    def save(self, entity: [Entity]) -> [Entity]:
        self.db.add(entity)
        self.db.flush()
        return entity

    def delete(self, entity: [Entity]) -> None:
        self.db.delete(entity)

    def find_by_status(self, status: str) -> List[[Entity]]:
        return self.db.query([Entity]).filter([Entity].status == status).all()

    def exists_by_email(self, email: str) -> bool:
        return self.db.query([Entity]).filter([Entity].email == email).count() > 0
```

---

## ✅ Boas Práticas

1. ✅ **Queries parametrizadas** — NUNCA concatenar strings para SQL (prevenir SQL Injection)
2. ✅ **Paginação** — todo `findAll` com `page` e `size`
3. ✅ **Batch operations** — flush/clear a cada N registros para evitar memory leak
4. ✅ **Retornar Optional** (ou null type-safe) para `findById`
5. ✅ **Read-only transactions** para queries de leitura (`readOnly = true`)

## ❌ Anti-Patterns

1. ❌ **SQL por concatenação** — `"SELECT * FROM x WHERE id = " + id` (SQL Injection!)
2. ❌ **Lógica de negócio** — repository apenas acessa dados, não decide
3. ❌ **Retornar DTOs** — repository trabalha com entities, service converte
4. ❌ **N+1 queries** — usar `JOIN FETCH` ou eager loading quando necessário
5. ❌ **Queries sem paginação** — pode derrubar o sistema com tabelas grandes

---

## 🧪 Test Template

```
class [Entity]RepositoryTest {  // Integration Test (com banco real ou H2/SQLite)

    // Test: save persiste
    void save_shouldPersist_whenNewEntity() { }

    // Test: findById encontra
    void findById_shouldReturn_whenExists() { }

    // Test: findById retorna vazio
    void findById_shouldReturnEmpty_whenNotExists() { }

    // Test: findAll com paginação
    void findAll_shouldReturnPage_whenDataExists() { }

    // Test: custom query funciona
    void findByStatus_shouldFilter_whenStatusMatches() { }

    // Test: delete remove
    void delete_shouldRemove_whenExists() { }
}
```

---

## 📊 Checklist

- [ ] Queries parametrizadas (sem concatenação)
- [ ] Paginação em listagens
- [ ] Batch operations para inserções em massa
- [ ] Sem lógica de negócio
- [ ] Testes de integração com banco real (H2, SQLite, TestContainers)
