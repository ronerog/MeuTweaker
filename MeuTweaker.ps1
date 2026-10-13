# ============================================================================
# MeuTweaker - ponto de entrada (GUI)
# App proprio de otimizacao do Windows. Sem login, sem telemetria, sem
# servidor externo. Todo ajuste reversivel salva backup automatico em
# %LOCALAPPDATA%\MeuTweaker\state.json e cria ponto de restauracao no
# primeiro uso.
# ============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$raiz = $PSScriptRoot
. (Join-Path $raiz 'engine.ps1')
. (Join-Path $raiz 'tweaks.ps1')
. (Join-Path $raiz 'display.ps1')
. (Join-Path $raiz 'debloat.ps1')
. (Join-Path $raiz 'drivers.ps1')
. (Join-Path $raiz 'perfmon.ps1')
. (Join-Path $raiz 'scan.ps1')
. (Join-Path $raiz 'perfis.ps1')

$CorFundo = [System.Drawing.Color]::FromArgb(17, 16, 20)
$CorFundoBarra = [System.Drawing.Color]::FromArgb(24, 23, 28)
$CorTexto = [System.Drawing.Color]::White
$CorTextoFraco = [System.Drawing.Color]::Gainsboro

# ---------- janela principal ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'MeuTweaker'
$form.Size = New-Object System.Drawing.Size(700, 760)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $CorFundo
$form.ForeColor = $CorTexto
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$titulo = New-Object System.Windows.Forms.Label
$titulo.Text = if (Test-Admin) { 'MeuTweaker  (administrador)' } else { 'MeuTweaker  (sem privilegios de administrador)' }
$titulo.AutoSize = $false
$titulo.Dock = 'Top'
$titulo.Height = 32
$titulo.TextAlign = 'MiddleLeft'
$titulo.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$form.Controls.Add($titulo)

$barraBotoes = New-Object System.Windows.Forms.FlowLayoutPanel
$barraBotoes.Dock = 'Bottom'
$barraBotoes.Height = 50
$barraBotoes.BackColor = $CorFundoBarra
$form.Controls.Add($barraBotoes)

$abas = New-Object System.Windows.Forms.TabControl
$abas.Dock = 'Fill'
$form.Controls.Add($abas)

function Mostrar-Status([string]$texto) {
    $titulo.Text = $texto
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

# ============================================================================
# ABA 1: Ajustes (perfis + catalogo categorizado)
# ============================================================================
$abaAjustes = New-Object System.Windows.Forms.TabPage
$abaAjustes.Text = 'Ajustes'
$abaAjustes.BackColor = $CorFundo
$abas.TabPages.Add($abaAjustes)

$painelPerfis = New-Object System.Windows.Forms.FlowLayoutPanel
$painelPerfis.Dock = 'Top'
$painelPerfis.Height = 40
$painelPerfis.BackColor = $CorFundo
$abaAjustes.Controls.Add($painelPerfis)

$painel = New-Object System.Windows.Forms.FlowLayoutPanel
$painel.Dock = 'Fill'
$painel.AutoScroll = $true
$painel.FlowDirection = 'TopDown'
$painel.WrapContents = $false
$painel.BackColor = $CorFundo
$abaAjustes.Controls.Add($painel)

$checkboxes = @{}

function Add-Secao([string]$nomeCategoria) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $nomeCategoria
    $lbl.AutoSize = $true
    $lbl.ForeColor = $CorTexto
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $lbl.Margin = New-Object System.Windows.Forms.Padding(8, 14, 0, 4)
    $painel.Controls.Add($lbl)
}

function Add-LinhaTweak($tweak) {
    $linha = New-Object System.Windows.Forms.Panel
    $linha.Width = 640
    $linha.Height = 42
    $linha.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $tweak.nome + $(if ($tweak.admin) { '  [admin]' } else { '' })
    $cb.AutoSize = $true
    $cb.Location = New-Object System.Drawing.Point(0, 0)
    $cb.Checked = (Test-TweakAplicado $tweak.id)
    $cb.ForeColor = $CorTexto
    $linha.Controls.Add($cb)
    $checkboxes[$tweak.id] = $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = $tweak.desc
    $desc.AutoSize = $false
    $desc.Width = 630
    $desc.Height = 18
    $desc.Location = New-Object System.Drawing.Point(20, 20)
    $desc.ForeColor = $CorTextoFraco
    $desc.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $linha.Controls.Add($desc)

    $painel.Controls.Add($linha)
}

