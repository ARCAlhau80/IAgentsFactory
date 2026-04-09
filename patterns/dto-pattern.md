# 🎯 PATTERN: DTO / Data Transfer Object Template

**Purpose:** Template reutilizável para criar DTOs de request/response  
**Applicable To:** Qualquer API que separa entity de representação externa

---

## 📋 Quick Reference

```
DTO:
├── Request DTO (input) — validação de formato
├── Response DTO (output) — representação para o cliente
├── NÃO é entity do banco
├── NÃO tem lógica de negócio
├── É imutável (idealmente)
└── Pode ter DTOs aninhados para relações
```

---

## 🏗️ Templates por Stack

### Java + Spring Boot (Jakarta Validation)

```java
package [PACKAGE_BASE].dto;

import jakarta.validation.constraints.*;

// ─── REQUEST DTO (Input) ────────────────────

/**
 * DTO de criação/atualização de [Entity].
 * Validação automática com @Valid no controller.
 */
public record [Entity]Request(
    
    @NotBlank(message = "Nome é obrigatório")
    @Size(min = 2, max = 255, message = "Nome deve ter entre 2 e 255 caracteres")
    String nome,
    
    @NotBlank(message = "Email é obrigatório")
    @Email(message = "Email deve ser válido")
    String email,
    
    @NotNull(message = "Status é obrigatório")
    String status,
    
    @Min(value = 0, message = "Valor não pode ser negativo")
    @Max(value = 999999, message = "Valor máximo excedido")
    Integer valor
    
) {}

// ─── RESPONSE DTO (Output) ──────────────────

/**
 * DTO de resposta de [Entity].
 * Não expõe campos sensíveis ou internos.
 */
public record [Entity]Response(
    Long id,
    String nome,
    String email,
    String status,
    LocalDateTime createdAt
) {
    public static [Entity]Response from([Entity] entity) {
        return new [Entity]Response(
            entity.getId(),
            entity.getNome(),
            entity.getEmail(),
            entity.getStatus().name(),
            entity.getCreatedAt()
        );
    }
}
```

### Java (sem records — Java 8/11)

```java
// Para Java < 16 (sem records)
public class [Entity]Request {
    
    @NotBlank(message = "Nome é obrigatório")
    private String nome;
    
    @NotBlank @Email
    private String email;
    
    // Getters (sem setters = imutável após construção)
    public String getNome() { return nome; }
    public String getEmail() { return email; }
}

public class [Entity]Response {
    private final Long id;
    private final String nome;
    private final String email;
    
    public [Entity]Response(Long id, String nome, String email) {
        this.id = id;
        this.nome = nome;
        this.email = email;
    }
    
    // Getters only
    public Long getId() { return id; }
    public String getNome() { return nome; }
    public String getEmail() { return email; }
}
```

### TypeScript

```typescript
// dto/create-[entity].dto.ts
import { IsNotEmpty, IsEmail, IsOptional, MinLength, MaxLength } from 'class-validator';

export class Create[Entity]Dto {
  @IsNotEmpty({ message: 'Nome é obrigatório' })
  @MinLength(2)
  @MaxLength(255)
  nome: string;

  @IsNotEmpty()
  @IsEmail({}, { message: 'Email deve ser válido' })
  email: string;

  @IsOptional()
  status?: string;
}

export class Update[Entity]Dto {
  @IsOptional()
  @MinLength(2)
  nome?: string;

  @IsOptional()
  @IsEmail()
  email?: string;
}

// dto/[entity]-response.dto.ts
export class [Entity]ResponseDto {
  id: string;
  nome: string;
  email: string;
  status: string;
  createdAt: Date;

  static from(entity: [Entity]): [Entity]ResponseDto {
    const dto = new [Entity]ResponseDto();
    dto.id = entity.id;
    dto.nome = entity.nome;
    dto.email = entity.email;
    dto.status = entity.status;
    dto.createdAt = entity.createdAt;
    return dto;
  }
}
```

### Python + Pydantic

```python
# schemas.py
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

class [Entity]Create(BaseModel):
    nome: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    status: Optional[str] = "ACTIVE"

class [Entity]Update(BaseModel):
    nome: Optional[str] = Field(None, min_length=2, max_length=255)
    email: Optional[EmailStr] = None
    status: Optional[str] = None

class [Entity]Response(BaseModel):
    id: int
    nome: str
    email: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
```

---

## 🔄 Mapper Template (Entity ↔ DTO)

### Java (manual ou MapStruct)

```java
// [Entity]Mapper.java
@Component
public class [Entity]Mapper {

    public [Entity] toEntity([Entity]Request request) {
        return new [Entity](request.nome(), request.email());
    }

    public [Entity]Response toResponse([Entity] entity) {
        return [Entity]Response.from(entity);
    }

    public void updateEntity([Entity] entity, [Entity]Request request) {
        entity.setNome(request.nome());
        entity.setEmail(request.email());
    }
}
```

---

## ✅ Boas Práticas

1. ✅ **Request ≠ Response** — DTOs separados para input e output
2. ✅ **Validação no Request DTO** — `@NotBlank`, `@Email`, `@Min`, etc.
3. ✅ **Imutável** — usar `record` (Java 16+) ou fields `final`
4. ✅ **Não expor campos sensíveis** — senha, tokens, IDs internos
5. ✅ **Mensagens de erro claras** — `message = "Email deve ser válido"`
6. ✅ **Update DTO com campos opcionais** — permite partial update

## ❌ Anti-Patterns

1. ❌ **Usar entity como DTO** — expõe estrutura interna do banco
2. ❌ **DTO com lógica** — DTO é apenas dados, lógica vai no service
3. ❌ **Um DTO para tudo** — Request, Response e Update devem ser separados
4. ❌ **Validação no service** — validação de formato vai no DTO, lógica de negócio no service
5. ❌ **Campos sensíveis no Response** — nunca retornar senha, hash, tokens

---

## 🧪 Test Template

```
class [Entity]RequestTest {  // Unit Test

    // Test: válido quando todos os campos corretos
    void shouldBeValid_whenAllFieldsCorrect() { }

    // Test: inválido quando nome vazio
    void shouldBeInvalid_whenNomeBlank() { }

    // Test: inválido quando email mal formatado
    void shouldBeInvalid_whenEmailInvalid() { }
}

class [Entity]ResponseTest {

    // Test: from() converte entity para response corretamente
    void from_shouldMapAllFields_whenEntityValid() { }

    // Test: campos sensíveis não expostos
    void from_shouldNotExposePassword() { }
}
```
