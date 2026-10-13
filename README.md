# MeuTweaker

Otimizador de Windows pessoal, independente, sem login, sem conta, sem
telemetria e sem servidor externo. Todos os ajustes são técnicas de
otimização de Windows conhecidas publicamente (chaves de registro
documentadas pela Microsoft e comandos nativos como `powercfg`, `netsh`,
`fsutil`) — nada aqui é proprietário.

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
- **Limpeza**: temporários, prefetch, lixeira.

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

## Executando a partir do código-fonte

```powershell
powershell -ExecutionPolicy Bypass -File .\MeuTweaker.ps1
```

Ajustes marcados `[admin]` só se aplicam se o PowerShell/exe estiver
rodando como administrador.

## Gerando o .exe

Usa o [ps2exe](https://github.com/MScholtes/PS2EXE) (módulo open-source do
PowerShell Gallery) para compilar os três scripts (`engine.ps1`,
`tweaks.ps1`, `MeuTweaker.ps1`) num único executável autocontido:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

O resultado fica em `dist\MeuTweaker.exe`.

## Sobre o alerta do Windows/SmartScreen

Este `.exe` **não é assinado digitalmente** (assinatura de código custa uma
certificação paga por um emissor confiável). Qualquer executável novo e não
assinado que grava em `HKLM` e chama PowerShell tende a disparar o
SmartScreen do Windows ou um alerta heurístico do Defender — isso vale tanto
para este script quanto para praticamente qualquer tweaker desse tipo
(incluindo os comerciais). Não é sinal de vírus; é o comportamento esperado
de software não assinado que esta ferramenta compila localmente, na sua
própria máquina, a partir de um código que você pode ler linha por linha.

Se preferir, revise `engine.ps1` e `tweaks.ps1` antes de compilar — não há
nada ofuscado.

## Estrutura

```
engine.ps1       motor: registro (ler/gravar/reverter), estado, ponto de restauração
tweaks.ps1       catálogo declarativo dos ajustes
MeuTweaker.ps1   interface (Windows Forms) e ponto de entrada
build.ps1        compila os três scripts acima em dist\MeuTweaker.exe via ps2exe
```