$categorias = ($script:Tweaks | Where-Object { -not $_.unico } | ForEach-Object { $_.categoria }) | Select-Object -Unique
foreach ($cat in $categorias) {
    Add-Secao $cat
    foreach ($t in ($script:Tweaks | Where-Object { $_.categoria -eq $cat -and -not $_.unico })) {
        Add-LinhaTweak $t
    }
}

Add-Secao 'Limpeza (acao imediata, nao reversivel)'
foreach ($t in ($script:Tweaks | Where-Object { $_.unico })) {
    Add-LinhaTweak $t
}

$script:botoesAcao = @()
function Set-BotoesHabilitados([bool]$habilitado) {
    foreach ($b in $script:botoesAcao) { $b.Enabled = $habilitado }
}

function Restart-ComoAdmin {
    $exeAtual = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    try {
        if ($exeAtual -match '\\(powershell|pwsh)(\.exe)?$' -and $PSCommandPath) {
            Start-Process -FilePath $exeAtual -ArgumentList @('-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") -Verb RunAs | Out-Null
        } else {
            Start-Process -FilePath $exeAtual -Verb RunAs | Out-Null
        }
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Nao foi possivel reiniciar como administrador: $($_.Exception.Message)", 'MeuTweaker') | Out-Null
    }
}

function Aplicar-Selecionados {
    Set-BotoesHabilitados $false
    try {
        New-PontoRestauracao | Out-Null
        $erros = @()
        $puloPorAdmin = @()
        foreach ($t in $script:Tweaks) {
            $cb = $checkboxes[$t.id]
            if (-not $cb -or -not $cb.Checked) { continue }
            if ($t.admin -and -not (Test-Admin)) { $puloPorAdmin += $t.nome; continue }
            Mostrar-Status "Aplicando: $($t.nome)..."
            if ($t.unico) {
                $r = Invoke-TweakUnico $t
            } elseif (-not (Test-TweakAplicado $t.id)) {
                $r = Invoke-Tweak $t
            } else { continue }
            if (-not $r.ok) { $erros += "$($t.nome): $($r.detail)" }
        }
        Mostrar-Status 'MeuTweaker'

        $partes = @()
        if ($erros.Count -gt 0) { $partes += "Falharam:`n - " + ($erros -join "`n - ") }
        if ($puloPorAdmin.Count -gt 0) {
            $partes += "Precisam de administrador (nao aplicados):`n - " + ($puloPorAdmin -join "`n - ") + "`n`nReinicie o MeuTweaker como administrador para aplicar estes."
        }
        if ($partes.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Ajustes aplicados.', 'MeuTweaker') | Out-Null
        } else {
            [System.Windows.Forms.MessageBox]::Show(($partes -join "`n`n"), 'MeuTweaker') | Out-Null
        }
    } finally {
        Set-BotoesHabilitados $true
    }
}

function Reverter-Selecionados {
    Set-BotoesHabilitados $false
    try {
        foreach ($t in $script:Tweaks) {
            $cb = $checkboxes[$t.id]
            if (-not $cb -or $t.unico) { continue }
            if (-not $cb.Checked -and (Test-TweakAplicado $t.id)) {
                Mostrar-Status "Revertendo: $($t.nome)..."
                Revert-Tweak $t | Out-Null
            }
        }
        Mostrar-Status 'MeuTweaker'
        [System.Windows.Forms.MessageBox]::Show('Ajustes desmarcados foram revertidos.', 'MeuTweaker') | Out-Null
    } finally {
        Set-BotoesHabilitados $true
    }
}

function Aplicar-Recomendados {
    foreach ($t in (Get-TweaksRecomendados)) {
        if ($checkboxes[$t.id]) { $checkboxes[$t.id].Checked = $true }
    }
    Aplicar-Selecionados
}

function Aplicar-Perfil($perfil) {
    if ($perfil.revertAll) {
        foreach ($t in $script:Tweaks) { if ($checkboxes[$t.id]) { $checkboxes[$t.id].Checked = $false } }
        Reverter-Selecionados
        return
    }
    foreach ($id in $perfil.tweaks) {
        if ($checkboxes[$id]) { $checkboxes[$id].Checked = $true }
    }
    Aplicar-Selecionados
}

foreach ($perfil in (Get-Perfis)) {
    $botaoPerfil = New-Object System.Windows.Forms.Button
    $botaoPerfil.Text = "$($perfil.icone) $($perfil.nome)"
    $botaoPerfil.Width = 150
    $botaoPerfil.Margin = New-Object System.Windows.Forms.Padding(6, 6, 0, 0)
    $perfilCapturado = $perfil
    $botaoPerfil.Add_Click({ Aplicar-Perfil $perfilCapturado }.GetNewClosure())
    $painelPerfis.Controls.Add($botaoPerfil)
}

# ============================================================================
# ABA 2: Debloat
# ============================================================================
$abaDebloat = New-Object System.Windows.Forms.TabPage
$abaDebloat.Text = 'Debloat'
$abaDebloat.BackColor = $CorFundo
$abas.TabPages.Add($abaDebloat)

$avisoDebloat = New-Object System.Windows.Forms.Label
$avisoDebloat.Dock = 'Top'
$avisoDebloat.Height = 36
$avisoDebloat.Text = 'Remocao de apps de fabrica exige administrador. NAO e reversivel por aqui (reinstale pela Microsoft Store se precisar de volta).'
$avisoDebloat.ForeColor = $CorTextoFraco
$avisoDebloat.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 0)
$abaDebloat.Controls.Add($avisoDebloat)

