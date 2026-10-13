# ============================================================================
# MeuTweaker - debloat.ps1
# Remocao de apps de fabrica (Appx) instalados pelo Windows/OEM. Exige admin.
# NAO e reversivel por este app: os apps podem ser reinstalados pela Microsoft
# Store depois, mas nao ha backup/estado salvo aqui (diferente dos tweaks de
# registro). Nunca toca em componentes de nucleo, Defender ou Windows Update.
# ============================================================================

$script:CatalogoDebloat = @(
    @{ id = 'BingWeather';   match = 'Microsoft.BingWeather';                     label = 'Clima (MSN Weather)' }
    @{ id = 'BingNews';      match = 'Microsoft.BingNews';                        label = 'Noticias (MSN News)' }
    @{ id = 'ZuneMusic';     match = 'Microsoft.ZuneMusic';                       label = 'Groove Musica' }
    @{ id = 'ZuneVideo';     match = 'Microsoft.ZuneVideo';                       label = 'Filmes e TV' }
    @{ id = 'Solitaire';     match = 'Microsoft.MicrosoftSolitaireCollection';    label = 'Solitaire Collection' }
    @{ id = 'People';        match = 'Microsoft.People';                          label = 'Pessoas' }
    @{ id = 'Maps';          match = 'Microsoft.WindowsMaps';                     label = 'Mapas' }
    @{ id = 'GetHelp';       match = 'Microsoft.GetHelp';                         label = 'Obter Ajuda' }
    @{ id = 'Feedback';      match = 'Microsoft.WindowsFeedbackHub';              label = 'Hub de Comentarios' }
    @{ id = 'Clipchamp';     match = 'Clipchamp.Clipchamp';                       label = 'Clipchamp (editor de video)' }
    @{ id = 'Todos';         match = 'Microsoft.Todos';                           label = 'Microsoft To Do' }
    @{ id = 'Family';        match = 'MicrosoftCorporationII.MicrosoftFamily';    label = 'Family Safety' }
    @{ id = 'Teams';         match = 'MicrosoftTeams';                            label = 'Teams / Chat pessoal' }
    @{ id = 'Copilot';       match = 'Microsoft.Copilot';                         label = 'Copilot'; aviso = 'IA da Microsoft.' }
    @{ id = 'Widgets';       match = 'MicrosoftWindows.Client.WebExperience';     label = 'Widgets'; aviso = 'Painel de noticias/clima do Windows 11.' }
    @{ id = 'Spotify';       match = 'SpotifyAB.SpotifyMusic';                    label = 'Spotify (versao da Store)' }
    @{ id = 'Xbox';          match = 'Microsoft.Xbox';                           label = 'Apps do Xbox'; aviso = 'NAO remova se usa Game Pass.' }
    @{ id = 'GamingApp';     match = 'Microsoft.GamingApp';                       label = 'Xbox (Gaming App)'; aviso = 'NAO remova se usa Game Pass.' }
    @{ id = 'MixedReality';  match = 'Microsoft.MixedReality.Portal';             label = 'Portal de Realidade Mista'; aviso = 'NAO remova se usa headset VR.' }
    @{ id = 'YourPhone';     match = 'Microsoft.YourPhone';                       label = 'Vinculo com o Celular'; aviso = 'Remova so se nao usa o Phone Link.' }
    @{ id = 'QuickAssist';   match = 'MicrosoftCorporationII.QuickAssist';        label = 'Assistencia Rapida' }
    @{ id = 'PowerAutomate'; match = 'Microsoft.PowerAutomateDesktop';            label = 'Power Automate' }
)

function Get-AppsFabrica {
    return $script:CatalogoDebloat | ForEach-Object {
        $instalado = [bool](Get-AppxPackage -Name "$($_.match)*" -ErrorAction SilentlyContinue)
        [pscustomobject]@{ id = $_.id; match = $_.match; label = $_.label; aviso = $_.aviso; instalado = $instalado }
    }
}

function Remove-AppsFabrica([string[]]$selecionados) {
    $resultados = @()
    foreach ($m in $selecionados) {
        $item = $script:CatalogoDebloat | Where-Object { $_.match -eq $m } | Select-Object -First 1
        if (-not $item) { continue }
        try { Get-AppxPackage -AllUsers -Name "$m*" -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction Stop }
        catch { $resultados += [pscustomobject]@{ id = $item.id; label = $item.label; ok = $false; detail = $_.Exception.Message }; continue }
        try { Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like "$m*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null } catch {}
        $restantes = @(Get-AppxPackage -Name "$m*" -ErrorAction SilentlyContinue).Count
        $resultados += [pscustomobject]@{ id = $item.id; label = $item.label; ok = ($restantes -eq 0); detail = $(if ($restantes -eq 0) { 'Removido.' } else { 'Nao foi totalmente removido.' }) }
    }
    return $resultados
}
