# ============================================================================
# MeuTweaker - perfis.ps1
# Conjuntos nomeados de ajustes do catalogo (tweaks.ps1), para aplicar varios
# de uma vez. 'revertAll' marca o perfil especial que desfaz tudo.
# ============================================================================

$script:Perfis = @(
    @{
        id = 'competitivo'; nome = 'Competitivo Total'; icone = '⚡'
        desc = 'Maximo FPS e minimo input lag. Sacrifica visual do Windows em nome de cada frame.'
        tweaks = @('monitor-max-hz', 'plano-energia-maximo', 'game-mode-on', 'hags-on', 'prioridade-jogos',
            'mouse-sem-aceleracao', 'game-dvr-off', 'sticky-keys-off', 'limitacao-rede-off', 'responsividade-sistema',
            'apps-background-off', 'edge-preload-off', 'compactacao-memoria-off', 'efeitos-visuais-desempenho',
            'transparencia-off', 'limpar-temp', 'flush-dns', 'standby-list')
    }
    @{
        id = 'equilibrado'; nome = 'Equilibrado'; icone = '🎯'
        desc = 'O essencial de FPS e input lag, sem mudar a aparencia do Windows.'
        tweaks = @('monitor-max-hz', 'plano-energia-maximo', 'game-mode-on', 'hags-on', 'prioridade-jogos',
            'mouse-sem-aceleracao', 'game-dvr-off', 'sticky-keys-off', 'limitacao-rede-off', 'responsividade-sistema',
            'apps-background-off', 'limpar-temp', 'flush-dns')
    }
    @{
        id = 'pc-modesto'; nome = 'PC Modesto'; icone = '🪫'
        desc = 'Para maquinas com pouca RAM e GPU fraca: corta peso visual e processos de fundo.'
        tweaks = @('plano-energia-maximo', 'efeitos-visuais-desempenho', 'transparencia-off', 'apps-background-off',
            'edge-preload-off', 'sugestoes-off', 'game-dvr-off', 'standby-list', 'limpar-temp', 'flush-dns')
    }
    @{
        id = 'privacidade'; nome = 'Privacidade Maxima'; icone = '🛡️'
        desc = 'Telemetria, rastreamento e conteudo promocional desligados, sem tocar em desempenho.'
        tweaks = @('telemetria-minima', 'telemetria-compatibilidade-off', 'conteudo-promocional-off',
            'historico-atividades-off', 'relatorio-erros-off', 'localizacao-off', 'busca-nuvem-off',
            'id-publicidade-off', 'apps-background-off', 'copilot-off', 'busca-bing-off', 'sugestoes-off')
    }
    @{
        id = 'padrao'; nome = 'Padrao Windows'; icone = '↩️'
        desc = 'Reverte TODAS as otimizacoes aplicadas pelo MeuTweaker e devolve o Windows ao estado original.'
        revertAll = $true; tweaks = @()
    }
)

function Get-Perfis { return $script:Perfis }