$painelDebloat = New-Object System.Windows.Forms.FlowLayoutPanel
$painelDebloat.Dock = 'Fill'
$painelDebloat.AutoScroll = $true
$painelDebloat.FlowDirection = 'TopDown'
$painelDebloat.WrapContents = $false
$painelDebloat.BackColor = $CorFundo
$abaDebloat.Controls.Add($painelDebloat)

$barraDebloat = New-Object System.Windows.Forms.FlowLayoutPanel
$barraDebloat.Dock = 'Bottom'
$barraDebloat.Height = 44
$barraDebloat.BackColor = $CorFundoBarra
$abaDebloat.Controls.Add($barraDebloat)

$script:checkboxesDebloat = @{}

function Carregar-Debloat {
    $painelDebloat.Controls.Clear()
    $script:checkboxesDebloat = @{}
    Mostrar-Status 'Lendo apps instalados...'
    foreach ($item in (Get-AppsFabrica)) {
        $cb = New-Object System.Windows.Forms.CheckBox
        $texto = $item.label
        if (-not $item.instalado) { $texto += '  (nao instalado)' }
        if ($item.aviso) { $texto += "  - $($item.aviso)" }
        $cb.Text = $texto
        $cb.AutoSize = $true
        $cb.Enabled = $item.instalado
        $cb.ForeColor = $(if ($item.instalado) { $CorTexto } else { $CorTextoFraco })
        $cb.Margin = New-Object System.Windows.Forms.Padding(8, 2, 0, 2)
        $painelDebloat.Controls.Add($cb)
        $script:checkboxesDebloat[$item.match] = $cb
    }
    Mostrar-Status 'MeuTweaker'
}

$botaoAtualizarDebloat = New-Object System.Windows.Forms.Button
$botaoAtualizarDebloat.Text = 'Atualizar lista'
$botaoAtualizarDebloat.Width = 130
$botaoAtualizarDebloat.Margin = New-Object System.Windows.Forms.Padding(8, 6, 0, 0)
$botaoAtualizarDebloat.Add_Click({ Carregar-Debloat })
$barraDebloat.Controls.Add($botaoAtualizarDebloat)

$botaoRemoverDebloat = New-Object System.Windows.Forms.Button
$botaoRemoverDebloat.Text = 'Remover selecionados'
$botaoRemoverDebloat.Width = 160
$botaoRemoverDebloat.Margin = New-Object System.Windows.Forms.Padding(8, 6, 0, 0)
$botaoRemoverDebloat.Add_Click({
    if (-not (Test-Admin)) {
        [System.Windows.Forms.MessageBox]::Show('Remover apps exige executar o MeuTweaker como administrador.', 'MeuTweaker') | Out-Null
        return
    }
    $selecionados = $script:checkboxesDebloat.Keys | Where-Object { $script:checkboxesDebloat[$_].Checked }
    if (-not $selecionados -or $selecionados.Count -eq 0) { return }
    $confirmar = [System.Windows.Forms.MessageBox]::Show("Remover $($selecionados.Count) app(s)? Isso nao e reversivel por aqui.", 'Confirmar', 'YesNo')
    if ($confirmar -ne 'Yes') { return }
    Mostrar-Status 'Removendo apps...'
    $resultados = Remove-AppsFabrica -selecionados @($selecionados)
    Mostrar-Status 'MeuTweaker'
    $texto = ($resultados | ForEach-Object { "$($_.label): $($_.detail)" }) -join "`n"
    [System.Windows.Forms.MessageBox]::Show($texto, 'MeuTweaker') | Out-Null
    Carregar-Debloat
})
$barraDebloat.Controls.Add($botaoRemoverDebloat)

