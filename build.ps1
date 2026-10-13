# ============================================================================
# MeuTweaker - build.ps1
# Empacota MeuTweaker.ps1 (+ engine.ps1 + tweaks.ps1, dot-sourced em tempo de
# execucao a partir da pasta do exe) em um executavel unico usando ps2exe
# (https://github.com/MScholtes/PS2EXE), modulo open-source do PowerShell
# Gallery. Nao baixa nada alem do proprio modulo ps2exe.
# ============================================================================

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host 'Instalando o modulo ps2exe (PowerShell Gallery, escopo do usuario atual)...'
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe

$raiz = $PSScriptRoot
$dist = Join-Path $raiz 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null

# Mescla os tres scripts num unico arquivo, removendo as linhas de dot-source,
# para que o .exe final seja autocontido (nao dependa de arquivos ao lado).
$engine    = Get-Content (Join-Path $raiz 'engine.ps1') -Raw
$tweaks    = Get-Content (Join-Path $raiz 'tweaks.ps1') -Raw
$principal = Get-Content (Join-Path $raiz 'MeuTweaker.ps1') -Raw
$principal = $principal -replace '(?m)^\s*\.\s*\(Join-Path \$raiz ''engine\.ps1''\)\s*$', '' `
                         -replace '(?m)^\s*\.\s*\(Join-Path \$raiz ''tweaks\.ps1''\)\s*$', ''

$mesclado = Join-Path $dist '_mesclado.ps1'
Set-Content -Path $mesclado -Value ($engine + "`n" + $tweaks + "`n" + $principal) -Encoding UTF8

Invoke-ps2exe `
    -inputFile  $mesclado `
    -outputFile (Join-Path $dist 'MeuTweaker.exe') `
    -title 'MeuTweaker' `
    -product 'MeuTweaker' `
    -description 'Otimizador de Windows pessoal (sem login, sem telemetria)' `
    -version '1.0.0.0' `
    -noConsole `
    -requireAdmin

Write-Host "Pronto: $(Join-Path $dist 'MeuTweaker.exe')"
Write-Host 'Observacao: por ser um executavel novo e sem assinatura digital, o Windows'
Write-Host 'SmartScreen pode exibir um alerta na primeira execucao ("Mais informacoes" ->'
Write-Host '"Executar assim mesmo"). Isso e esperado para qualquer exe nao assinado e nao'
Write-Host 'indica malware - veja o README.'
