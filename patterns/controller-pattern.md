# 🎯 PATTERN: Controller / API Endpoint Template

**Purpose:** Template reutilizável para criar controllers/handlers de API  
**Applicable To:** REST APIs, GraphQL resolvers, gRPC services, CLI handlers

---

## 📋 Quick Reference

```
Controller/Handler:
├── Recebe request (HTTP, CLI, event)
├── Valida input (delegando para DTOs/schemas)
├── Delega processamento para Service
├── Formata e retorna response
└── NÃO contém lógica de negócio
```

---

## 🏗️ Templates por Stack

### Java + Spring Boot

```java
package [PACKAGE_BASE].controller;

import [PACKAGE_BASE].dto.[Entity]Request;
import [PACKAGE_BASE].dto.[Entity]Response;
import [PACKAGE_BASE].service.[Entity]Service;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import jakarta.validation.Valid;
import java.util.List;

/**
 * Controller: [Entity]Controller
 * 
 * Endpoints para gerenciar [Entity].
 * Delega toda lógica para [Entity]Service.
 */
@RestController
@RequestMapping("/api/v1/[entities]")
public class [Entity]Controller {

    // ─── Dependencies ───────────────────────
    private final [Entity]Service service;

    public [Entity]Controller([Entity]Service service) {
        this.service = service;
    }

    // ─── CRUD Endpoints ─────────────────────

    @GetMapping
    public ResponseEntity<List<[Entity]Response>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(service.findAll(page, size));
    }

    @GetMapping("/{id}")
    public ResponseEntity<[Entity]Response> findById(@PathVariable Long id) {
        return ResponseEntity.ok(service.findById(id));
    }

    @PostMapping
    public ResponseEntity<[Entity]Response> create(
            @Valid @RequestBody [Entity]Request request) {
        [Entity]Response created = service.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<[Entity]Response> update(
            @PathVariable Long id,
            @Valid @RequestBody [Entity]Request request) {
        return ResponseEntity.ok(service.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

### TypeScript + Express/NestJS

```typescript
// [entity].controller.ts
import { Controller, Get, Post, Put, Delete, Body, Param, Query } from '@nestjs/common';
import { [Entity]Service } from './[entity].service';
import { Create[Entity]Dto, Update[Entity]Dto, [Entity]ResponseDto } from './dto';

@Controller('api/v1/[entities]')
export class [Entity]Controller {
  constructor(private readonly service: [Entity]Service) {}

  @Get()
  async findAll(
    @Query('page') page = 0,
    @Query('size') size = 20,
  ): Promise<[Entity]ResponseDto[]> {
    return this.service.findAll(page, size);
  }

  @Get(':id')
  async findById(@Param('id') id: string): Promise<[Entity]ResponseDto> {
    return this.service.findById(id);
  }

  @Post()
  async create(@Body() dto: Create[Entity]Dto): Promise<[Entity]ResponseDto> {
    return this.service.create(dto);
  }

  @Put(':id')
  async update(
    @Param('id') id: string,
    @Body() dto: Update[Entity]Dto,
  ): Promise<[Entity]ResponseDto> {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  async delete(@Param('id') id: string): Promise<void> {
    return this.service.delete(id);
  }
}
```

### Python + FastAPI

```python
# [entity]_router.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from .schemas import [Entity]Create, [Entity]Update, [Entity]Response
from .service import [Entity]Service

router = APIRouter(prefix="/api/v1/[entities]", tags=["[entities]"])

@router.get("/", response_model=List[[Entity]Response])
async def find_all(
    page: int = 0,
    size: int = 20,
    service: [Entity]Service = Depends()
):
    return service.find_all(page, size)

@router.get("/{id}", response_model=[Entity]Response)
async def find_by_id(id: int, service: [Entity]Service = Depends()):
    return service.find_by_id(id)

@router.post("/", response_model=[Entity]Response, status_code=status.HTTP_201_CREATED)
async def create(dto: [Entity]Create, service: [Entity]Service = Depends()):
    return service.create(dto)

@router.put("/{id}", response_model=[Entity]Response)
async def update(id: int, dto: [Entity]Update, service: [Entity]Service = Depends()):
    return service.update(id, dto)

@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete(id: int, service: [Entity]Service = Depends()):
    service.delete(id)
```

### C# + .NET

```csharp
// [Entity]Controller.cs
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/v1/[entities]")]
public class [Entity]Controller : ControllerBase
{
    private readonly I[Entity]Service _service;

    public [Entity]Controller(I[Entity]Service service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<List<[Entity]Response>>> GetAll(
        [FromQuery] int page = 0, [FromQuery] int size = 20)
        => Ok(await _service.GetAllAsync(page, size));

    [HttpGet("{id}")]
    public async Task<ActionResult<[Entity]Response>> GetById(long id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpPost]
    public async Task<ActionResult<[Entity]Response>> Create([FromBody] [Entity]Request request)
    {
        var created = await _service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<[Entity]Response>> Update(long id, [FromBody] [Entity]Request request)
        => Ok(await _service.UpdateAsync(id, request));

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(long id)
    {
        await _service.DeleteAsync(id);
        return NoContent();
    }
}
```

---

## ✅ Boas Práticas

1. ✅ **Sem lógica de negócio** — Controller apenas delega para Service
2. ✅ **Validação via DTO** — `@Valid`, decorators, ou schemas (nunca manual no controller)
3. ✅ **HTTP status corretos** — 201 Created, 204 No Content, 404 Not Found
4. ✅ **Paginação obrigatória** em endpoints de listagem
5. ✅ **Versionamento na URL** — `/api/v1/`
6. ✅ **Nomes no plural** — `/users`, `/orders`, `/products`

## ❌ Anti-Patterns

1. ❌ **Lógica de negócio no controller** — if/else complexos, cálculos, validações de domínio
2. ❌ **Acessar repository/DAO direto** — sempre passar pelo service
3. ❌ **Retornar entity/model do banco** — sempre converter para DTO/Response
4. ❌ **Endpoint sem validação** — todo input externo DEVE ser validado
5. ❌ **Try-catch genérico** — usar exception handler global / middleware

---

## 🧪 Test Template

```
class [Entity]ControllerTest {

    // Test: GET /api/v1/[entities] - lista com sucesso
    void findAll_shouldReturnList_whenCalled() { }

    // Test: GET /api/v1/[entities]/{id} - encontra por id
    void findById_shouldReturnEntity_whenExists() { }

    // Test: GET /api/v1/[entities]/{id} - 404 quando não existe
    void findById_shouldReturn404_whenNotExists() { }

    // Test: POST /api/v1/[entities] - cria com sucesso
    void create_shouldReturn201_whenValidInput() { }

    // Test: POST /api/v1/[entities] - 400 quando input inválido
    void create_shouldReturn400_whenInvalidInput() { }

    // Test: PUT /api/v1/[entities]/{id} - atualiza com sucesso
    void update_shouldReturn200_whenValidInput() { }

    // Test: DELETE /api/v1/[entities]/{id} - deleta com sucesso
    void delete_shouldReturn204_whenExists() { }
}
```

---

## 📊 Checklist

- [ ] Sem lógica de negócio (apenas delegação)
- [ ] Validação via DTO/Schema
- [ ] HTTP status codes corretos
- [ ] Paginação em listagens
- [ ] Error handling via global handler (não local)
- [ ] Endpoint versionado (/api/v1/)
- [ ] Teste para cada endpoint (happy + error path)