# ============================================================================
# ABA 3: Drivers
# ============================================================================
$abaDrivers = New-Object System.Windows.Forms.TabPage
$abaDrivers.Text = 'Drivers'
$abaDrivers.BackColor = $CorFundo
$abas.TabPages.Add($abaDrivers)

$listaDrivers = New-Object System.Windows.Forms.ListView
$listaDrivers.View = 'Details'
$listaDrivers.FullRowSelect = $true
$listaDrivers.Dock = 'Top'
$listaDrivers.Height = 320
$listaDrivers.Columns.Add('Classe', 110) | Out-Null
$listaDrivers.Columns.Add('Dispositivo', 220) | Out-Null
$listaDrivers.Columns.Add('Versao', 110) | Out-Null
$listaDrivers.Columns.Add('Data', 90) | Out-Null
$listaDrivers.Columns.Add('Fornecedor', 110) | Out-Null
$abaDrivers.Controls.Add($listaDrivers)

$rotuloProblemas = New-Object System.Windows.Forms.Label
$rotuloProblemas.Dock = 'Top'
$rotuloProblemas.Height = 24
$rotuloProblemas.Text = 'Dispositivos com problema:'
$rotuloProblemas.ForeColor = $CorTexto
$rotuloProblemas.Padding = New-Object System.Windows.Forms.Padding(8, 6, 0, 0)
$abaDrivers.Controls.Add($rotuloProblemas)

$listaProblemas = New-Object System.Windows.Forms.ListView
$listaProblemas.View = 'Details'
$listaProblemas.FullRowSelect = $true
$listaProblemas.Dock = 'Top'
$listaProblemas.Height = 100
$listaProblemas.Columns.Add('Dispositivo', 260) | Out-Null
$listaProblemas.Columns.Add('Classe', 120) | Out-Null
$listaProblemas.Columns.Add('Status', 150) | Out-Null
$abaDrivers.Controls.Add($listaProblemas)

$barraDrivers = New-Object System.Windows.Forms.FlowLayoutPanel
$barraDrivers.Dock = 'Bottom'
$barraDrivers.Height = 44
$barraDrivers.BackColor = $CorFundoBarra
$abaDrivers.Controls.Add($barraDrivers)

function Carregar-Drivers {
    Mostrar-Status 'Lendo drivers instalados...'
    $listaDrivers.Items.Clear()
    foreach ($d in (Get-TodosDrivers)) {
        $texto = $d.nome + $(if ($d.contagem -gt 1) { " (x$($d.contagem))" } else { '' })
        $item = New-Object System.Windows.Forms.ListViewItem(@($d.classe, $texto, $d.versao, $d.data, $d.fornecedor))
        $listaDrivers.Items.Add($item) | Out-Null
    }
    $listaProblemas.Items.Clear()
    foreach ($p in (Get-DispositivosComProblema)) {
        $item = New-Object System.Windows.Forms.ListViewItem(@($p.nome, $p.classe, $p.status))
        $listaProblemas.Items.Add($item) | Out-Null
    }
    Mostrar-Status 'MeuTweaker'
}

$botaoAtualizarDrivers = New-Object System.Windows.Forms.Button
$botaoAtualizarDrivers.Text = 'Atualizar'
$botaoAtualizarDrivers.Width = 120
$botaoAtualizarDrivers.Margin = New-Object System.Windows.Forms.Padding(8, 6, 0, 0)
$botaoAtualizarDrivers.Add_Click({ Carregar-Drivers })
$barraDrivers.Controls.Add($botaoAtualizarDrivers)

