# ============================================================================
# MeuTweaker - scan.ps1
# Diagnostico: mede o que ainda da para otimizar NESTA maquina, sondando o
# estado real do Windows. Nao altera nada. Retorna um "potencial de
# otimizacao" de 0 a 100 com a lista do que foi encontrado.
# ============================================================================

function Get-PotencialOtimizacao {
    $ErrorActionPreference = 'SilentlyContinue'
    function Valor($caminho, $nome) { try { (Get-ItemProperty -Path $caminho -Name $nome -ErrorAction Stop).$nome } catch { $null } }
    function StatusServico($nome) { try { (Get-Service -Name $nome -ErrorAction Stop).Status.ToString() } catch { 'ausente' } }

    $fx         = Valor 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting'
    $transp     = Valor 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency'
    $telemetria = Valor 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
    $diagtrack  = StatusServico 'DiagTrack'
    $sysmain    = StatusServico 'SysMain'
    $busca      = StatusServico 'WSearch'
    $gamedvr    = Valor 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
    $gamemode   = Valor 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
    $hiberna    = if (Test-Path "$env:SystemDrive\hiberfil.sys") { 1 } else { 0 }
    $mouse      = (Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseSpeed -ErrorAction SilentlyContinue).MouseSpeed
    $energia    = ((powercfg /getactivescheme) -join ' ')

    $inicio = 0
    foreach ($h in 'HKCU:', 'HKLM:') {
        $p = Join-Path $h 'Software\Microsoft\Windows\CurrentVersion\Run'
        if (Test-Path $p) { $inicio += @((Get-Item $p).GetValueNames() | Where-Object { $_ -ne '' }).Count }
    }

    $tempBytes = (Get-ChildItem "$env:TEMP\*", "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $tempGb = if ($tempBytes) { [math]::Round($tempBytes / 1GB, 2) } else { 0 }

    $drive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
    $discoUsoPct = if ($drive -and ($drive.Used + $drive.Free) -gt 0) { [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 0) } else { 0 }

    $sondas = @(
        @{ peso = 4; rotulo = 'Efeitos visuais no maximo';               ruim = ([int]$fx -ne 2) }
        @{ peso = 2; rotulo = 'Transparencia ligada';                    ruim = ([int]$transp -eq 1) }
        @{ peso = 4; rotulo = 'Telemetria no nivel cheio';               ruim = (($null -eq $telemetria) -or ([int]$telemetria -gt 1)) }
        @{ peso = 5; rotulo = 'Servico de telemetria (DiagTrack) rodando'; ruim = ($diagtrack -eq 'Running') }
        @{ peso = 5; rotulo = 'SysMain rodando';                         ruim = ($sysmain -eq 'Running') }
        @{ peso = 4; rotulo = 'Indexacao de arquivos ativa';             ruim = ($busca -eq 'Running') }
        @{ peso = 5; rotulo = 'Game DVR ligado';                         ruim = ([int]$gamedvr -eq 1) }
        @{ peso = 3; rotulo = 'Modo Jogo desligado';                     ruim = ([int]$gamemode -ne 1) }
        @{ peso = 3; rotulo = 'Hibernacao ocupando espaco em disco';     ruim = ([int]$hiberna -eq 1) }
        @{ peso = 4; rotulo = 'Aceleracao do mouse ligada';              ruim = ([string]$mouse -ne '0') }
        @{ peso = 6; rotulo = 'Plano de energia nao e o de desempenho';  ruim = -not ($energia -match '(?i)(alto desempenho|high performance|ultimate|desempenho m.ximo)') }
    )

    $achados = @()
    $pontos = 0; $total = 0
    foreach ($s in $sondas) {
        $total += $s.peso
        if ($s.ruim) { $pontos += $s.peso; $achados += $s.rotulo }
    }

    $pesoInicio = 14; $total += $pesoInicio
    if ($inicio -gt 4) {
        $pontos += [math]::Min($pesoInicio, [math]::Round((($inicio - 4) / 10.0) * $pesoInicio))
        $achados += "$inicio programas abrem junto com o Windows"
    }

    $pesoLixo = 10; $total += $pesoLixo
    if ($tempGb -ge 0.5) {
        $pontos += [math]::Min($pesoLixo, [math]::Round(($tempGb / 8.0) * $pesoLixo))
        $achados += "$tempGb GB em arquivos temporarios"
    }

    $pesoDisco = 8; $total += $pesoDisco
    if ($discoUsoPct -ge 85) {
        $pontos += $pesoDisco
        $achados += "Disco do sistema em $discoUsoPct% de uso"
    }

    $percentual = if ($total -gt 0) { [math]::Round(($pontos / $total) * 100) } else { 0 }
    return @{ potencial = $percentual; achados = $achados }
}
