# 🎯 PATTERN: Service / Business Logic Template

**Purpose:** Template reutilizável para criar services de lógica de negócio  
**Applicable To:** Qualquer aplicação com separação de camadas

---

## 📋 Quick Reference

```
Service:
├── Contém TODA lógica de negócio
├── Orquestra chamadas a repositories/DAOs
├── Lida com transações
├── Faz validações de domínio
├── Lança exceções de negócio
└── NÃO conhece HTTP, CLI, ou framework de apresentação
```

---

## 🏗️ Templates por Stack

### Java + Spring Boot

```java
package [PACKAGE_BASE].service;

import [PACKAGE_BASE].dto.[Entity]Request;
import [PACKAGE_BASE].dto.[Entity]Response;
import [PACKAGE_BASE].entity.[Entity];
import [PACKAGE_BASE].exception.[Entity]NotFoundException;
import [PACKAGE_BASE].mapper.[Entity]Mapper;
import [PACKAGE_BASE].repository.[Entity]Repository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class [Entity]Service {

    private static final Logger log = LoggerFactory.getLogger([Entity]Service.class);

    private final [Entity]Repository repository;
    private final [Entity]Mapper mapper;

    public [Entity]Service([Entity]Repository repository, [Entity]Mapper mapper) {
        this.repository = repository;
        this.mapper = mapper;
    }

    // ─── Query Methods ──────────────────────

    @Transactional(readOnly = true)
    public List<[Entity]Response> findAll(int page, int size) {
        log.debug("Finding all [entities], page={}, size={}", page, size);
        return repository.findAll(PageRequest.of(page, size))
            .map(mapper::toResponse)
            .getContent();
    }

    @Transactional(readOnly = true)
    public [Entity]Response findById(Long id) {
        log.debug("Finding [entity] by id={}", id);
        return repository.findById(id)
            .map(mapper::toResponse)
            .orElseThrow(() -> new [Entity]NotFoundException(id));
    }

    // ─── Command Methods ────────────────────

    @Transactional
    public [Entity]Response create([Entity]Request request) {
        log.info("Creating [entity]: {}", request);
        
        // Validações de negócio
        validateBusinessRules(request);
        
        [Entity] entity = mapper.toEntity(request);
        [Entity] saved = repository.save(entity);
        
        log.info("Created [entity] with id={}", saved.getId());
        return mapper.toResponse(saved);
    }

    @Transactional
    public [Entity]Response update(Long id, [Entity]Request request) {
        log.info("Updating [entity] id={}", id);
        
        [Entity] existing = repository.findById(id)
            .orElseThrow(() -> new [Entity]NotFoundException(id));
        
        validateBusinessRules(request);
        mapper.updateEntity(existing, request);
        
        [Entity] saved = repository.save(existing);
        log.info("Updated [entity] id={}", id);
        return mapper.toResponse(saved);
    }

    @Transactional
    public void delete(Long id) {
        log.info("Deleting [entity] id={}", id);
        
        if (!repository.existsById(id)) {
            throw new [Entity]NotFoundException(id);
        }
        repository.deleteById(id);
        log.info("Deleted [entity] id={}", id);
    }

    // ─── Business Rules ─────────────────────

    private void validateBusinessRules([Entity]Request request) {
        // Regras de negócio que vão além de validação de formato
        // Ex: verificar duplicidade, limites, regras de domínio
    }
}
```

### TypeScript + NestJS

```typescript
// [entity].service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { [Entity] } from './[entity].entity';
import { Create[Entity]Dto, Update[Entity]Dto, [Entity]ResponseDto } from './dto';

@Injectable()
export class [Entity]Service {
  constructor(
    @InjectRepository([Entity])
    private readonly repository: Repository<[Entity]>,
  ) {}

  async findAll(page: number, size: number): Promise<[Entity]ResponseDto[]> {
    const entities = await this.repository.find({
      skip: page * size,
      take: size,
    });
    return entities.map(e => [Entity]ResponseDto.from(e));
  }

  async findById(id: string): Promise<[Entity]ResponseDto> {
    const entity = await this.repository.findOne({ where: { id } });
    if (!entity) throw new NotFoundException(`[Entity] ${id} not found`);
    return [Entity]ResponseDto.from(entity);
  }

  async create(dto: Create[Entity]Dto): Promise<[Entity]ResponseDto> {
    const entity = this.repository.create(dto);
    const saved = await this.repository.save(entity);
    return [Entity]ResponseDto.from(saved);
  }

  async update(id: string, dto: Update[Entity]Dto): Promise<[Entity]ResponseDto> {
    const entity = await this.repository.findOne({ where: { id } });
    if (!entity) throw new NotFoundException(`[Entity] ${id} not found`);
    Object.assign(entity, dto);
    const saved = await this.repository.save(entity);
    return [Entity]ResponseDto.from(saved);
  }

  async delete(id: string): Promise<void> {
    const result = await this.repository.delete(id);
    if (result.affected === 0) throw new NotFoundException(`[Entity] ${id} not found`);
  }
}
```