$botaoBackupDrivers = New-Object System.Windows.Forms.Button
$botaoBackupDrivers.Text = 'Fazer backup dos drivers...'
$botaoBackupDrivers.Width = 190
$botaoBackupDrivers.Margin = New-Object System.Windows.Forms.Padding(8, 6, 0, 0)
$botaoBackupDrivers.Add_Click({
    if (-not (Test-Admin)) {
        [System.Windows.Forms.MessageBox]::Show('Backup de drivers exige executar o MeuTweaker como administrador.', 'MeuTweaker') | Out-Null
        return
    }
    $dialogo = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialogo.Description = 'Escolha a pasta de destino do backup de drivers'
    if ($dialogo.ShowDialog() -ne 'OK') { return }
    Mostrar-Status 'Exportando drivers...'
    $r = Backup-Drivers $dialogo.SelectedPath
    Mostrar-Status 'MeuTweaker'
    if ($r.ok) {
        [System.Windows.Forms.MessageBox]::Show("Backup concluido: $($r.quantidade) driver(s) exportado(s) para $($r.destino).", 'MeuTweaker') | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show("Falha no backup: $($r.detail)", 'MeuTweaker') | Out-Null
    }
})
$barraDrivers.Controls.Add($botaoBackupDrivers)

# ============================================================================
# ABA 4: Desempenho (ao vivo)
# ============================================================================
$abaDesempenho = New-Object System.Windows.Forms.TabPage
$abaDesempenho.Text = 'Desempenho'
$abaDesempenho.BackColor = $CorFundo
$abas.TabPages.Add($abaDesempenho)

$rotuloEstatico = New-Object System.Windows.Forms.Label
$rotuloEstatico.Dock = 'Top'
$rotuloEstatico.Height = 70
$rotuloEstatico.ForeColor = $CorTexto
$rotuloEstatico.Padding = New-Object System.Windows.Forms.Padding(8, 8, 0, 0)
$abaDesempenho.Controls.Add($rotuloEstatico)

$rotuloVivo = New-Object System.Windows.Forms.Label
$rotuloVivo.Dock = 'Top'
$rotuloVivo.Height = 160
$rotuloVivo.Font = New-Object System.Drawing.Font('Consolas', 11)
$rotuloVivo.ForeColor = $CorTexto
$rotuloVivo.Padding = New-Object System.Windows.Forms.Padding(8, 8, 0, 0)
$abaDesempenho.Controls.Add($rotuloVivo)

$script:timerDesempenho = New-Object System.Windows.Forms.Timer
$script:timerDesempenho.Interval = 1500
$script:timerDesempenho.Add_Tick({
    try {
        $a = Get-AmostraDesempenho
        $rotuloVivo.Text = "CPU:    $($a.cpuPct)%`r`nGPU:    $($a.gpuPct)%`r`nDisco:  $($a.discoPct)%`r`nRAM livre: $([math]::Round($a.ramDisponivelMb/1024,1)) GB`r`nRede:   recebendo $($a.redeRecebidoKb) KB/s, enviando $($a.redeEnviadoKb) KB/s"
    } catch {}
})

$abas.Add_SelectedIndexChanged({
    if ($abas.SelectedTab -eq $abaDesempenho) {
        if (-not $script:estaticaCarregada) {
            $e = Get-InfoEstaticaDesempenho
            $rotuloEstatico.Text = "CPU: $($e.cpuNome)  ($($e.nucleos) nucleos / $($e.logicos) logicos)`r`nGPU: $($e.gpuNome)`r`nRAM: $($e.ramTotalGb) GB $($e.tipoRam)"
            $script:estaticaCarregada = $true
        }
        $script:timerDesempenho.Start()
    } else {
        $script:timerDesempenho.Stop()
    }
})

# ============================================================================
# ABA 5: Diagnostico
# ============================================================================
$abaDiagnostico = New-Object System.Windows.Forms.TabPage
$abaDiagnostico.Text = 'Diagnostico'
$abaDiagnostico.BackColor = $CorFundo
$abas.TabPages.Add($abaDiagnostico)

$barraDiagnostico = New-Object System.Windows.Forms.FlowLayoutPanel
$barraDiagnostico.Dock = 'Top'
$barraDiagnostico.Height = 44
$barraDiagnostico.BackColor = $CorFundoBarra
$abaDiagnostico.Controls.Add($barraDiagnostico)

$botaoDiagnostico = New-Object System.Windows.Forms.Button
$botaoDiagnostico.Text = 'Rodar diagnostico'
$botaoDiagnostico.Width = 150
$botaoDiagnostico.Margin = New-Object System.Windows.Forms.Padding(8, 6, 0, 0)
$barraDiagnostico.Controls.Add($botaoDiagnostico)

