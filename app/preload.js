const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('mt', {
  testAdmin: () => ipcRenderer.invoke('test-admin'),
  getCatalog: () => ipcRenderer.invoke('get-catalog'),
  applyTweaks: (ids) => ipcRenderer.invoke('apply-tweaks', ids),
  revertTweaks: (ids) => ipcRenderer.invoke('revert-tweaks', ids),
  applyPerfil: (id) => ipcRenderer.invoke('apply-perfil', id),
  createRestorePoint: () => ipcRenderer.invoke('create-restore-point'),
  restartAsAdmin: () => ipcRenderer.invoke('restart-as-admin'),

  getDebloat: () => ipcRenderer.invoke('get-debloat'),
  removeDebloat: (matches) => ipcRenderer.invoke('remove-debloat', matches),

  getDrivers: () => ipcRenderer.invoke('get-drivers'),
  backupDrivers: (destino) => ipcRenderer.invoke('backup-drivers', destino),

  getPerfStatic: () => ipcRenderer.invoke('get-perf-static'),
  getPerfLive: () => ipcRenderer.invoke('get-perf-live'),

  getDiagnostico: () => ipcRenderer.invoke('get-diagnostico'),

  chooseFolder: () => ipcRenderer.invoke('choose-folder'),
  confirm: (title, message) => ipcRenderer.invoke('confirm', { title, message }),
  openFolder: (destino) => ipcRenderer.invoke('open-folder', destino),
});
