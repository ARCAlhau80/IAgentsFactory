---
domain: operations
pattern: dashboard
language: javascript
framework: node-http
agent: factory-seed
quality: 0.91
tags: dashboard, knowledge-hub, sqlite, filters
---

## Prompt

Descreva a solucao usada pela Factory para expor KPIs e operacao do knowledge.db em um dashboard leve, sem depender de framework pesado.

## Solution

```text
A Factory usa um servidor Node.js enxuto para ler o knowledge.db diretamente com better-sqlite3.
O backend agrega KPIs, alertas, tabelas e distribuicoes a partir de learned_solutions e factory_projects.
No front-end, uma pagina estatica em HTML/CSS/JS consome /api/dashboard e renderiza cards, barras e tabelas.
O desenho favorece operacao local, startup rapido e baixa friccao para times que querem visao do acervo sem subir infraestrutura adicional.
```

## Summary

Dashboard operacional da Factory baseado em Node.js + SQLite direto no knowledge.db, com foco em leitura local, KPIs e navegacao do acervo.