$rotuloPotencial = New-Object System.Windows.Forms.Label
$rotuloPotencial.Dock = 'Top'
$rotuloPotencial.Height = 40
$rotuloPotencial.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$rotuloPotencial.ForeColor = $CorTexto
$rotuloPotencial.Padding = New-Object System.Windows.Forms.Padding(8, 8, 0, 0)
$rotuloPotencial.Text = 'Potencial de otimizacao: -'
$abaDiagnostico.Controls.Add($rotuloPotencial)

$caixaAchados = New-Object System.Windows.Forms.TextBox
$caixaAchados.Multiline = $true
$caixaAchados.ReadOnly = $true
$caixaAchados.ScrollBars = 'Vertical'
$caixaAchados.Dock = 'Fill'
$caixaAchados.BackColor = $CorFundoBarra
$caixaAchados.ForeColor = $CorTexto
$abaDiagnostico.Controls.Add($caixaAchados)

$botaoDiagnostico.Add_Click({
    Mostrar-Status 'Rodando diagnostico...'
    $d = Get-PotencialOtimizacao
    Mostrar-Status 'MeuTweaker'
    $rotuloPotencial.Text = "Potencial de otimizacao: $($d.potencial)%"
    $caixaAchados.Text = if ($d.achados.Count -gt 0) { ($d.achados | ForEach-Object { "- $_" }) -join "`r`n" } else { 'Nada relevante encontrado - maquina ja bem otimizada.' }
})

# ============================================================================
# Barra de botoes global (aba Ajustes)
# ============================================================================
$botaoBoost = New-Object System.Windows.Forms.Button
$botaoBoost.Text = 'Otimizar agora (recomendados)'
$botaoBoost.Width = 190
$botaoBoost.Margin = New-Object System.Windows.Forms.Padding(10, 10, 0, 0)
$botaoBoost.Add_Click({ Aplicar-Recomendados })
$barraBotoes.Controls.Add($botaoBoost)

$botaoAplicar = New-Object System.Windows.Forms.Button
$botaoAplicar.Text = 'Aplicar marcados'
$botaoAplicar.Width = 140
$botaoAplicar.Margin = New-Object System.Windows.Forms.Padding(10, 10, 0, 0)
$botaoAplicar.Add_Click({ Aplicar-Selecionados })
$barraBotoes.Controls.Add($botaoAplicar)

$botaoReverter = New-Object System.Windows.Forms.Button
$botaoReverter.Text = 'Reverter desmarcados'
$botaoReverter.Width = 150
$botaoReverter.Margin = New-Object System.Windows.Forms.Padding(10, 10, 0, 0)
$botaoReverter.Add_Click({ Reverter-Selecionados })
$barraBotoes.Controls.Add($botaoReverter)

$botaoRestore = New-Object System.Windows.Forms.Button
$botaoRestore.Text = 'Criar ponto de restauracao'
$botaoRestore.Width = 170
$botaoRestore.Margin = New-Object System.Windows.Forms.Padding(10, 10, 0, 0)
$botaoRestore.Add_Click({
    $r = New-PontoRestauracao
    [System.Windows.Forms.MessageBox]::Show($r.detail, 'MeuTweaker') | Out-Null
})
$barraBotoes.Controls.Add($botaoRestore)

$script:botoesAcao = @($botaoBoost, $botaoAplicar, $botaoReverter, $botaoRestore)

if (-not (Test-Admin)) {
    $botaoAdmin = New-Object System.Windows.Forms.Button
    $botaoAdmin.Text = 'Reiniciar como administrador'
    $botaoAdmin.Width = 190
    $botaoAdmin.Margin = New-Object System.Windows.Forms.Padding(10, 10, 0, 0)
    $botaoAdmin.BackColor = [System.Drawing.Color]::FromArgb(120, 40, 40)
    $botaoAdmin.ForeColor = [System.Drawing.Color]::White
    $botaoAdmin.Add_Click({ Restart-ComoAdmin })
    $barraBotoes.Controls.Add($botaoAdmin)
}

# carrega as abas de leitura (debloat/drivers) em segundo plano logico, so quando abertas
$abas.Add_Selecting({
    param($sender, $e)
    if ($e.TabPage -eq $abaDebloat -and $painelDebloat.Controls.Count -eq 0) { Carregar-Debloat }
    if ($e.TabPage -eq $abaDrivers -and $listaDrivers.Items.Count -eq 0) { Carregar-Drivers }
})

[void]$form.ShowDialog()
