import { contextBridge, ipcRenderer } from 'electron'
import { electronAPI } from '@electron-toolkit/preload'

const Api = {
  minimize: () => ipcRenderer.send('window-minimize'),
  maximize: () => ipcRenderer.send('window-maximize'),
  close: () => ipcRenderer.send('window-close'),

  getChangelog: () => ipcRenderer.invoke('get-changelog'),
  checkLatestRelease: () => ipcRenderer.invoke('check-latest-release'),
  loadConfig: () => ipcRenderer.invoke('load-config'),
  saveConfig: (Data: unknown) => ipcRenderer.invoke('save-config', Data),

  getJobState: () => ipcRenderer.invoke('get-job-state'),
  getServerPort: () => ipcRenderer.invoke('get-server-port'),
  getDownloadsPath: () => ipcRenderer.invoke('get-downloads-path'),
  selectDownloadDir: () => ipcRenderer.invoke('select-download-dir'),

  selectInstallDir: () => ipcRenderer.invoke('select-install-dir'),
  selectNupkgFile: () => ipcRenderer.invoke('select-nupkg-file'),
  checkInstallStatus: (TargetPath: string) => ipcRenderer.invoke('check-install-status', TargetPath),
  installApp: (Args: unknown) => ipcRenderer.invoke('install-app', Args),
  launchInstalledApp: (TargetPath: string) => ipcRenderer.invoke('launch-installed-app', TargetPath),

  getAppVersion: () => ipcRenderer.invoke('get-app-version'),
  validateCookie: (Cookie: string) => ipcRenderer.invoke('validate-cookie', Cookie),
  getDefaultInstallDir: () => ipcRenderer.invoke('get-default-install-dir'),
  downloadAndLaunchUpdate: (Url: string) => ipcRenderer.invoke('download-and-launch-update', Url),
  runDownloadWithoutPlugin: (IdsString: string) => ipcRenderer.invoke('run-download-without-plugin', IdsString),

  onJobUpdate: (Cb: (State: unknown) => void) =>
    ipcRenderer.on('job-update', (_E, V) => Cb(V)),
  onServerStatus: (Cb: (Status: unknown) => void) =>
    ipcRenderer.on('server-status', (_E, V) => Cb(V)),
  onUpdateDownloadProgress: (Cb: (Pct: number) => void) =>
    ipcRenderer.on('update-download-progress', (_E, V) => Cb(V as number)),
  removeListeners: () => {
    ipcRenderer.removeAllListeners('job-update')
    ipcRenderer.removeAllListeners('server-status')
    ipcRenderer.removeAllListeners('update-download-progress')
  },
}

if (process.contextIsolated) {
  try {
    contextBridge.exposeInMainWorld('electron', electronAPI)
    contextBridge.exposeInMainWorld('api', Api)
  } catch (E) {
    console.error(E)
  }
} else {
  // @ts-ignore
  window.electron = electronAPI
  // @ts-ignore
  window.api = Api
}
