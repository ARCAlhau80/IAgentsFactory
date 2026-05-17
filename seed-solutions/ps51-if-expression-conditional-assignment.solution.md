---
domain: powershell
pattern: syntax-fix
language: powershell
framework: powershell-5.1
agent: claude-sonnet
quality: 0.88
tags: powershell, if-expression, conditional-assignment, cast, syntax, ps51
---

## Prompt

No PowerShell 5.1, tentei usar if inline como argumento de cast: `$x = [double](if ($cond) { $val } else { 0.72 })`. Recebi o erro "O termo 'if' nao e reconhecido como nome de cmdlet". Como fazer atribuicao condicional com cast de tipo no PowerShell?

## Solution

O problema: no PowerShell, `if` e um statement, nao uma expressao. `[double](if ...)` tenta usar `if` como argumento para o operador de cast, o que e invalido — PS interpreta `if` como nome de comando e falha.

```powershell
# ERRADO: if nao e expressao, nao pode ser argumento de cast
$vecThreshold = [double](if ($cfg.vector_hub_threshold) {
    $cfg.vector_hub_threshold
} else { 0.72 })
# Erro: "O termo 'if' nao e reconhecido como nome de cmdlet"

# CORRETO opcao 1: if como statement de atribuicao (funciona em PS5.1+)
$vecThreshold = if ($cfg.vector_hub_threshold) {
    [double]$cfg.vector_hub_threshold
} else {
    0.72
}

# CORRETO opcao 2: operador ternario via subexpressao (PS5.1+)
$vecThreshold = [double]$(if ($cfg.vector_hub_threshold) {
    $cfg.vector_hub_threshold
} else { 0.72 })

# CORRETO opcao 3: logica de fallback com -or / null coalescing
$raw = $cfg.vector_hub_threshold
$vecThreshold = if ($raw) { [double]$raw } else { 0.72 }

# CORRETO opcao 4: PS7+ tem operador ternario real
# $vecThreshold = $cfg.vector_hub_threshold ? [double]$cfg.vector_hub_threshold : 0.72
# (nao disponivel no PS5.1)
```

No PS5.1, a forma mais clara e: `$var = if (cond) { val1 } else { val2 }` sem cast externo.

## Summary

PowerShell 5.1: `[type](if ...)` e invalido porque `if` e statement, nao expressao. Solucao: `$x = if ($cond) { [type]$val1 } else { $val2 }`. O `if` pode ser usado como statement de atribuicao direta, mas nao como argumento de operador de cast.
