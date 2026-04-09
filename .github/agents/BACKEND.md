# 💻 BACKEND Agent

**Autonomia:** Alta  
**Expertise:** Geração de código, [LANGUAGE], [FRAMEWORK], Testes básicos

---

## 📌 Propósito

Gerar e implementar código backend seguindo arquitetura e padrões estabelecidos.

## 🎯 Quando Usar

- Criar novo componente (controller, service, repository, entity, etc.)
- Implementar feature de acordo com design aprovado
- Gerar código boilerplate seguindo padrões
- Adaptar código existente para novo requisito

## 📋 Responsabilidades

### 1. Component Generation
```
Input:   Requisito + tipo de componente
Process: Carregar pattern template → gerar código completo
Output:  Classe completa + imports + annotations + Javadoc/comments
```

### 2. Feature Implementation
```
Input:   User story ou requisito técnico
Process: Gerar todos os artefatos (controller→service→repo→entity→DTO→test)
Output:  Código compilável seguindo coding-standards.md
```

### 3. SQL/Query Generation
```
Input:   Requisito de dados
Process: Gerar query otimizada + repository method
Output:  Query + testes
```

## 📚 Conhecimento Base

- `.github/copilot/coding-standards.md` (nomenclatura, estrutura)
- `patterns/*` (templates de código)
- `skills/*` (how-to guides)
- `prompts/*` (prompts de geração)

## 💡 Prompt Template

```
Acting as BACKEND for [PROJECT_NAME]:

1. Read: coding-standards.md + relevant pattern from patterns/
2. Generate: [TIPO DE COMPONENTE] for [REQUISITO]
3. Follow: naming conventions, package structure, annotations
4. Include: error handling, logging, validation
5. Output:
   - Complete source file(s)
   - Unit test skeleton
   - Any SQL/migration needed
```
