# 📖 SKILL: Knowledge Capture & Reuse

**Propósito:** Capturar soluções de agentes de IA externos e reutilizá-las localmente para economizar tokens  
**Aplicabilidade:** Toda interação valiosa com agentes externos (Claude, GPT-4o, DeepSeek, Gemini, etc.)  
**Esforço:** ~2 min por captura (automática) | ~30s por busca local

---

## 📋 Quando Usar Esta Skill

✅ **USE quando:**
- Recebeu uma solução valiosa de um agente externo (Claude, GPT-4o, etc.)
- Vai iniciar trabalho em domínio similar a projeto anterior
- Quer verificar se já existe solução local antes de gastar tokens
- Precisa classificar e organizar conhecimento aprendido
- Quer economizar tokens em interações repetitivas

❌ **NÃO use quando:**
- A pergunta é trivial ou one-off (não vale indexar)
- A solução é altamente específica e não reutilizável
- Precisa de resposta em tempo real sem latência de busca

---

## 🎯 Conceito

```
┌────────────────────────────────────────────────────┐
│            KNOWLEDGE CAPTURE PIPELINE              │
│                                                    │
│  ANTES de perguntar ao agente externo:             │
│  ┌─────────┐    ┌──────────────┐                   │
│  │ Pergunta│───►│ Knowledge Hub│──► Match ≥75%? ─► │ USA LOCAL
│  └─────────┘    │ (FTS5 + RAG) │                   │
│                 └──────────────┘──► Sem match ───► │ CHAMA EXTERNO
│                                                    │
│  DEPOIS de receber resposta do agente externo:     │
│  ┌──────────┐   ┌──────────┐   ┌──────────────┐   │
│  │ Resposta │──►│Classifica│──►│ Knowledge Hub│   │
│  │ do Agent │   │ + Indexa │   │    (SALVA)   │   │
│  └──────────┘   └──────────┘   └──────────────┘   │
│                                                    │
│  Na PRÓXIMA VEZ com pergunta similar:              │
│  ┌─────────┐    ┌──────────────┐                   │
│  │ Pergunta│───►│ Knowledge Hub│──► Match 92%! ──► │ USA LOCAL ✅
│  └─────────┘    └──────────────┘   (0 tokens ext.) │
└────────────────────────────────────────────────────┘
```

---

## 📐 Passo a Passo

### Step 1: Buscar no Knowledge Hub ANTES de chamar agente externo

Antes de enviar qualquer pergunta a um agente externo, verifique se já existe solução local:

```
Pergunte ao KNOWLEDGE agent:

"Buscar no Knowledge Hub:
  - Domínio: [financial/medical/crm/auth/etc.]
  - Padrão: [roi-calculation/crud-api/auth-flow/etc.]
  - Linguagem: [java/typescript/python/etc.]
  - Problema: [descreva em 1-2 linhas]"
```

**O que faz:** Busca no SQLite (FTS5 + TF-IDF) por soluções similares armazenadas.

**Possíveis resultados:**
- `Match ≥ 75%` → Use a solução local (adapte se necessário). **Zero tokens externos!**
- `Match < 75%` → Prossiga para o Step 2 (chamar agente externo)
- `Sem resultados` → Prossiga para o Step 2. Esta é uma **oportunidade de aprendizado.**

### Step 2: Chamar Agente Externo (quando não há match local)

Faça a pergunta normalmente ao agente externo (Claude, GPT-4o, etc.).

```
Dica de otimização (via OpenClaude agent routing):
- Perguntas simples/boilerplate → DeepSeek (mais barato)
- Perguntas complexas/design → GPT-4o ou Claude Sonnet
- Code generation → Claude Sonnet ou GPT-4o
- Debugging → qualquer modelo competente
```

### Step 3: Capturar a Solução no Knowledge Hub

Após receber uma resposta valiosa, capture-a:

```
Informe ao KNOWLEDGE agent:

"Capturar solução:
  - Domínio: financial
  - Padrão: roi-calculation
  - Linguagem: java
  - Framework: spring-boot
  - Projeto origem: loteria-roi
  - Agente: claude-sonnet-4
  - Qualidade: 0.9
  - Tags: [roi, financial, calculation, investment]
  
  Prompt original: [cole a pergunta]
  Solução: [cole a resposta do agente]"
```

