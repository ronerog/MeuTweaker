# ============================================================================
# MeuTweaker - drivers.ps1
# Inventario de drivers, dispositivos com problema, e backup de drivers de
# terceiros para uma pasta. NAO baixa nenhum driver de lugar nenhum.
# ============================================================================

function Get-TodosDrivers {
    $ErrorActionPreference = 'SilentlyContinue'
    $dados = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceName } | ForEach-Object {
        [pscustomobject]@{
            nome       = $_.DeviceName
            versao     = $_.DriverVersion
            data       = $(if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } else { '' })
            fornecedor = $_.DriverProviderName
            classe     = $_.DeviceClass
        }
    }
    $mapa = @{}
    foreach ($d in $dados) {
        $chave = "$($d.nome)|$($d.versao)|$($d.fornecedor)"
        if ($mapa.ContainsKey($chave)) { $mapa[$chave].contagem++ }
        else { $mapa[$chave] = [pscustomobject]@{ nome = $d.nome; versao = $d.versao; data = $d.data; fornecedor = $d.fornecedor; classe = $d.classe; contagem = 1 } }
    }
    return @($mapa.Values | Sort-Object classe, nome)
}

function Get-DispositivosComProblema {
    $ErrorActionPreference = 'SilentlyContinue'
    return @(Get-PnpDevice -PresentOnly | Where-Object { $_.Status -ne 'OK' -and $_.Class } |
        Select-Object @{n = 'nome'; e = { $_.FriendlyName } }, @{n = 'classe'; e = { $_.Class } }, @{n = 'status'; e = { $_.Status } })
}

function Backup-Drivers([string]$destino) {
    if (-not $destino) { return @{ ok = $false; detail = 'Pasta invalida.' } }
    if (-not (Test-Path $destino)) { New-Item -ItemType Directory -Path $destino -Force | Out-Null }
    try {
        $r = & { $ErrorActionPreference = 'Stop'; Export-WindowsDriver -Online -Destination $destino }
        return @{ ok = $true; quantidade = @($r).Count; destino = $destino }
    } catch {
        return @{ ok = $false; detail = $_.Exception.Message }
    }
}
