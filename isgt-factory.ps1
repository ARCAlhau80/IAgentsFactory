param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$ForwardArgs
)

$newScript = Join-Path $PSScriptRoot 'iagents-factory.ps1'
if (-not (Test-Path $newScript)) {
    Write-Error 'Compat wrapper falhou: iagents-factory.ps1 nao encontrado.'
    exit 1
}

Write-Warning 'isgt-factory.ps1 foi mantido apenas por compatibilidade. Use iagents-factory.ps1.'
& $newScript @ForwardArgs
exit $LASTEXITCODE
