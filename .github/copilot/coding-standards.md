# 💻 CODING STANDARDS — IAgentsFactory

**Escopo:** PowerShell + Node.js utilitário + Markdown operacional  
**Aplicado:** Para humanos E IA

---

## 🏛️ Convenções de Nomenclatura

### Classes

```
✅ PADRÃO:

Artefato         | Padrão                    | Exemplo
─────────────────┼───────────────────────────┼────────────────────────────
PowerShell func  | Verbo-Nome                | Get-ProjectMetadata
Script principal | kebab-case.ps1            | iagents-factory.ps1
Config JSON      | kebab-case.json           | dashboard-config.json
Documentos ADR   | ADR-XXX-kebab-case.md     | ADR-002-iagentsfactory-repo-split.md
Agent/skill/prompt | UPPERCASE ou kebab-case | KNOWLEDGE.md / knowledge-capture.md
```

```
❌ NUNCA:
- Nomes genéricos sem contexto: Helper, Utils, Script2, TempFinal
- Misturar idioma no mesmo identificador: processarPipelineState
- Funções PowerShell fora do padrão Verbo-Nome
```

### Métodos

```
✅ PADRÃO:

Tipo             | Prefixo          | Exemplo
─────────────────┼──────────────────┼────────────────────────
Coletar          | Get              | Get-Config()
Resolver         | Resolve          | Resolve-DetectedValue()
Executar         | Invoke           | Invoke-Search()
Salvar           | Save             | Save-Config()
Criar            | New              | New-Id()
Validar          | Test, Validate   | Test-Path, ValidateSet
```

```
❌ NUNCA:
- Nomes de 1-2 letras: x(), fn(), go()
- Funções com múltiplas responsabilidades operacionais sem separação clara
- Negações duplas: isNotInvalid()
```

### Variáveis

```
✅ PADRÃO:
- camelCase (Java/JS/TS) ou snake_case (Python/Ruby)
- Nomes descritivos: totalAmount, isActive, userList
- Constantes: UPPER_SNAKE_CASE → MAX_RETRY_COUNT

❌ NUNCA:
- 1 letra (exceto loops): a, x, d
- Tipo no nome: strName, intCount, listUsers
- Abreviações obscuras: usrMgr, txnProc
```

---

## 🎯 Estrutura de Classes

### Template Geral

```
PowerShell script structure:

1. Param block
2. Encoding / strict defaults
3. Globals / paths
4. Helpers
5. Command handlers
6. Main dispatcher
```

<!-- Adicione templates específicos para cada tipo de classe do seu projeto -->

### [TIPO_CLASSE_1] Template (ex: Controller)

```
// Adapte este template para sua linguagem e framework

[Annotations/Decorators]
public class [Nome][Tipo] {

    // 1. Dependencies (injection)
    private final [Dependency1] dependency1;
    
    // 2. Constructor
    public [Nome][Tipo]([Dependency1] dependency1) {
        this.dependency1 = dependency1;
    }
    
    // 3. Public methods
    public [ReturnType] [method]([Params]) {
        // Implementation
    }
}
```

---

## 📦 Organização de Pacotes/Módulos

```
IAgentsFactory/
├── .github/              # comportamento do agente
├── config/               # configuracao e exemplos
├── docs/                 # operacao, ADR, arquitetura
├── tools/                # dashboard e utilitarios
├── patterns/             # templates estruturais
├── prompts/              # prompts reutilizaveis
├── skills/               # how-to guias
└── *.ps1                 # automacao principal
```

---

## ⚠️ Anti-Patterns (NUNCA fazer)

<!-- Liste os anti-patterns específicos do seu projeto -->

1. ❌ Misturar conceito de ADK base com produto final sem deixar a fronteira explícita.
2. ❌ Adicionar caminhos absolutos em regras novas quando poderiam ser config/env.
3. ❌ Capturar solução no banco sem hash, metadados ou resumo.
4. ❌ Script PowerShell gigante sem handlers separados por comando.
5. ❌ Dashboard ou automação dependente de framework pesado sem necessidade real.

---

## ✅ Padrões Obrigatórios

<!-- Liste padrões que TODO código novo deve seguir -->

1. ✅ Todo comando principal da factory deve ter um handler `Invoke-*` dedicado.
2. ✅ Toda função PowerShell nova deve seguir verbo aprovado do PowerShell quando possível.
3. ✅ Toda mudança em knowledge flow deve considerar busca, captura, score e reuso.
4. ✅ Logs e mensagens devem ser operacionais e claros, sem verbosidade artificial.
5. ✅ Markdown de governança deve refletir o estado real do produto, não placeholders.

---

## 🧪 Padrões de Teste

```
Nomenclatura:  [script]-smoke, [flow]-validation, ou teste manual documentado
Estrutura:     Setup → Execute → Validate
Localização:   docs/, scripts auxiliares ou pipeline externa
Cobertura:     Priorizar smoke tests dos fluxos `init`, `register`, `search`, `capture`
```

| Componente | Tipo de Teste | Framework |
|------------|---------------|-----------|
| PowerShell CLI | Smoke / functional | PowerShell manual ou Pester futuro |
| Dashboard local | Health + API | Node runtime |
| MCP integration | Integration | Fluxo local com MCP Graph |

