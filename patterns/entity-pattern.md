# 🎯 PATTERN: Entity / Domain Model Template

**Purpose:** Template reutilizável para criar entities/models de domínio  
**Applicable To:** Qualquer aplicação com persistência (ORM, ODM)

---

## 📋 Quick Reference

```
Entity/Model:
├── Representa uma tabela/coleção do banco
├── Define campos e relacionamentos
├── Possui validações de formato (@Column, constraints)
├── Implementa equals/hashCode corretamente
├── Pode ter lógica de domínio SIMPLES (status transitions)
└── NÃO contém lógica de serviço ou acesso a dados
```

---

## 🏗️ Templates por Stack

### Java + JPA/Hibernate

```java
package [PACKAGE_BASE].entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * Entity: [Entity]
 * Table: [TABLE_NAME]
 */
@Entity
@Table(name = "[table_name]")
public class [Entity] {

    // ─── Primary Key ────────────────────────
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ─── Fields ─────────────────────────────

    @Column(nullable = false, length = 255)
    private String nome;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private Status status = Status.ACTIVE;

    // ─── Audit Fields ───────────────────────

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // ─── Relationships ──────────────────────

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    private ParentEntity parent;

    @OneToMany(mappedBy = "[entity]", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ChildEntity> children = new ArrayList<>();

    // ─── Lifecycle Callbacks ────────────────

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    // ─── Constructors ───────────────────────

    protected [Entity]() { } // JPA requires no-arg

    public [Entity](String nome, String email) {
        this.nome = nome;
        this.email = email;
    }

    // ─── Domain Methods (optional) ──────────

    public void deactivate() {
        this.status = Status.INACTIVE;
    }

    public boolean isActive() {
        return this.status == Status.ACTIVE;
    }

    // ─── equals / hashCode (BY ID!) ─────────
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        [Entity] that = ([Entity]) o;
        return id != null && Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return getClass().hashCode(); // Consistent for JPA
    }

    // ─── Getters & Setters ──────────────────
    // Use Lombok @Getter @Setter se disponível, ou gere manualmente
    
    public Long getId() { return id; }
    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public Status getStatus() { return status; }
}

enum Status {
    ACTIVE, INACTIVE, SUSPENDED
}
```

### TypeScript + TypeORM

```typescript
// [entity].entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, 
         UpdateDateColumn, ManyToOne, OneToMany } from 'typeorm';

@Entity('[table_name]')
export class [Entity] {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: false })
  nome: string;

  @Column({ unique: true, nullable: false })
  email: string;

  @Column({ type: 'enum', enum: ['ACTIVE', 'INACTIVE'], default: 'ACTIVE' })
  status: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @ManyToOne(() => ParentEntity, parent => parent.children, { lazy: true })
  parent: ParentEntity;

  @OneToMany(() => ChildEntity, child => child.parent, { cascade: true })
  children: ChildEntity[];
}
```

### Python + SQLAlchemy

```python
# models.py
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base
import enum

class StatusEnum(enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"

class [Entity](Base):
    __tablename__ = "[table_name]"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    status = Column(Enum(StatusEnum), default=StatusEnum.ACTIVE, nullable=False)
    
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, onupdate=datetime.utcnow)

    # Relationships
    parent_id = Column(Integer, ForeignKey("parent.id"))
    parent = relationship("ParentEntity", back_populates="children")
    children = relationship("ChildEntity", back_populates="parent", cascade="all, delete-orphan")

    def deactivate(self):
        self.status = StatusEnum.INACTIVE

    def is_active(self) -> bool:
        return self.status == StatusEnum.ACTIVE
```

### C# + Entity Framework

```csharp
// [Entity].cs
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("[table_name]")]
public class [Entity]
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long Id { get; set; }

    [Required, MaxLength(255)]
    public string Nome { get; set; }

    [Required]
    public string Email { get; set; }

    [Required]
    public Status Status { get; set; } = Status.Active;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    // Relationships
    public long? ParentId { get; set; }
    public virtual ParentEntity Parent { get; set; }
    public virtual ICollection<ChildEntity> Children { get; set; } = new List<ChildEntity>();
}

public enum Status { Active, Inactive, Suspended }
```

---

## ✅ Boas Práticas

1. ✅ **Audit fields** — `createdAt`, `updatedAt` em toda entity
2. ✅ **equals/hashCode por ID** — nunca por campos de negócio mutáveis
3. ✅ **Lazy loading por padrão** em relacionamentos `@ManyToOne`
4. ✅ **Enum como String** no banco (`EnumType.STRING`), nunca ordinal
5. ✅ **Constructor protegido** sem args para JPA, e constructor de negócio com args obrigatórios
6. ✅ **Cascade com cuidado** — só em relacionamentos de agregação forte (parent→children)

## ❌ Anti-Patterns

1. ❌ **Entity como DTO** — nunca expor entity na API (criar DTO separado)
2. ❌ **Lógica complexa na entity** — orquestração vai no service
3. ❌ **equals/hashCode por todos os campos** — quebra com JPA/proxies
4. ❌ **Eager loading em tudo** — causa N+1 e performance problems
5. ❌ **Sem audit fields** — impossível rastrear quem/quando modificou

---

## 🧪 Test Template

```
class [Entity]Test {  // Unit Test (sem banco)

    // Test: constructor cria com valores corretos
    void constructor_shouldSetFields_whenValidArgs() { }

    // Test: equals por ID
    void equals_shouldBeTrue_whenSameId() { }

    // Test: equals false para IDs different
    void equals_shouldBeFalse_whenDifferentId() { }

    // Test: domain methods
    void deactivate_shouldSetStatusInactive() { }
    void isActive_shouldReturnTrue_whenActive() { }
}
```
