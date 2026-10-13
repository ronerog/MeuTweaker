# ============================================================================
# MeuTweaker - ponto de entrada (GUI)
# App proprio de otimizacao do Windows. Sem login, sem telemetria, sem
# servidor externo. Todo ajuste e reversivel (backup automatico em
# %LOCALAPPDATA%\MeuTweaker\state.json) e cria ponto de restauracao no
# primeiro uso.
# ============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$raiz = $PSScriptRoot
. (Join-Path $raiz 'engine.ps1')
. (Join-Path $raiz 'tweaks.ps1')

# ---------- janela principal ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'MeuTweaker'
$form.Size = New-Object System.Drawing.Size(640, 720)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(17, 16, 20)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$titulo = New-Object System.Windows.Forms.Label
$titulo.Text = if (Test-Admin) { 'MeuTweaker  (administrador)' } else { 'MeuTweaker  (sem privilegios de administrador — alguns ajustes ficarao bloqueados)' }
$titulo.AutoSize = $false
$titulo.Dock = 'Top'
$titulo.Height = 32
$titulo.TextAlign = 'MiddleLeft'
$titulo.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
$form.Controls.Add($titulo)

$painel = New-Object System.Windows.Forms.FlowLayoutPanel
$painel.Dock = 'Fill'
$painel.AutoScroll = $true
$painel.FlowDirection = 'TopDown'
$painel.WrapContents = $false
$painel.BackColor = $form.BackColor
$form.Controls.Add($painel)

$barraBotoes = New-Object System.Windows.Forms.FlowLayoutPanel
$barraBotoes.Dock = 'Bottom'
$barraBotoes.Height = 50
$barraBotoes.BackColor = [System.Drawing.Color]::FromArgb(24, 23, 28)
$form.Controls.Add($barraBotoes)

$checkboxes = @{}

function Add-Secao([string]$nomeCategoria) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $nomeCategoria
    $lbl.AutoSize = $true
    $lbl.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $lbl.Margin = New-Object System.Windows.Forms.Padding(8, 14, 0, 4)
    $painel.Controls.Add($lbl)
}

function Add-LinhaTweak($tweak) {
    $linha = New-Object System.Windows.Forms.Panel
    $linha.Width = 590
    $linha.Height = 42
    $linha.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $tweak.nome + $(if ($tweak.admin) { '  [admin]' } else { '' })
    $cb.AutoSize = $true
    $cb.Location = New-Object System.Drawing.Point(0, 0)
    $cb.Checked = (Test-TweakAplicado $tweak.id)
    $cb.ForeColor = [System.Drawing.Color]::White
    $linha.Controls.Add($cb)
    $checkboxes[$tweak.id] = $cb

    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = $tweak.desc
    $desc.AutoSize = $false
    $desc.Width = 580
    $desc.Height = 18
    $desc.Location = New-Object System.Drawing.Point(20, 20)
    $desc.ForeColor = [System.Drawing.Color]::Gainsboro
    $desc.Font = New-Object System.Drawing.Font('Segoe UI', 8)
    $linha.Controls.Add($desc)

    $painel.Controls.Add($linha)
}

$categorias = $script:Tweaks | Where-Object { -not $_.unico } | Select-Object -ExpandProperty categoria -Unique
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

function Mostrar-Status([string]$texto) {
    $titulo.Text = $texto
    $form.Refresh()
}

function Aplicar-Selecionados {
    if (-not (Test-Admin)) {
        [System.Windows.Forms.MessageBox]::Show('Para aplicar os ajustes marcados como [admin], execute o MeuTweaker como administrador.', 'MeuTweaker') | Out-Null
    }
    New-PontoRestauracao | Out-Null
    $erros = @()
    foreach ($t in $script:Tweaks) {
        $cb = $checkboxes[$t.id]
        if (-not $cb -or -not $cb.Checked) { continue }
        if ($t.admin -and -not (Test-Admin)) { continue }
        Mostrar-Status "Aplicando: $($t.nome)..."
        if ($t.unico) {
            $r = Invoke-TweakUnico $t
        } elseif (-not (Test-TweakAplicado $t.id)) {
            $r = Invoke-Tweak $t
        } else { continue }
        if (-not $r.ok) { $erros += "$($t.nome): $($r.detail)" }
    }
    Mostrar-Status 'MeuTweaker'
    if ($erros.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(($erros -join "`n"), 'Alguns ajustes falharam') | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show('Ajustes aplicados.', 'MeuTweaker') | Out-Null
    }
}

function Reverter-Selecionados {
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
}

function Aplicar-Recomendados {
    foreach ($t in (Get-TweaksRecomendados)) {
        if ($checkboxes[$t.id]) { $checkboxes[$t.id].Checked = $true }
    }
    Aplicar-Selecionados
}

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

[void]$form.ShowDialog()
