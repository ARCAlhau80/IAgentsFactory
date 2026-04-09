---
domain: productivity
pattern: workflow-api
language: python
framework: flask
agent: factory-seed
quality: 0.88
tags: kanban, flask, sqlite, status, drag-drop
---

## Prompt

Resuma a abordagem tecnica do projeto ToDo para manter um board Kanban simples com persistencia local e atualizacao de status.

## Solution

```text
O projeto ToDo organiza tarefas em colunas Todo, Iniciar e Terminar e expoe uma API simples em Flask.
As operacoes principais sao GET /api/tasks, POST /api/tasks e PATCH /api/tasks/<id>/status.
A persistencia e local em SQLite, o que simplifica setup e torna o projeto adequado para onboarding, demos e automacao leve.
No front-end, o drag-and-drop move tarefas entre colunas e a API persiste a mudanca de status.
```

## Summary

Padrao de board Kanban leve em Flask com API minima de tarefas e persistencia local em SQLite, util para fluxos simples de produtividade.