# 🔧 PROMPTS: Refactoring

**Uso:** Identificar code smells e melhorar código existente  
**Agente:** REFACTOR  
**Aplicabilidade:** Qualquer código legado ou com débito técnico

---

## PROMPT #1 — Identificar Code Smells

**Quando usar:** Analisar código existente e listar problemas.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Skills: ver skills/clean-architecture.md
- Source: [COLE O CÓDIGO AQUI]

TAREFA:
Analisar o código acima e identificar:

1. CODE SMELLS (categorizar por severidade):
   🔴 CRÍTICO: Bugs potenciais, vulnerabilidades
   🟡 ALTO: Manutenção difícil, acoplamento forte
   🟢 MÉDIO: Naming, organização, estilo
   ⚪ BAIXO: Cosmético, sugestões de melhoria

2. Para cada smell encontrado:
   - Nome do smell (ex: "Long Method", "God Class")
   - Linha(s) afetada(s)
   - Por que é problema
   - Sugestão de correção (com código)

3. PRIORIZAÇÃO:
   - Classificar do mais urgente ao menos urgente
   - Estimar esforço (minutos, horas)
   - Indicar risco de regressão

OUTPUT FORMAT:
| # | Smell | Severidade | Linha | Esforço | Sugestão |
```

---

## PROMPT #2 — Refactoring: Extract Method

**Quando usar:** Método longo (> 30 linhas) que faz muitas coisas.

```
CONTEXTO:
- Source: [COLE O MÉTODO LONGO AQUI]

TAREFA:
Refatorar o método acima aplicando Extract Method:

1. Identificar blocos lógicos (3-10 linhas cada)
2. Extrair cada bloco em método privado com nome descritivo
3. Manter o método original como "orquestrador"
4. Garantir que cada método extraído tem UMA responsabilidade

REQUISITOS:
- Preservar comportamento EXATO (sem mudar lógica)
- Naming: verbos descritivos (validateInput, calculateTotal, persistOrder)
- Métodos extraídos são testáveis individualmente
- Mostrar ANTES e DEPOIS completo

OUTPUT:
- Código refatorado completo
- Lista de métodos extraídos e sua responsabilidade
- Sugestão de testes para os novos métodos
```

---

## PROMPT #3 — Refactoring: Replace Conditional with Strategy

**Quando usar:** if/else ou switch/case longo que cresce a cada feature nova.

```
CONTEXTO:
- Source: [COLE O CÓDIGO COM IF/ELSE ou SWITCH AQUI]

TAREFA:
Refatorar o código acima substituindo conditional por Strategy Pattern:

1. Criar interface Strategy com o método principal
2. Criar uma implementação para cada caso do if/else ou switch
3. Criar um Registry/Factory para selecionar a estratégia
4. O código cliente usa a interface, sem saber qual implementação

REQUISITOS:
- Cada estratégia em arquivo/classe separada
- Registro automático (não hardcoded) quando possível
- Open/Closed Principle: nova feature = nova classe, sem alterar existente
- Mostrar ANTES e DEPOIS

OUTPUT:
- Interface da Strategy
- Implementações (1 por caso)
- Registry/Factory
- Código cliente refatorado
```

---

## PROMPT #4 — Refactoring: Eliminar Duplicação

**Quando usar:** Código similar/duplicado em múltiplos lugares.

```
CONTEXTO:
- Sources: [COLE OS CÓDIGOS DUPLICADOS AQUI]

TAREFA:
Eliminar duplicação extraindo código comum:

1. Identificar o que é IGUAL entre os trechos
2. Identificar o que é DIFERENTE (parâmetros)
3. Extrair para método/classe compartilhada
4. Parametrizar as diferenças

REQUISITOS:
- DRY mas sem abstrações forçadas (se diferem muito, manter separados)
- Nome descritivo para o código extraído
- Testes existentes devem continuar passando

OUTPUT:
- Código extraído (método/classe compartilhada)
- Cada chamador refatorado para usar o código compartilhado
```

---

## PROMPT #5 — Code Review Automatizado

**Quando usar:** Revisar código antes de merge/PR.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Standards: ver .github/copilot/coding-standards.md
- Patterns: ver patterns/
- Source: [COLE O CÓDIGO PARA REVIEW AQUI]

TAREFA:
Fazer code review completo verificando:

1. ✅ FUNCIONALIDADE: Lógica correta? Edge cases cobertos?
2. ✅ SEGURANÇA: Injection? Auth? Dados sensíveis expostos?
3. ✅ PERFORMANCE: N+1? Sem paginação? Operação O(n²)?
4. ✅ TESTES: Cobertura adequada? Cenários de erro?
5. ✅ PADRÕES: Segue patterns/ do projeto?
6. ✅ NAMING: Descritivo? Consistente? Ubiquitous language?
7. ✅ COMPLEXIDADE: Método longo? Classe grande? Aninhamento profundo?

OUTPUT FORMAT:
Classificar cada item como:
  ✅ APROVADO — Sem problemas
  ⚠️ SUGESTÃO — Poderia melhorar (não bloqueia merge)
  ❌ BLOCKER — Deve corrigir antes do merge

Para cada ⚠️ ou ❌:
  - Linha afetada
  - Problema
  - Sugestão com código
```
