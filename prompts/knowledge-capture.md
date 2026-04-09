# 🧠 Prompts — Knowledge Capture & Reuse

**Domínio:** Memória persistente, busca local, economia de tokens  
**Prerequisito:** KNOWLEDGE agent + MCP Graph Workflow configurado  
**Referência:** [skills/knowledge-capture.md](../skills/knowledge-capture.md)

---

## PROMPT #1 — Buscar Solução Local (Knowledge Search)

```
Acting as KNOWLEDGE agent:

Search the Knowledge Hub for an existing solution:

Context:
- Project: [PROJECT_NAME]
- Domain: [financial / medical / crm / auth / ecommerce / messaging / reporting / integration / infrastructure / general]
- Pattern: [crud-api / calculation / data-transform / auth-flow / error-handling / testing / refactoring / design-pattern / query-optimization / configuration]
- Language: [java / typescript / python / csharp / go / rust]
- Framework: [spring-boot / nestjs / express / fastapi / django / react / angular / vue]

Problem to solve:
[Descreva o problema em 2-3 linhas]

Instructions:
1. Search the Knowledge Hub using FTS5 + TF-IDF
2. If match ≥ 75%: return the stored solution with adaptation notes
3. If match < 75%: indicate this is a NEW learning opportunity
4. Show: solution_id, quality_score, match_percentage, source_project
```

---

## PROMPT #2 — Capturar Solução de Agente Externo

```
Acting as KNOWLEDGE agent:

Capture and index this solution from an external AI agent:

Source:
- Agent: [claude-sonnet / gpt-4o / deepseek / gemini / ollama / copilot]
- Project: [PROJECT_NAME]
- Session date: [YYYY-MM-DD]

Classification:
- Domain: [domain from taxonomy]
- Pattern: [pattern from taxonomy]
- Language: [programming language]
- Framework: [framework used]
- Tags: [tag1, tag2, tag3, tag4]
- Initial quality score: [0.0 to 1.0]

Original prompt:
"""
[Cole aqui a pergunta original que você fez ao agente]
"""

Solution received:
"""
[Cole aqui a resposta completa do agente]
"""

Instructions:
1. Generate a concise summary (2-3 lines) optimized for search
2. Calculate token count of the solution
3. Check for duplicates (SHA-256 hash)
4. Index with FTS5 and generate TF-IDF embeddings
5. Store in Knowledge Hub
6. Return: solution_id, estimated_future_savings
```

---

## PROMPT #3 — Cross-Project Knowledge Search

```
Acting as KNOWLEDGE agent:

Search across ALL registered projects for reusable solutions:

Current project: [PROJECT_NAME]
Current domain: [domain]
Current need: [describe what you need in 1-2 lines]

Instructions:
1. Search all projects in the factory registry
2. Filter by domain relevance
3. Adapt context if language/framework differs
   (e.g., Java solution → TypeScript adaptation)
4. Rank by: quality_score × relevance × recency
5. Return top 5 matches with:
   - source_project, domain, pattern
   - quality_score, usage_count
   - adaptation notes (if language/framework differs)
   - estimated tokens saved if reused
```

---

## PROMPT #4 — Economy Report

```
Acting as KNOWLEDGE agent:

Generate a Knowledge Hub economy report:

Period: [last week / last month / last quarter / all time]
Project: [PROJECT_NAME or "all projects"]

Include:
1. Total solutions stored (by domain, by pattern)
2. Solutions reused this period
3. Total tokens saved (estimated)
4. Cost equivalent saved (at $3/1M input tokens avg)
5. Top 5 most reused solutions
6. Top 3 domains with most knowledge
7. Recommendations:
   - Domains with low coverage (opportunities to capture more)
   - Stale solutions (not used in 3+ months)
   - High-value solutions (most reused)

Format: Table + summary paragraph
```

---

## PROMPT #5 — Validate & Score Solution

```
Acting as KNOWLEDGE agent:

Update quality feedback for a stored solution:

Solution ID: [id from previous capture]
Project where used: [PROJECT_NAME]

Feedback:
- Did it work? [yes / partially / no]
- Adaptation needed: [none / minor tweaks / significant changes / complete rewrite]
- Quality score: [0.0 to 1.0]
  (0.0 = useless, 0.5 = needed major changes, 0.8 = minor tweaks, 1.0 = perfect)
- Notes: [any observations about the solution]
- Should expire? [no / yes, after N months]

Instructions:
1. Update quality_score with weighted average (previous + new)
2. Increment usage_count
3. Calculate tokens_saved for this reuse
4. Update last_used_at
5. If quality < 0.3 after 3+ uses: flag for deprecation
6. Return updated stats
```
