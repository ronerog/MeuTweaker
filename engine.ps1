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

# Converte o resultado de ConvertFrom-Json (PSCustomObject/Object[]) em
# Hashtable puro, recursivamente. Necessario porque -AsHashtable do
# ConvertFrom-Json so existe a partir do PowerShell 6 — o .exe gerado pelo
# ps2exe roda sobre o Windows PowerShell 5.1.
function ConvertTo-HashtableRecursivo($objeto) {
    if ($null -eq $objeto) { return $null }
    if ($objeto -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($chave in $objeto.Keys) { $h[$chave] = ConvertTo-HashtableRecursivo $objeto[$chave] }
        return $h
    }
    if ($objeto -is [string]) { return $objeto }
    if ($objeto -is [System.Collections.IEnumerable]) {
        return @($objeto | ForEach-Object { ConvertTo-HashtableRecursivo $_ })
    }
    if ($objeto -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($prop in $objeto.PSObject.Properties) { $h[$prop.Name] = ConvertTo-HashtableRecursivo $prop.Value }
        return $h
    }
    return $objeto
}

function Get-Estado {
    Initialize-Estado
    if (Test-Path $script:StatePath) {
        try {
            $json = Get-Content $script:StatePath -Raw | ConvertFrom-Json
            $estado = ConvertTo-HashtableRecursivo $json
            if (-not $estado.aplicados) { $estado.aplicados = @{} }
            return $estado
        }
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

# Executa um comando (string de PowerShell) e detecta falha de verdade.
# Por padrao, um erro de cmdlet (ex.: Set-Service sem privilegio de admin) e
# "nao terminal": ele imprime o erro mas a execucao CONTINUA e nao lanca
# excecao nenhuma - um try/catch comum nao percebe nada. Aqui a preferencia
# de erro e forcada para 'Stop' dentro de um escopo isolado (nao afeta o
# resto do app), entao qualquer linha do comando que nao tenha o proprio
# -ErrorAction silencioso passa a lancar excecao de verdade. Tambem checa o
# codigo de saida de comandos nativos (powercfg, fsutil, netsh, DISM...),
# que nunca lancam excecao do PowerShell por conta propria.
function Invoke-ComandoVerificado([string]$comando) {
    $saida = & {
        $ErrorActionPreference = 'Stop'
        Invoke-Expression $comando 2>&1
    } | Out-String
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Comando externo retornou codigo $LASTEXITCODE. Saida: $($saida.Trim())"
    }
    return $saida.Trim()
}

# Aplica um tweak do catalogo. Suporta regOps (lista de operacoes de registro,
# com leitura do valor anterior para permitir reversao) e/ou cmd (comando
# PowerShell direto, usado para acoes que nao sao de registro).
function Invoke-Tweak($tweak) {
    $estado = Get-Estado
    if (-not $estado.aplicados) { $estado.aplicados = @{} }

    if ($tweak.tipoEspecial -eq 'maxHz') {
        $info = Get-InfoMonitor
        if (-not $info) { return @{ id = $tweak.id; ok = $false; detail = 'Nao foi possivel ler o monitor.' } }
        if ($info.atual -ge $info.maximo) {
            $estado.aplicados[$tweak.id] = @{ em = (Get-Date).ToString('o'); backup = @{ hzAnterior = $info.atual } }
            Save-Estado $estado
            return @{ id = $tweak.id; ok = $true; detail = "Ja estava no maximo ($($info.maximo) Hz)."; noop = $true }
        }
        $r = Set-HzMonitor $info.maximo
        if (-not $r.ok) { return @{ id = $tweak.id; ok = $false; detail = $r.detail } }
        $estado.aplicados[$tweak.id] = @{ em = (Get-Date).ToString('o'); backup = @{ hzAnterior = $info.atual } }
        Save-Estado $estado
        return @{ id = $tweak.id; ok = $true; detail = "$($info.atual) Hz -> $($info.maximo) Hz" }
    }

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
            Invoke-ComandoVerificado $tweak.cmd | Out-Null
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

    if ($tweak.tipoEspecial -eq 'maxHz') {
        $anterior = $entrada.backup.hzAnterior
        if ($anterior) { Set-HzMonitor ([int]$anterior) | Out-Null }
        $estado.aplicados.Remove($tweak.id)
        Save-Estado $estado
        return @{ id = $tweak.id; ok = $true }
    }

    if ($entrada.backup.regOps) {
        Undo-RegOps $entrada.backup.regOps
    }
    if ($tweak.revertCmd) {
        try { Invoke-ComandoVerificado $tweak.revertCmd | Out-Null } catch {}
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
        $saida = Invoke-ComandoVerificado $tweak.cmd
        return @{ id = $tweak.id; ok = $true; detail = $saida }
    } catch {
        return @{ id = $tweak.id; ok = $false; detail = $_.Exception.Message }
    }
}
