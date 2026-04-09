# 🎯 PATTERN: [COMPONENT_TYPE] Template

**Purpose:** Template reutilizável para criar [COMPONENT_TYPE]  
**Applicable To:** [Onde se aplica — ex: todas as APIs REST, todas as entities]

---

## 📋 Quick Reference

```
[COMPONENT_TYPE]:
├── [RESPONSABILIDADE_1]
├── [RESPONSABILIDADE_2]
├── [RESPONSABILIDADE_3]
└── [RESPONSABILIDADE_4]
```

---

## 🏗️ Template

```[LANGUAGE]
// ═══════════════════════════════════════════════
// [COMPONENT_TYPE]: [Nome]
// Purpose: [O que este componente faz]
// Created: [DATE]
// ═══════════════════════════════════════════════

[ANNOTATIONS/DECORATORS]
public class [Nome][Sufixo] {

    // ─────────────────────────────────────
    // 1. DEPENDENCIES
    // ─────────────────────────────────────
    
    private final [Dependency1] dependency1;
    
    // ─────────────────────────────────────
    // 2. CONSTRUCTOR
    // ─────────────────────────────────────
    
    public [Nome][Sufixo]([Dependency1] dependency1) {
        this.dependency1 = dependency1;
    }
    
    // ─────────────────────────────────────
    // 3. PUBLIC METHODS (API surface)
    // ─────────────────────────────────────
    
    public [ReturnType] [method]([Params]) {
        // TODO: implementar
    }
    
    // ─────────────────────────────────────
    // 4. PRIVATE METHODS (internal)
    // ─────────────────────────────────────
    
    private [ReturnType] [helperMethod]([Params]) {
        // TODO: implementar
    }
}
```

---

## ✅ Boas Práticas

1. ✅ [BOA_PRATICA_1 — ex: Sempre injetar dependências via constructor]
2. ✅ [BOA_PRATICA_2 — ex: Logging no início e fim de operações]
3. ✅ [BOA_PRATICA_3 — ex: Validar inputs na entrada]

## ❌ Anti-Patterns

1. ❌ [ANTI_PATTERN_1 — ex: Não usar field injection (@Autowired no campo)]
2. ❌ [ANTI_PATTERN_2 — ex: Não retornar null, usar Optional]
3. ❌ [ANTI_PATTERN_3 — ex: Não capturar Exception genérica]

---

## 🧪 Test Template

```[LANGUAGE]
// Test for [Nome][Sufixo]
class [Nome][Sufixo]Test {

    // Setup
    // ...

    // Test: happy path
    void [method]_shouldReturnExpected_whenValidInput() {
        // Given
        // When
        // Then
    }

    // Test: edge case
    void [method]_shouldThrow_whenInvalidInput() {
        // Given
        // When / Then
    }
}
```

---

## 📊 Checklist

- [ ] Segue nomenclatura de coding-standards.md
- [ ] Não viola nenhuma regra de domains-rules.md
- [ ] Tem logging adequado
- [ ] Tem error handling
- [ ] Tem teste correspondente