**O que faz:** 
1. Classifica a solução por domain/pattern/language
2. Gera summary otimizado para busca
3. Calcula embeddings TF-IDF
4. Verifica duplicação via SHA-256
5. Salva no Knowledge Hub (SQLite + FTS5)

### Step 4: Validar e Pontuar

Após usar a solução no seu código:

```
"Feedback para KNOWLEDGE:
  - Solução ID: [id retornado no Step 3]
  - Funcionou: sim/não
  - Quality score: [0.0 a 1.0]
  - Notas: [observações sobre adaptações necessárias]"
```

**O que faz:** Atualiza o quality_score e usage_count, melhorando o ranking para buscas futuras.

---

## 🏷️ Taxonomia de Classificação

### Domains (domínios de negócio)

| Domain | Exemplos |
|--------|----------|
| `financial` | ROI, investimentos, cálculos fiscais, billing |
| `medical` | Prontuários, diagnósticos, prescrições |
| `crm` | Clientes, vendas, pipeline, leads |
| `auth` | Login, OAuth2, JWT, permissões, RBAC |
| `ecommerce` | Carrinho, checkout, pagamento, estoque |
| `messaging` | Email, notificações, push, webhooks |
| `reporting` | Relatórios, dashboards, exportação |
| `integration` | APIs externas, ETL, sync |
| `infrastructure` | Deploy, CI/CD, Docker, monitoring |
| `general` | Algoritmos genéricos, utils, helpers |

### Patterns (tipos de solução)

| Pattern | Exemplos |
|---------|----------|
| `crud-api` | REST endpoints completos |
| `calculation` | Fórmulas, algoritmos matemáticos |
| `data-transform` | Mapeamento, conversão, ETL |
| `auth-flow` | Login, token management |
| `error-handling` | Exception handling, retry, circuit breaker |
| `testing` | Test patterns, mocks, fixtures |
| `refactoring` | Code smell fix, extract method |
| `design-pattern` | Strategy, Observer, Factory, etc. |
| `query-optimization` | SQL tuning, N+1 fix, indexing |
| `configuration` | Setup, ambiente, properties |

---

## ✅ Resultado Esperado

Após seguir esta skill consistentemente, você terá:
- 📚 **Knowledge base crescente** com soluções validadas
- 💰 **60-90% economia de tokens** em perguntas repetitivas
- ⚡ **Busca local em ms** vs. 2-5s de chamada API
- 🔄 **Cross-project reuse** — soluções de um projeto beneficiam outros
- 📊 **Métricas de economia** — visibilidade sobre o ROI do knowledge base

---

## ⚠️ Armadilhas Comuns

| Armadilha | Sintoma | Solução |
|-----------|---------|---------|
| Capturar tudo sem curadoria | Knowledge base poluído, matches irrelevantes | Só capture soluções com quality ≥ 0.6, depure periodicamente |
| Threshold muito baixo | Muitos false matches | Comece com 75%, ajuste para 80% se necessário |
| Threshold muito alto | Raramente encontra match local | Baixe para 70%, aceite adaptação manual |
| Não classificar corretamente | Busca não encontra quando deveria | Use taxonomia padrão (domains + patterns acima) |
| Nunca dar feedback | Quality scores estáticos, ranking pobre | Após usar solução, sempre atualize quality_score |
| Solução obsoleta reutilizada | Bug por usar versão antiga | Configure TTL por domain, re-valide trimestralmente |

---

## 📊 Métricas de Referência

| Métrica | Iniciante | Intermediário | Avançado |
|---------|-----------|---------------|----------|
| Soluções capturadas | 10-30 | 50-100 | 200+ |
| Taxa de reuso | 10-20% | 30-50% | 60%+ |
| Token savings/mês | -20% | -50% | -80% |
| Cross-project reuse | 0 | 5-10 | 20+ |
| Avg quality score | 0.5-0.7 | 0.7-0.85 | 0.85+ |

---

## 📚 Referências

- [ADR-001: Knowledge Hub Architecture](../../docs/decisions/ADR-001-knowledge-hub-architecture.md)
- [IAgentsFactory Analysis](../../docs/architecture/IAGENTSFACTORY-ANALYSIS.md)
- [KNOWLEDGE Agent](../../.github/agents/KNOWLEDGE.md)
- [MCP Graph Workflow](https://github.com/your-repo/mcp-graph-workflow) (motor de persistência)
- [OpenClaude](https://github.com/Gitlawb/openclaude) (gateway multi-provider)

