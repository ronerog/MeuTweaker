# ============================================================================
# MeuTweaker - engine.ps1
# Motor de aplicacao/reversao de ajustes do Windows.
# Projeto proprio e independente: implementa tecnicas de tweak de Windows
# publicamente documentadas (registro e comandos nativos do sistema).
# Nao contem login, telemetria ou qualquer servico de terceiros.
# ============================================================================

$script:StateDir  = Join-Path $env:LOCALAPPDATA 'MeuTweaker'
$script:StatePath = Join-Path $script:StateDir 'state.json'
$script:Ausente   = '__AUSENTE__'

function Initialize-Estado {
    if (-not (Test-Path $script:StateDir)) {
        New-Item -ItemType Directory -Path $script:StateDir -Force | Out-Null
    }
}

function Get-Estado {
    Initialize-Estado
    if (Test-Path $script:StatePath) {
        try { return Get-Content $script:StatePath -Raw | ConvertFrom-Json -AsHashtable }
        catch { return @{ aplicados = @{} } }
    }
    return @{ aplicados = @{} }
}

function Save-Estado([hashtable]$estado) {
    Initialize-Estado
    ($estado | ConvertTo-Json -Depth 10) | Set-Content -Path $script:StatePath -Encoding UTF8
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-PontoRestauracao {
    try {
        $estado = Get-Estado
        if ($estado.restorePointAt) {
            $ultimo = [DateTime]::Parse($estado.restorePointAt)
            if (((Get-Date) - $ultimo).TotalHours -lt 24) {
                return @{ ok = $true; skipped = $true; detail = 'Ponto de restauracao recente ja existe.' }
            }
        }
        Checkpoint-Computer -Description 'MeuTweaker - antes da otimizacao' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $estado.restorePointAt = (Get-Date).ToString('o')
        Save-Estado $estado
        return @{ ok = $true; detail = 'Ponto de restauracao criado.' }
    } catch {
        return @{ ok = $false; detail = "Falha ao criar ponto de restauracao: $($_.Exception.Message)" }
    }
}

# ---------- registro: leitura/escrita com backup para reversao ----------

function Get-ValorRegistro([string]$hive, [string]$chave, [string]$nome) {
    $caminho = "$hive`:\$chave"
    try {
        if (-not (Test-Path $caminho)) { return $script:Ausente }
        $item = Get-ItemProperty -Path $caminho -Name $nome -ErrorAction Stop
        return $item.$nome
    } catch { return $script:Ausente }
}

function Set-ValorRegistro([string]$hive, [string]$chave, [string]$nome, [string]$tipo, $valor) {
    $caminho = "$hive`:\$chave"
    try {
        if (-not (Test-Path $caminho)) { New-Item -Path $caminho -Force | Out-Null }
        Set-ItemProperty -Path $caminho -Name $nome -Value $valor -Type $tipo -ErrorAction Stop
        return @{ ok = $true }
    } catch {
        return @{ ok = $false; detail = $_.Exception.Message }
    }
}

function Remove-ValorRegistro([string]$hive, [string]$chave, [string]$nome) {
    $caminho = "$hive`:\$chave"
    try {
        Remove-ItemProperty -Path $caminho -Name $nome -ErrorAction SilentlyContinue
        return @{ ok = $true }
    } catch { return @{ ok = $true } }
}

# Aplica um tweak do catalogo. Suporta regOps (lista de operacoes de registro,
# com leitura do valor anterior para permitir reversao) e/ou cmd (comando
# PowerShell direto, usado para acoes que nao sao de registro).
function Invoke-Tweak($tweak) {
    $estado = Get-Estado
    if (-not $estado.aplicados) { $estado.aplicados = @{} }

    $backup = @{ regOps = @() }

    if ($tweak.regOps) {
        foreach ($op in $tweak.regOps) {
            $anterior = Get-ValorRegistro $op.hive $op.chave $op.nome
            $backup.regOps += @{ hive = $op.hive; chave = $op.chave; nome = $op.nome; tipo = $op.tipo; anterior = $anterior }
            $r = Set-ValorRegistro $op.hive $op.chave $op.nome $op.tipo $op.valor
            if (-not $r.ok) {
                Undo-RegOps $backup.regOps
                return @{ id = $tweak.id; ok = $false; detail = "Falha ao gravar registro: $($r.detail)" }
            }
        }
    }

    if ($tweak.cmd) {
        try {
            Invoke-Expression $tweak.cmd | Out-Null
        } catch {
            Undo-RegOps $backup.regOps
            return @{ id = $tweak.id; ok = $false; detail = "Falha ao executar comando: $($_.Exception.Message)" }
        }
    }

    $estado.aplicados[$tweak.id] = @{ em = (Get-Date).ToString('o'); backup = $backup }
    Save-Estado $estado
    return @{ id = $tweak.id; ok = $true; reboot = [bool]$tweak.reboot }
}

function Undo-RegOps($regOps) {
    foreach ($op in $regOps) {
        if ($op.anterior -eq $script:Ausente) {
            Remove-ValorRegistro $op.hive $op.chave $op.nome | Out-Null
        } else {
            Set-ValorRegistro $op.hive $op.chave $op.nome $op.tipo $op.anterior | Out-Null
        }
    }
}

function Revert-Tweak($tweak) {
    $estado = Get-Estado
    if (-not $estado.aplicados) { $estado.aplicados = @{} }
    $entrada = $estado.aplicados[$tweak.id]
    if (-not $entrada) { return @{ id = $tweak.id; ok = $true; detail = 'Nada a reverter.' } }

    if ($entrada.backup.regOps) {
        Undo-RegOps $entrada.backup.regOps
    }
    if ($tweak.revertCmd) {
        try { Invoke-Expression $tweak.revertCmd | Out-Null } catch {}
    }

    $estado.aplicados.Remove($tweak.id)
    Save-Estado $estado
    return @{ id = $tweak.id; ok = $true }
}

function Test-TweakAplicado($id) {
    $estado = Get-Estado
    return [bool]($estado.aplicados -and $estado.aplicados[$id])
}

# Executa uma unica vez (limpeza etc.), sem estado reversivel.
function Invoke-TweakUnico($tweak) {
    try {
        $saida = Invoke-Expression $tweak.cmd 2>&1 | Out-String
        return @{ id = $tweak.id; ok = $true; detail = $saida.Trim() }
    } catch {
        return @{ id = $tweak.id; ok = $false; detail = $_.Exception.Message }
    }
}
