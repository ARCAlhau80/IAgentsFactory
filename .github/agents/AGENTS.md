# 🤖 AI Agents Guide — [PROJECT_NAME]

---

## 📋 Agent Index

| Agent | Expertise | Quando Usar |
|-------|-----------|-------------|
| 🏛️ [ARCHITECT](ARCHITECT.md) | Design, Padrões, Performance | Revisar arquitetura, decisões |
| 💻 [BACKEND](BACKEND.md) | Geração de código | Criar novos componentes |
| 🧪 [QA](QA.md) | Testes, Cobertura | Gerar testes, validar qualidade |
| 🔧 [REFACTOR](REFACTOR.md) | Code smells, Limpeza | Melhorar código existente |
| 🎯 [COORDINATOR](COORDINATOR.md) | Planejamento, Sequenciamento | Planejar tarefas, sprints |
| 📊 [OBSERVABILITY](OBSERVABILITY.md) | Logs, Métricas, Tracing | Instrumentar código, debugar produção |
| 🧠 [KNOWLEDGE](KNOWLEDGE.md) | Memória persistente, Reuso | Buscar/capturar soluções, economizar tokens |

---

## 🎯 Quick Reference

| Preciso de... | → Use |
|---------------|-------|
| "Como devo projetar isso?" | ARCHITECT |
| "Gere código para este requisito" | BACKEND |
| "Crie testes para meu código" | QA |
| "Este código está confuso, como melhorar?" | REFACTOR |
| "O que devemos fazer a seguir?" | COORDINATOR |
| "Adicione logs/métricas ao meu código" | OBSERVABILITY |
| "Investigue este erro em produção" | OBSERVABILITY |
| "Já resolvemos algo parecido antes?" | KNOWLEDGE |
| "Salve essa solução para reuso futuro" | KNOWLEDGE |
| "Quanto economizamos em tokens?" | KNOWLEDGE |

---

## 🔄 Workflow: Nova Feature

```
1. KNOWLEDGE → Busca soluções similares no Knowledge Hub
2. COORDINATOR → Divide em tarefas (com head start do knowledge)
3. ARCHITECT → Valida design (se complexo)
4. BACKEND → Gera código
5. QA → Gera testes
6. KNOWLEDGE → Captura soluções novas para reuso futuro
7. COORDINATOR → Verifica completude
```

## 🔄 Workflow: Melhoria de Qualidade

```
1. REFACTOR → Identifica code smells
2. ARCHITECT → Valida mudanças (se estrutural)
3. REFACTOR → Aplica refactoring
4. QA → Garante que testes passam
```

## 🔄 Workflow: Resolver com Memória (Knowledge-First)

```
1. KNOWLEDGE → Busca local (match ≥ 75%?)
2. Se sim → Retorna solução adaptada (0 tokens ext.) → FIM
3. Se não → BACKEND/ARCHITECT resolve com agente externo
4. KNOWLEDGE → Captura solução para reuso futuro
```

## 🔄 Workflow: Planejamento

```
1. COORDINATOR → Analisa backlog + AS-IS + TO-BE
2. COORDINATOR → Prioriza tarefas
3. Distribui para agentes (BACKEND, QA, REFACTOR)
4. COORDINATOR → Acompanha progresso
```
