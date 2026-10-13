# ============================================================================
# MeuTweaker - tweaks.ps1
# Catalogo de ajustes. Cada item e uma tecnica de otimizacao do Windows
# publicamente conhecida (chaves de registro documentadas pela Microsoft ou
# comandos nativos como powercfg/netsh/DISM). Nada aqui depende de servidor,
# conta ou licenca externa.
# ============================================================================

$script:Tweaks = @(

    # ---------------- DESEMPENHO ----------------
    @{
        id = 'plano-energia-maximo'; categoria = 'Desempenho'
        nome = 'Plano de energia: Desempenho Maximo'
        desc = 'Ativa o plano Ultimate Performance (ou High Performance como alternativa).'
        admin = $false; recomendado = $true
        # GUID proprio e fixo para o plano duplicado: evita criar um novo plano a
        # cada aplicacao e nao depende do nome do plano (que e traduzido pelo
        # Windows - "Ultimate Performance" so existe em ingles; em pt-BR e
        # "Desempenho Maximo"). O template e identificado so pelo GUID, que e
        # fixo independente do idioma do sistema.
        cmd = "if (-not (powercfg /l | Select-String '9c3f3889-6c4a-4def-9e93-dcd13c88b8a6')) { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 9c3f3889-6c4a-4def-9e93-dcd13c88b8a6 | Out-Null }; powercfg /setactive 9c3f3889-6c4a-4def-9e93-dcd13c88b8a6; if (`$LASTEXITCODE -ne 0) { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c }"
        revertCmd = "powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e; powercfg -delete 9c3f3889-6c4a-4def-9e93-dcd13c88b8a6 2>`$null"
    }
    @{
        id = 'compactacao-memoria-off'; categoria = 'Desempenho'
        nome = 'Desativar compactacao de memoria'
        desc = 'Com RAM suficiente, remove a latencia de comprimir/descomprimir memoria. Exige reinicio.'
        admin = $true; reboot = $true
        cmd = 'Disable-MMAgent -MemoryCompression'
        revertCmd = 'Enable-MMAgent -MemoryCompression'
    }
    @{
        id = 'core-parking-off'; categoria = 'Desempenho'
        nome = 'Manter todos os nucleos ativos'
        desc = 'Desativa o core parking para resposta imediata da CPU (reduz economia de energia).'
        admin = $true
        cmd = 'powercfg /setacvalueindex scheme_current sub_processor CPMINCORES 100; powercfg /setdcvalueindex scheme_current sub_processor CPMINCORES 100; powercfg /setactive scheme_current'
        revertCmd = 'powercfg /setacvalueindex scheme_current sub_processor CPMINCORES 0; powercfg /setdcvalueindex scheme_current sub_processor CPMINCORES 0; powercfg /setactive scheme_current'
    }
    @{
        id = 'sysmain-off'; categoria = 'Desempenho'
        nome = 'Desligar SysMain (SuperFetch)'
        desc = 'Recomendado em SSD: para o pre-carregamento e libera RAM/disco.'
        admin = $true
        cmd = 'Stop-Service SysMain -Force -ErrorAction SilentlyContinue; Set-Service SysMain -StartupType Disabled'
        revertCmd = 'Set-Service SysMain -StartupType Automatic; Start-Service SysMain -ErrorAction SilentlyContinue'
    }
    @{
        id = 'indexacao-off'; categoria = 'Desempenho'
        nome = 'Desligar indexacao de arquivos (Windows Search)'
        desc = 'Libera CPU e disco desativando o indexador de busca.'
        admin = $true
        cmd = 'Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Set-Service WSearch -StartupType Disabled'
        revertCmd = 'Set-Service WSearch -StartupType Automatic; Start-Service WSearch -ErrorAction SilentlyContinue'
    }
    @{
        id = 'ultimo-acesso-ntfs-off'; categoria = 'Desempenho'
        nome = 'Desligar registro de ultimo acesso (NTFS)'
        desc = 'Menos escrita em disco a cada arquivo aberto.'
        admin = $true
        cmd = 'fsutil behavior set disablelastaccess 1'
        revertCmd = 'fsutil behavior set disablelastaccess 2'
    }
    @{
        id = 'hibernacao-off'; categoria = 'Desempenho'
        nome = 'Desativar hibernacao'
        desc = 'Remove o hiberfil.sys e libera espaco em disco (notebooks: avalie antes).'
        admin = $true
        cmd = 'powercfg /hibernate off'
        revertCmd = 'powercfg /hibernate on'
    }
    @{
        id = 'inicializacao-rapida-off'; categoria = 'Desempenho'
        nome = 'Desativar Inicializacao Rapida'
        desc = 'Evita problemas de driver/hardware causados pelo Fast Startup.'
        admin = $true
        regOps = @(@{ hive='HKLM'; chave='SYSTEM\CurrentControlSet\Control\Session Manager\Power'; nome='HiberbootEnabled'; tipo='DWord'; valor=0 })
    }

    # ---------------- JOGOS / INPUT ----------------
    @{
        id = 'game-mode-on'; categoria = 'Jogos'
        nome = 'Ativar Game Mode do Windows'
        desc = 'Prioriza o jogo e segura atualizacoes em segundo plano.'
        admin = $false; recomendado = $true
        regOps = @(@{ hive='HKCU'; chave='Software\Microsoft\GameBar'; nome='AutoGameModeEnabled'; tipo='DWord'; valor=1 })
    }
    @{
        id = 'hags-on'; categoria = 'Jogos'
        nome = 'Agendamento de GPU por hardware (HAGS)'
        desc = 'A GPU gerencia a propria fila de quadros, reduzindo latencia. Exige reinicio.'
        admin = $true; reboot = $true
        regOps = @(@{ hive='HKLM'; chave='SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; nome='HwSchMode'; tipo='DWord'; valor=2 })
    }
    @{
        id = 'prioridade-jogos'; categoria = 'Jogos'
        nome = 'Prioridade maxima para jogos'
        desc = 'Ajusta o perfil "Games" do sistema para priorizar GPU/CPU.'
        admin = $true
        regOps = @(
            @{ hive='HKLM'; chave='SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; nome='GPU Priority'; tipo='DWord'; valor=8 }
            @{ hive='HKLM'; chave='SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; nome='Priority'; tipo='DWord'; valor=6 }
            @{ hive='HKLM'; chave='SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; nome='Scheduling Category'; tipo='String'; valor='High' }
        )
    }
    @{
        id = 'mouse-sem-aceleracao'; categoria = 'Jogos'
        nome = 'Desativar aceleracao do mouse'
        desc = 'Resposta 1:1 do cursor, sem a curva de precisao do Windows.'
        admin = $false; recomendado = $true
        regOps = @(
            @{ hive='HKCU'; chave='Control Panel\Mouse'; nome='MouseSpeed'; tipo='String'; valor='0' }
            @{ hive='HKCU'; chave='Control Panel\Mouse'; nome='MouseThreshold1'; tipo='String'; valor='0' }
            @{ hive='HKCU'; chave='Control Panel\Mouse'; nome='MouseThreshold2'; tipo='String'; valor='0' }
        )
    }
    @{
        id = 'game-dvr-off'; categoria = 'Jogos'
        nome = 'Desativar gravacao em segundo plano (Game DVR)'
        desc = 'Impede a Xbox Game Bar de gravar em background consumindo FPS.'
        admin = $false; recomendado = $true
        regOps = @(
            @{ hive='HKCU'; chave='System\GameConfigStore'; nome='GameDVR_Enabled'; tipo='DWord'; valor=0 }
            @{ hive='HKCU'; chave='SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; nome='AppCaptureEnabled'; tipo='DWord'; valor=0 }
        )
    }
    @{
        id = 'sticky-keys-off'; categoria = 'Jogos'
        nome = 'Desativar popups de teclas de aderencia'
        desc = 'Evita a janela de Sticky Keys ao apertar Shift 5x.'
        admin = $false
        regOps = @(
            @{ hive='HKCU'; chave='Control Panel\Accessibility\StickyKeys'; nome='Flags'; tipo='String'; valor='506' }
            @{ hive='HKCU'; chave='Control Panel\Accessibility\ToggleKeys'; nome='Flags'; tipo='String'; valor='58' }
            @{ hive='HKCU'; chave='Control Panel\Accessibility\Keyboard Response'; nome='Flags'; tipo='String'; valor='122' }
        )
    }

    # ---------------- REDE ----------------
    @{
        id = 'limitacao-rede-off'; categoria = 'Rede'
        nome = 'Remover limitacao de rede (throttling)'
        desc = 'Remove o limite de pacotes por milissegundo do perfil multimidia.'
        admin = $true; recomendado = $true
        regOps = @(@{ hive='HKLM'; chave='SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; nome='NetworkThrottlingIndex'; tipo='DWord'; valor=0xffffffff })
    }
    @{
        id = 'responsividade-sistema'; categoria = 'Rede'
        nome = 'Responsividade do sistema para jogos'
        desc = 'Reduz a reserva de CPU para tarefas de fundo, de 20% para 10%.'
        admin = $true; recomendado = $true
        regOps = @(@{ hive='HKLM'; chave='SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; nome='SystemResponsiveness'; tipo='DWord'; valor=10 })
    }
    @{
        id = 'flush-dns'; categoria = 'Rede'
        nome = 'Limpar cache de DNS'
        desc = 'Resolve lentidao de conexao por cache de DNS desatualizado.'
        admin = $false; unico = $true
        cmd = 'ipconfig /flushdns'
    }

    # ---------------- PRIVACIDADE ----------------
    @{
        id = 'telemetria-minima'; categoria = 'Privacidade'
        nome = 'Telemetria do Windows no minimo'
        desc = 'Reduz o envio de dados de diagnostico a Microsoft.'
        admin = $true
        regOps = @(@{ hive='HKLM'; chave='SOFTWARE\Policies\Microsoft\Windows\DataCollection'; nome='AllowTelemetry'; tipo='DWord'; valor=0 })
    }
    @{
        id = 'diagtrack-manual'; categoria = 'Privacidade'
        nome = 'Servico de telemetria (DiagTrack) para Manual'
        desc = 'Para o servico sem desativar por completo (mantem estabilidade).'
        admin = $true
        cmd = 'Set-Service DiagTrack -StartupType Manual -ErrorAction SilentlyContinue; Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue'
        revertCmd = 'Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service DiagTrack -ErrorAction SilentlyContinue'
    }
    @{
        id = 'id-publicidade-off'; categoria = 'Privacidade'
        nome = 'Desativar ID de publicidade'
        desc = 'Impede que apps usem seu ID de anuncios para rastreamento entre apps.'
        admin = $false; recomendado = $true
        regOps = @(@{ hive='HKCU'; chave='SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; nome='Enabled'; tipo='DWord'; valor=0 })
    }
    @{
        id = 'historico-atividades-off'; categoria = 'Privacidade'
        nome = 'Desligar historico de atividades'
        desc = 'Para a coleta/sincronizacao da Linha do Tempo com a conta Microsoft.'
        admin = $true; recomendado = $true
        regOps = @(
            @{ hive='HKLM'; chave='SOFTWARE\Policies\Microsoft\Windows\System'; nome='EnableActivityFeed'; tipo='DWord'; valor=0 }
            @{ hive='HKLM'; chave='SOFTWARE\Policies\Microsoft\Windows\System'; nome='PublishUserActivities'; tipo='DWord'; valor=0 }
            @{ hive='HKLM'; chave='SOFTWARE\Policies\Microsoft\Windows\System'; nome='UploadUserActivities'; tipo='DWord'; valor=0 }
        )
    }
    @{
        id = 'relatorio-erros-off'; categoria = 'Privacidade'
        nome = 'Desativar relatorio de erros'
        desc = 'Para o envio automatico de relatorios de erro a Microsoft.'
        admin = $true
        regOps = @(@{ hive='HKLM'; chave='SOFTWARE\Microsoft\Windows\Windows Error Reporting'; nome='Disabled'; tipo='DWord'; valor=1 })
    }

    # ---------------- APARENCIA ----------------
    @{
        id = 'efeitos-visuais-desempenho'; categoria = 'Aparencia'
        nome = 'Efeitos visuais: priorizar desempenho'
        desc = 'Desativa animacoes e sombras para aliviar a GPU fora do jogo.'
        admin = $false
        regOps = @(@{ hive='HKCU'; chave='Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; nome='VisualFXSetting'; tipo='DWord'; valor=2 })
    }
    @{
        id = 'transparencia-off'; categoria = 'Aparencia'
        nome = 'Desativar transparencias'
        desc = 'Remove o efeito acrilico da interface.'
        admin = $false
        regOps = @(@{ hive='HKCU'; chave='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; nome='EnableTransparency'; tipo='DWord'; valor=0 })
    }
    @{
        id = 'notificacoes-off'; categoria = 'Aparencia'
        nome = 'Desativar notificacoes (toasts)'
        desc = 'Remove os popups de notificacao do sistema.'
        admin = $false
        regOps = @(@{ hive='HKCU'; chave='SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications'; nome='ToastEnabled'; tipo='DWord'; valor=0 })
    }

    # ---------------- LIMPEZA (acao unica) ----------------
    @{
        id = 'limpar-temp'; categoria = 'Limpeza'
        nome = 'Limpar arquivos temporarios'
        desc = 'Remove o conteudo de %TEMP% e da pasta Temp do Windows.'
        admin = $false; unico = $true; recomendado = $true
        cmd = 'Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue'
    }
    @{
        id = 'limpar-prefetch'; categoria = 'Limpeza'
        nome = 'Limpar Prefetch'
        desc = 'Esvazia a pasta Prefetch (o Windows recria o que precisar).'
        admin = $true; unico = $true
        cmd = 'Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue'
    }
    @{
        id = 'esvaziar-lixeira'; categoria = 'Limpeza'
        nome = 'Esvaziar a Lixeira'
        desc = 'Libera espaco em disco. O conteudo e apagado em definitivo.'
        admin = $false; unico = $true
        cmd = 'Clear-RecycleBin -Force -ErrorAction SilentlyContinue'
    }
)

function Get-Tweaks { return $script:Tweaks }
function Find-Tweak([string]$id) { return $script:Tweaks | Where-Object { $_.id -eq $id } | Select-Object -First 1 }
function Get-TweaksRecomendados { return $script:Tweaks | Where-Object { $_.recomendado } }
