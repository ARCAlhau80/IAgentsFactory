---
domain: integration
pattern: api-sync
language: csharp
framework: .net 8.0
agent: factory-seed
quality: 0.89
tags: dotnet, sql-server, api, retry, sync
---

## Prompt

Resuma a solucao tecnica do AtualizadorLotofacil para sincronizar dados externos com SQL Server.

## Solution

```text
O AtualizadorLotofacil implementa um fluxo de sincronizacao em C#/.NET 8 que consulta a API da Caixa, identifica o ultimo concurso disponivel e atualiza o SQL Server local.
O processo usa retries para falhas HTTP, parse de JSON e insercao parametrizada no banco.
O padrao reutilizavel e um job de integracao incremental: descobrir ultimo estado remoto, comparar com estado local e aplicar somente o delta pendente.
```

## Summary

Job incremental de integracao em C# que consulta API externa, compara estado local e persiste apenas o delta necessario no SQL Server.