### Python + FastAPI

```python
# service.py
from typing import List, Optional
from sqlalchemy.orm import Session
from .models import [Entity]
from .schemas import [Entity]Create, [Entity]Update, [Entity]Response
from .exceptions import [Entity]NotFoundError
import logging

logger = logging.getLogger(__name__)

class [Entity]Service:
    def __init__(self, db: Session):
        self.db = db

    def find_all(self, page: int = 0, size: int = 20) -> List[[Entity]Response]:
        entities = self.db.query([Entity]).offset(page * size).limit(size).all()
        return [[Entity]Response.model_validate(e) for e in entities]

    def find_by_id(self, id: int) -> [Entity]Response:
        entity = self.db.query([Entity]).filter([Entity].id == id).first()
        if not entity:
            raise [Entity]NotFoundError(id)
        return [Entity]Response.model_validate(entity)

    def create(self, dto: [Entity]Create) -> [Entity]Response:
        logger.info(f"Creating [entity]: {dto}")
        entity = [Entity](**dto.model_dump())
        self.db.add(entity)
        self.db.commit()
        self.db.refresh(entity)
        return [Entity]Response.model_validate(entity)

    def update(self, id: int, dto: [Entity]Update) -> [Entity]Response:
        entity = self.db.query([Entity]).filter([Entity].id == id).first()
        if not entity:
            raise [Entity]NotFoundError(id)
        for key, value in dto.model_dump(exclude_unset=True).items():
            setattr(entity, key, value)
        self.db.commit()
        return [Entity]Response.model_validate(entity)

    def delete(self, id: int) -> None:
        entity = self.db.query([Entity]).filter([Entity].id == id).first()
        if not entity:
            raise [Entity]NotFoundError(id)
        self.db.delete(entity)
        self.db.commit()
```

---

## ✅ Boas Práticas

1. ✅ **Toda lógica de negócio aqui** — nunca no controller, nunca no repository
2. ✅ **Transações no service** — `@Transactional`, `db.commit()`, etc.
3. ✅ **Logging de operações** — info para writes, debug para reads
4. ✅ **Exceções de domínio** — `[Entity]NotFoundException`, não genéricas
5. ✅ **Receber DTO, retornar DTO** — nunca receber/retornar entity do banco
6. ✅ **Injeção de dependência** — via constructor, nunca field injection

## ❌ Anti-Patterns

1. ❌ **God Service** — uma classe fazendo tudo (dividir por responsabilidade)
2. ❌ **Conhecer HTTP** — retornar ResponseEntity/HttpResponse no service
3. ❌ **Catch-all vazio** — nunca engolir exceção em silêncio
4. ❌ **Acessar banco direto** — sempre via repository/DAO
5. ❌ **Lógica no mapper** — mapper só converte, não processa

---

## 🧪 Test Template

```
class [Entity]ServiceTest {

    // Mocks: repository, mapper

    // Test: findAll retorna lista
    void findAll_shouldReturnList() { }

    // Test: findById encontra
    void findById_shouldReturnEntity_whenExists() { }

    // Test: findById lança exceção quando não existe
    void findById_shouldThrow_whenNotExists() { }

    // Test: create salva e retorna
    void create_shouldSaveAndReturn_whenValid() { }

    // Test: create falha com dados inválidos (regra de negócio)
    void create_shouldThrow_whenBusinessRuleViolated() { }

    // Test: update atualiza existente
    void update_shouldUpdateAndReturn_whenExists() { }

    // Test: delete remove existente
    void delete_shouldRemove_whenExists() { }

    // Test: delete falha quando não existe
    void delete_shouldThrow_whenNotExists() { }
}
```

---

## 📊 Checklist

- [ ] Toda lógica de negócio no service (não no controller/repository)
- [ ] Transações configuradas corretamente
- [ ] Exceções de domínio (não genéricas)
- [ ] Logging em operações de escrita
- [ ] Recebe DTO, retorna DTO (não entity)
- [ ] Testes unitários com mocks de repository
