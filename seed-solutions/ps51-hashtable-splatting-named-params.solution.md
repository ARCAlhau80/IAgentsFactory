---
domain: powershell
pattern: syntax-fix
language: powershell
framework: powershell-5.1
agent: claude-sonnet
quality: 0.90
tags: powershell, splatting, hashtable, array, named-parameters, dynamic-args
---

## Prompt

No PowerShell, preciso chamar um script externo com parametros nomeados dinamicos (alguns opcionais). Usei um array $args com strings como "-Query", $value e fiz & $script @args, mas os parametros chegam como posicionais e nao como nomeados. Como passar parametros nomeados dinamicamente?

## Solution

O problema: `@array` faz splatting POSICIONAL — cada elemento do array e passado como argumento posicional separado. Entao `@("-Query", "valor")` passa a string `"-Query"` como primeiro argumento posicional e `"valor"` como segundo, nao como parametro nomeado `-Query valor`.

Fix: usar hashtable para splatting nomeado.

```powershell
# ERRADO: array splatting passa "-Query" como valor posicional
$args = @("-Query", $queryText)
if ($domain) { $args += @("-Domain", $domain) }
& $script @args
# O script recebe: $Query = "-Query" (primeiro posicional!) e "valor" sem destino

# CORRETO: hashtable splatting passa parametros nomeados
$splat = @{ Query = $queryText }
if ($domain)   { $splat["Domain"]   = $domain }
if ($language) { $splat["Language"] = $language }
if ($project)  { $splat["Project"]  = $project }
& $script @splat
# O script recebe: -Query "valor" -Domain "dom" etc. corretamente

# Regra: @array -> posicional | @hashtable -> nomeado
# Para parametros dinamicos nomeados, SEMPRE usar hashtable
```

Isso se aplica a chamadas de scripts, funcoes e cmdlets do PowerShell.

## Summary

No PowerShell, @array faz splatting posicional (cada elemento = arg posicional). Para passar parametros nomeados dinamicamente, usar @hashtable onde as chaves sao os nomes dos parametros. $splat = @{ ParamName = value }; & $cmd @splat.
