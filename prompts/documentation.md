# 📝 PROMPTS: Documentation

**Uso:** Gerar documentação técnica e de negócio  
**Agente:** COORDINATOR  
**Aplicabilidade:** Qualquer projeto

---

## PROMPT #1 — Gerar ADR (Architecture Decision Record)

**Quando usar:** Documentar uma decisão técnica importante.

```
CONTEXTO:
- Projeto: [PROJECT_NAME]
- Decisão: [DESCREVA A DECISÃO]
- Alternativas consideradas: [LISTA]

TAREFA:
Gerar um ADR no formato:

# ADR-[NUMBER]: [TÍTULO]
- **Status:** Proposed | Accepted | Deprecated | Superseded
- **Data:** [DATA]
- **Decisores:** [NOMES]

## Contexto
[Por que essa decisão precisa ser tomada? Qual o problema?]

## Decisão
[O que foi decidido? Qual alternativa escolhida?]

## Alternativas Consideradas
| Alternativa | Prós | Contras |
|------------|------|---------|
| [ALT_1]    | ...  | ...     |
| [ALT_2]    | ...  | ...     |

## Consequências
- ✅ Positivas: [...]
- ⚠️ Negativas: [...]
- 📋 Ações necessárias: [...]

## Referências
- [links relevantes]

REQUISITOS:
- Linguagem clara e objetiva
- Foco em "por quê", não "como"
- Listar trade-offs honestamente
- Salvar em docs/decisions/ADR-[number].md
```

---

## PROMPT #2 — Gerar README de Projeto

**Quando usar:** Criar documentação de entrada para o projeto.

```
CONTEXTO:
- Projeto: [PROJECT_NAME]
- Stack: [LANGUAGE] + [FRAMEWORK] + [DATABASE]
- Propósito: [O QUE O PROJETO FAZ]

TAREFA:
Gerar um README.md completo com:

1. HEADER: Nome + descrição de 1 linha + badges (build, coverage, version)
2. QUICK START: Como rodar em 3 comandos (clone, install, run)
3. PRÉ-REQUISITOS: Ferramentas necessárias com versões
4. ESTRUTURA: Árvore de pastas com descrição de cada pasta
5. DEVELOPMENT: Como buildar, testar, lint
6. API: Tabela dos principais endpoints (se API)
7. ENVIRONMENT: Variáveis de ambiente obrigatórias
8. DEPLOY: Como fazer deploy (manual ou CI/CD)
9. CONTRIBUTING: Como contribuir
10. LICENSE: Tipo de licença

REQUISITOS:
- Assumi que o leitor é um dev novo no projeto
- Copiar e colar os comandos deve FUNCIONAR
- Sem informação desatualizada (mantenha conciso)
```

---

## PROMPT #3 — Documentar API (OpenAPI/Swagger Summary)

**Quando usar:** Criar documentação legível dos endpoints da API.

```
CONTEXTO:
- Stack: [LANGUAGE] + [FRAMEWORK]
- Controllers: [LISTAR OU COLAR CÓDIGO]

TAREFA:
Gerar documentação da API em formato Markdown com:

1. OVERVIEW: Propósito da API, base URL, autenticação
2. ENDPOINTS: Para cada endpoint:
   - Método + Path
   - Descrição
   - Request body (com exemplo JSON)
   - Response body (com exemplo JSON)  
   - Status codes possíveis
   - Parâmetros de query (paginação, filtros)
3. ERROR FORMAT: Formato padrão de erros
4. AUTENTICAÇÃO: Como obter e enviar token

OUTPUT FORMAT:
## [Entity]

### GET /api/v1/[entities]
**Descrição:** Lista [entities] com paginação

**Query Parameters:**
| Param | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| page  | int  | Não         | Número da página (default: 0) |
| size  | int  | Não         | Itens por página (default: 20) |

**Response 200:**
```json
{ "content": [...], "totalElements": 100, "totalPages": 5 }
```

**Response 401:** Não autenticado
**Response 403:** Sem permissão
```

---

## PROMPT #4 — Gerar Changelog

**Quando usar:** Documentar o que mudou entre releases.

```
CONTEXTO:
- Projeto: [PROJECT_NAME]
- Período: [DATA_INÍCIO] a [DATA_FIM]
- Commits/PRs: [LISTAR COMMITS OU PRs]

TAREFA:
Gerar changelog no formato Keep a Changelog:

## [VERSION] - [DATA]

### Added
- Nova feature X (#PR_NUMBER)
- Endpoint POST /api/v1/Y (#PR_NUMBER)

### Changed
- Atualizado Z para usar nova lib (#PR_NUMBER)

### Fixed
- Corrigido bug no cálculo de W (#ISSUE_NUMBER)

### Removed
- Removido endpoint deprecated GET /api/v1/old (#PR_NUMBER)

### Security
- Atualizado dependência A de 1.0 para 1.1 (CVE-XXXX)

REQUISITOS:
- Linguagem para humanos (não commit messages técnicas)
- Agrupar por tipo (Added/Changed/Fixed/Removed/Security)
- Referenciar PR ou Issue
- Mais recente no topo
```
