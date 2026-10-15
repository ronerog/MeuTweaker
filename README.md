# MeuTweaker

Otimizador de Windows pessoal, independente, sem login, sem conta, sem
telemetria e sem servidor externo. Todos os ajustes são técnicas de
otimização de Windows conhecidas publicamente (chaves de registro
documentadas pela Microsoft e comandos nativos como `powercfg`, `netsh`,
`fsutil`) — nada aqui é proprietário.

Interface em Electron (HTML/CSS/JS); a lógica de cada ajuste continua em
PowerShell puro, legível e sem nada ofuscado.

## Por que existe

Script próprio inspirado em tweakers de Windows gratuitos e conhecidos da
comunidade (ex.: guias de otimização para jogos, scripts como o
Windows10Debloater). Feito para uso pessoal, com código aberto e legível, sem
nenhuma das partes de conta/assinatura/anúncio que ferramentas comerciais do
mesmo tipo costumam ter.

## O que ele faz

- **Desempenho**: plano de energia Ultimate, core parking, SysMain,
  indexação de busca, compactação de memória, NTFS last-access, hibernação,
  inicialização rápida.
- **Jogos**: Game Mode, HAGS, prioridade de processo para jogos, remoção da
  aceleração do mouse, desativar Game DVR, sticky keys.
- **Rede**: remoção de network throttling, responsividade do sistema, flush
  de DNS.
- **Privacidade**: telemetria mínima, DiagTrack, ID de publicidade, histórico
  de atividades, relatório de erros.
- **Aparência**: efeitos visuais, transparência, notificações.
- **Limpeza**: temporários, prefetch, lixeira, memória em standby.
- **Hz do monitor**: detecta e aplica a taxa de atualização máxima suportada.
- **Perfis prontos**: Competitivo Total, Equilibrado, PC Modesto, Privacidade
  Máxima e Padrão Windows (reverte tudo) — cada um aplica um conjunto de
  ajustes do catálogo de uma vez.
- **Debloat**: lista e remove ~22 apps de fábrica (Clima, Xbox, Copilot,
  Widgets, etc.) via `Get-AppxPackage`/`Remove-AppxPackage`. Exige admin e
  **não é reversível** por aqui — reinstale pela Microsoft Store se precisar.
- **Drivers**: inventário de drivers instalados, lista de dispositivos com
  problema, e backup de drivers de terceiros para uma pasta
  (`Export-WindowsDriver`). Não baixa nada.
- **Desempenho ao vivo**: CPU%, RAM, disco, rede e GPU em tempo real.
- **Diagnóstico**: percentual de 0–100% do quanto a máquina ainda pode ser
  otimizada, sondando o estado real do Windows (sem aplicar nada).

Cada ajuste reversível salva o valor **anterior** do registro antes de
alterar (em `%LOCALAPPDATA%\MeuTweaker\state.json`) e desmarcar a opção
restaura o valor original. Um ponto de restauração do Windows é criado
automaticamente na primeira aplicação.

## O que ele **não** faz (de propósito)

- Sem login, conta ou licença.
- Sem telemetria própria (nada é enviado para lugar nenhum).
- Sem overlay dentro de jogos, sem recurso de "segunda tela"/celular.
- Sem auto-update puxando de servidor externo.
- Não toca em arquivos de jogo nem em anti-cheat.
- Não desativa a proteção em tempo real do Defender.

## Se algum ajuste falhar

A maioria dos ajustes marcados `[admin]` exige que o MeuTweaker esteja
rodando **como administrador**. Se não estiver, o app pula esses ajustes e
avisa quais foram pulados ao final — use o botão **"Reiniciar como
administrador"** que aparece na barra inferior quando o app não está
elevado.

Se um ajuste falhar mesmo rodando como administrador, a mensagem de erro
mostrada é o motivo real (não genérico) — normalmente outro programa ou
política de grupo está controlando aquela configuração.

## Arquitetura

```
core/            motor de tweaks em PowerShell (nao muda com a UI)
  engine.ps1       registro (ler/gravar/reverter), estado, ponto de restauracao
  tweaks.ps1       catalogo declarativo dos ajustes
  display.ps1      Hz do monitor (P/Invoke EnumDisplaySettings/ChangeDisplaySettings)
  debloat.ps1      catalogo e remocao de apps de fabrica
  drivers.ps1      inventario, problemas e backup de drivers
  perfmon.ps1      medidor de desempenho ao vivo
  scan.ps1         diagnostico (potencial de otimizacao)
  perfis.ps1       perfis prontos (conjuntos nomeados de ajustes)
  bridge.ps1       ponte JSON entre o Electron e as funcoes acima

app/             interface em Electron
  main.js          processo principal: janela, IPC, spawn do bridge.ps1
  preload.js       expoe a API (window.mt) para a renderer, sem Node direto
  renderer/        HTML/CSS/JS da interface (sem framework)
  package.json     scripts e config do electron-builder (gera o instalador)
```

A interface nunca toca em registro/serviços diretamente: toda ação do
usuário vira uma chamada IPC → `main.js` sobe um `powershell.exe` chamando
`core/bridge.ps1 -Action <acao>` → o bridge dot-source os módulos de `core/`
e devolve um JSON. Trocar a interface no futuro (ou adicionar uma CLI) não
exige tocar na lógica de nenhum ajuste.

## Executando a partir do código-fonte

```powershell
cd app
npm install
npm start
```

## Gerando o instalador

```powershell
cd app
npm install
npm run dist
```

Usa o [electron-builder](https://www.electron.build/) para gerar um
instalador NSIS (`.exe`) em `app\dist`. Instalação por usuário (não exige
admin para instalar); os ajustes que exigem admin continuam avisando e
oferecendo "Reiniciar como administrador" dentro do app, como antes.

## Sobre o alerta do Windows/SmartScreen

O instalador e o `.exe` gerados **não são assinados digitalmente**
(assinatura de código custa uma certificação paga por um emissor confiável).
Qualquer executável novo e não assinado que grava em `HKLM` e chama
PowerShell tende a disparar o SmartScreen do Windows ou um alerta heurístico
do Defender — isso vale tanto para este projeto quanto para praticamente
qualquer tweaker desse tipo (incluindo os comerciais). Não é sinal de vírus;
é o comportamento esperado de software não assinado que você mesmo compila
localmente, a partir de um código que pode ler linha por linha.
