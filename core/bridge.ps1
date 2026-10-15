# ============================================================================
# MeuTweaker - bridge.ps1
# Ponte entre a interface Electron (Node) e a logica real dos tweaks, que
# continua 100% em PowerShell (engine/tweaks/display/debloat/drivers/perfmon/
# scan/perfis - inalterados). Recebe uma acao + payload JSON (base64 UTF8) via
# argumentos de linha de comando e devolve SEMPRE uma unica linha JSON no
# stdout, prefixada por um marcador, para o processo Node conseguir separar o
# resultado de qualquer saida acidental (warnings, etc.).
# ============================================================================

param(
    [Parameter(Mandatory = $true)][string]$Action,
    [string]$PayloadB64 = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

$raiz = $PSScriptRoot
. (Join-Path $raiz 'engine.ps1')
. (Join-Path $raiz 'tweaks.ps1')
. (Join-Path $raiz 'display.ps1')
. (Join-Path $raiz 'debloat.ps1')
. (Join-Path $raiz 'drivers.ps1')
. (Join-Path $raiz 'perfmon.ps1')
. (Join-Path $raiz 'scan.ps1')
. (Join-Path $raiz 'perfis.ps1')

$script:Marcador = '###MT_RESULT###'

function Read-Payload {
    if (-not $PayloadB64) { return @{} }
    $bytes = [Convert]::FromBase64String($PayloadB64)
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    if (-not $json) { return @{} }
    return ConvertTo-HashtableRecursivo (ConvertFrom-Json $json)
}

function Write-Resultado($obj) {
    $json = $obj | ConvertTo-Json -Depth 12 -Compress
    Write-Output "$script:Marcador$json"
}

# Aplica uma lista de ids de tweak (checkbox marcados), na mesma ordem/regras
# da UI antiga: cria ponto de restauracao, pula os que exigem admin sem admin,
# executa os "unico" sempre, e os reversiveis so se ainda nao aplicados.
function Invoke-AplicarTweaks([string[]]$ids) {
    New-PontoRestauracao | Out-Null
    $idsSet = @{}
    foreach ($i in $ids) { $idsSet[$i] = $true }
    $erros = @(); $pulados = @(); $aplicados = @()
    foreach ($t in (Get-Tweaks)) {
        if (-not $idsSet[$t.id]) { continue }
        if ($t.admin -and -not (Test-Admin)) { $pulados += $t.nome; continue }
        if ($t.unico) {
            $r = Invoke-TweakUnico $t
        } elseif (-not (Test-TweakAplicado $t.id)) {
            $r = Invoke-Tweak $t
        } else {
            $aplicados += $t.nome
            continue
        }
        if ($r.ok) { $aplicados += $t.nome } else { $erros += @{ nome = $t.nome; detail = $r.detail } }
    }
    return @{ ok = $true; aplicados = $aplicados; erros = $erros; pulados = $pulados }
}

function Invoke-ReverterTweaks([string[]]$ids) {
    $idsSet = @{}
    foreach ($i in $ids) { $idsSet[$i] = $true }
    $revertidos = @(); $erros = @()
    foreach ($t in (Get-Tweaks)) {
        if ($t.unico) { continue }
        if (-not $idsSet[$t.id]) { continue }
        if (-not (Test-TweakAplicado $t.id)) { continue }
        $r = Revert-Tweak $t
        if ($r.ok) { $revertidos += $t.nome } else { $erros += @{ nome = $t.nome; detail = $r.detail } }
    }
    return @{ ok = $true; revertidos = $revertidos; erros = $erros }
}

function Get-Catalogo {
    $tweaks = @(Get-Tweaks | ForEach-Object {
        [ordered]@{
            id          = $_.id
            categoria   = $_.categoria
            nome        = $_.nome
            desc        = $_.desc
            admin       = [bool]$_.admin
            recomendado = [bool]$_.recomendado
            reboot      = [bool]$_.reboot
            unico       = [bool]$_.unico
            aplicado    = (Test-TweakAplicado $_.id)
        }
    })
    $perfis = @(Get-Perfis | ForEach-Object {
        [ordered]@{ id = $_.id; nome = $_.nome; icone = $_.icone; desc = $_.desc; tweaks = @($_.tweaks); revertAll = [bool]$_.revertAll }
    })
    return @{ ok = $true; isAdmin = (Test-Admin); tweaks = $tweaks; perfis = $perfis }
}

function Invoke-AplicarPerfil([string]$id) {
    $perfil = (Get-Perfis) | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $perfil) { return @{ ok = $false; detail = 'Perfil nao encontrado.' } }
    if ($perfil.revertAll) {
        $todosIds = @((Get-Tweaks) | Where-Object { -not $_.unico } | ForEach-Object { $_.id })
        $r = Invoke-ReverterTweaks $todosIds
        return @{ ok = $true; revertAll = $true; revertidos = $r.revertidos; erros = $r.erros }
    }
    return Invoke-AplicarTweaks $perfil.tweaks
}

function Invoke-RemoverDebloat([string[]]$matches) {
    if (-not (Test-Admin)) { return @{ ok = $false; detail = 'Exige administrador.' } }
    $resultados = @(Remove-AppsFabrica -selecionados $matches)
    return @{ ok = $true; resultados = $resultados }
}

function Invoke-BackupDrivers([string]$destino) {
    if (-not (Test-Admin)) { return @{ ok = $false; detail = 'Exige administrador.' } }
    return (Backup-Drivers $destino)
}

try {
    $payload = Read-Payload
    switch ($Action) {
        'test-admin'      { Write-Resultado @{ ok = $true; isAdmin = (Test-Admin) } }
        'get-catalog'      { Write-Resultado (Get-Catalogo) }
        'apply-tweaks'     { Write-Resultado (Invoke-AplicarTweaks @($payload.ids)) }
        'revert-tweaks'    { Write-Resultado (Invoke-ReverterTweaks @($payload.ids)) }
        'apply-perfil'     { Write-Resultado (Invoke-AplicarPerfil $payload.id) }
        'create-restore-point' { Write-Resultado (New-PontoRestauracao) }
        'get-debloat'      { Write-Resultado @{ ok = $true; apps = @(Get-AppsFabrica) } }
        'remove-debloat'   { Write-Resultado (Invoke-RemoverDebloat @($payload.matches)) }
        'get-drivers'      { Write-Resultado @{ ok = $true; drivers = @(Get-TodosDrivers); problemas = @(Get-DispositivosComProblema) } }
        'backup-drivers'   { Write-Resultado (Invoke-BackupDrivers $payload.destino) }
        'get-perf-static'  { Write-Resultado @{ ok = $true; info = (Get-InfoEstaticaDesempenho) } }
        'get-perf-live'    { Write-Resultado @{ ok = $true; amostra = (Get-AmostraDesempenho) } }
        'get-diagnostico'  { Write-Resultado @{ ok = $true; diagnostico = (Get-PotencialOtimizacao) } }
        default            { Write-Resultado @{ ok = $false; detail = "Acao desconhecida: $Action" } }
    }
} catch {
    Write-Resultado @{ ok = $false; detail = $_.Exception.Message }
}
