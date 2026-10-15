// MeuTweaker - processo principal do Electron.
// Toda a logica de tweak continua em PowerShell (core/bridge.ps1); aqui so
// orquestramos a janela, o IPC com a renderer e a chamada do bridge.

const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('node:path');
const { spawn } = require('node:child_process');

const MARCADOR = '###MT_RESULT###';

function corePath() {
  return app.isPackaged
    ? path.join(process.resourcesPath, 'core')
    : path.join(__dirname, '..', 'core');
}

function bridgePath() {
  return path.join(corePath(), 'bridge.ps1');
}

// Tempo maximo de espera por uma chamada ao bridge.ps1. Sem isso, qualquer
// travamento real do PowerShell (antivirus interceptando, WMI lento, servico
// do Restore Point parado, etc.) deixava a promise pendurada para sempre e a
// tela travava num "carregando" infinito sem nenhuma mensagem de erro.
const TIMEOUT_MS = 25000;

// Executa uma acao do bridge.ps1 e resolve com o objeto JSON de resultado.
// Cada chamada sobe um processo powershell novo (app nao e um servidor de
// alta frequencia; simplicidade e robustez pesam mais aqui do que os ~300ms
// de startup do PowerShell).
function callBridge(action, payload) {
  return new Promise((resolve) => {
    const payloadJson = JSON.stringify(payload || {});
    const payloadB64 = Buffer.from(payloadJson, 'utf8').toString('base64');
    const args = [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy', 'Bypass',
      '-File', bridgePath(),
      '-Action', action,
      '-PayloadB64', payloadB64,
    ];
    const proc = spawn('powershell.exe', args, { windowsHide: true });
    let stdout = '';
    let stderr = '';
    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(value);
    };
    const timer = setTimeout(() => {
      proc.kill();
      finish({ ok: false, detail: `Tempo esgotado esperando o PowerShell responder (${action}). Tente de novo; se persistir, pode ser antivirus bloqueando a execucao.` });
    }, TIMEOUT_MS);
    proc.stdout.setEncoding('utf8');
    proc.stderr.setEncoding('utf8');
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.on('data', (d) => { stderr += d; });
    proc.on('error', (err) => {
      finish({ ok: false, detail: `Falha ao iniciar PowerShell: ${err.message}` });
    });
    proc.on('close', () => {
      const idx = stdout.lastIndexOf(MARCADOR);
      if (idx === -1) {
        finish({ ok: false, detail: stderr.trim() || 'Sem resposta do PowerShell.' });
        return;
      }
      const jsonText = stdout.slice(idx + MARCADOR.length).trim();
      try {
        finish(JSON.parse(jsonText));
      } catch (e) {
        finish({ ok: false, detail: `Resposta invalida do PowerShell: ${e.message}` });
      }
    });
  });
}

function restartAsAdmin() {
  const exe = process.execPath;
  const args = app.isPackaged ? process.argv.slice(1) : [app.getAppPath()];
  const quoted = (s) => `'${String(s).replace(/'/g, "''")}'`;
  const argList = args.length ? `-ArgumentList @(${args.map(quoted).join(',')}) ` : '';
  const psCmd = `Start-Process -FilePath ${quoted(exe)} ${argList}-Verb RunAs`;
  spawn('powershell.exe', ['-NoProfile', '-Command', psCmd], { windowsHide: true, detached: true });
  app.quit();
}

let janela;

function criarJanela() {
  janela = new BrowserWindow({
    width: 980,
    height: 760,
    minWidth: 820,
    minHeight: 560,
    backgroundColor: '#121116',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  janela.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(criarJanela);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// ---------------- IPC ----------------

const acoesSimples = [
  'test-admin',
  'get-catalog',
  'create-restore-point',
  'get-debloat',
  'get-drivers',
  'get-perf-static',
  'get-perf-live',
  'get-diagnostico',
];

for (const acao of acoesSimples) {
  ipcMain.handle(acao, () => callBridge(acao));
}

ipcMain.handle('apply-tweaks', (_e, ids) => callBridge('apply-tweaks', { ids }));
ipcMain.handle('revert-tweaks', (_e, ids) => callBridge('revert-tweaks', { ids }));
ipcMain.handle('apply-perfil', (_e, id) => callBridge('apply-perfil', { id }));
ipcMain.handle('remove-debloat', (_e, matches) => callBridge('remove-debloat', { matches }));
ipcMain.handle('backup-drivers', (_e, destino) => callBridge('backup-drivers', { destino }));

ipcMain.handle('restart-as-admin', () => { restartAsAdmin(); });

ipcMain.handle('choose-folder', async () => {
  const r = await dialog.showOpenDialog(janela, { properties: ['openDirectory', 'createDirectory'] });
  if (r.canceled || !r.filePaths.length) return null;
  return r.filePaths[0];
});

ipcMain.handle('confirm', async (_e, { title, message }) => {
  const r = await dialog.showMessageBox(janela, {
    type: 'question',
    buttons: ['Cancelar', 'Confirmar'],
    defaultId: 0,
    cancelId: 0,
    title: title || 'MeuTweaker',
    message,
  });
  return r.response === 1;
});

ipcMain.handle('open-folder', (_e, destino) => { shell.openPath(destino); });
