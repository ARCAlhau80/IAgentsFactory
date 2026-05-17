---
domain: database
pattern: data-processing
language: powershell
framework: sqlite
agent: claude-sonnet
quality: 0.92
tags: sqlite, multiline, separator, powershell, sql, newline, column-parsing
---

## Prompt

Ao ler linhas do SQLite CLI com separador customizado (ex: |SEP|), colunas que contem quebras de linha no conteudo fazem o SQLite emitir multiplas linhas OS por registro, quebrando o split de colunas. Como corrigir o SQL para garantir saida de uma linha por registro?

## Solution

O SQLite CLI usa o flag `-separator` apenas para separar COLUNAS, nao linhas. Se o conteudo de uma coluna (ex: solution_content, description) tem `\n` ou `\r\n` embutidos, o SQLite emite essas quebras literalmente, resultando em multiplas linhas OS para um unico registro do banco.

Fix: usar REPLACE no SQL para achatar o conteudo antes da saida.

```sql
-- Padrão: colunas com conteudo multiline quebram o separador
SELECT id, solution_content FROM learned_solutions;
-- SQLite emite:
-- id1|linha1
-- linha2
-- linha3
-- id2|conteudo normal
-- Resultado: split por |SEP| da colunas erradas para linha2 e linha3

-- FIX: achatar newlines no SQL antes de emitir
SELECT
    id,
    REPLACE(REPLACE(COALESCE(solution_content, ''), char(13), ''), char(10), ' '),
    REPLACE(REPLACE(COALESCE(solution_summary, ''), char(13), ''), char(10), ' '),
    REPLACE(REPLACE(COALESCE(prompt_used, ''),     char(13), ''), char(10), ' ')
FROM learned_solutions
WHERE is_deprecated = 0;
-- Agora cada registro ocupa exatamente 1 linha OS
-- char(13) = CR (\r), char(10) = LF (\n)
-- COALESCE garante que NULL vira string vazia antes do REPLACE
```

```powershell
# No PowerShell, usar com separador customizado
$rows = & sqlite3 -separator "|SEP|" $dbPath $sql 2>$null
foreach ($row in @($rows)) {
    $cols = [string]$row -split '\|SEP\|', 4
    # Agora $cols sempre tem exatamente 4 elementos por registro
    $id      = if ($cols.Count -gt 0) { $cols[0].Trim() } else { "" }
    $content = if ($cols.Count -gt 1) { $cols[1].Trim() } else { "" }
}
```

## Summary

SQLite CLI emite quebras de linha embutidas em colunas como linhas OS separadas, quebrando parse de separadores customizados. Fix: envolver colunas multiline com REPLACE(REPLACE(COALESCE(col,''),char(13),''),char(10),' ') no SELECT para garantir uma linha OS por registro do banco.
