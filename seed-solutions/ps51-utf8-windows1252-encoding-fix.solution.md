---
domain: powershell
pattern: encoding-fix
language: powershell
framework: powershell-5.1
agent: claude-sonnet
quality: 0.95
tags: powershell, encoding, utf8, windows-1252, unicode, parse-error, ps51
---

## Prompt

PowerShell 5.1 apresenta erros de parse em arquivos .ps1 com caracteres Unicode como traco-longo (em-dash U+2014) e caracteres de caixa (U+2500). O erro tipico e: "Expressoes sao permitidas apenas como o primeiro elemento de um pipeline." Como corrigir?

## Solution

O problema: PowerShell 5.1 le arquivos UTF-8-sem-BOM como Windows-1252. O char em-dash (U+2014, UTF-8: E2 80 94) e box-drawing (U+2500, UTF-8: E2 94 80) contem o byte 0x94, que Windows-1252 mapeia para RIGHT_DOUBLE_QUOTATION_MARK (aspas tipograficas). O PS5.1 interpreta essa aspa como delimitador de string, fechando a string no meio do codigo.

Fix: substituir todos os chars nao-ASCII por equivalentes ASCII antes de commitar o arquivo.

```powershell
# Detectar chars nao-ASCII em arquivos .ps1
$text = [System.IO.File]::ReadAllText(".\script.ps1", [System.Text.Encoding]::UTF8)
$nonAscii = [regex]::Matches($text, '[^\x00-\x7F]').Count
Write-Host "Non-ASCII chars: $nonAscii"

# Corrigir: substituir os chars problemáticos
$fixed = $text `
    -replace [char]0x2014, ' - ' `  # em-dash
    -replace [char]0x2500, '-'  `   # box-drawing horizontal
    -replace [char]0x2013, ' - ' `  # en-dash
    -replace [char]0x2012, ' - ' `  # figure dash
    -replace [char]0x2026, '...'    # ellipsis

# Salvar com UTF-8 (com ou sem BOM — ambos funcionam apos remover nao-ASCII)
[System.IO.File]::WriteAllText(".\script.ps1", $fixed, [System.Text.Encoding]::UTF8)

# Validar parse apos correcao
$tokens = $null; $errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path ".\script.ps1").Path, [ref]$tokens, [ref]$errors)
if ($errors.Count -eq 0) { "OK - sem erros de parse" }
else { $errors | ForEach-Object { "L$($_.Extent.StartLineNumber): $($_.Message)" } }
```

Regra preventiva: scripts PowerShell devem conter APENAS caracteres ASCII (U+0000 a U+007F). Usar `-` em vez de `—`, `|` em vez de `─`, `...` em vez de `…`.

## Summary

PowerShell 5.1 le UTF-8-sem-BOM como Windows-1252. Byte 0x94 presente em em-dash (U+2014) e box-drawing (U+2500) e interpretado como aspa tipografica, quebrando parse de strings. Fix: substituir todos chars nao-ASCII com equivalentes ASCII via -replace antes de salvar o .ps1.
