import { ElectronAPI } from '@electron-toolkit/preload'

declare global {
  interface Window {
    electron: ElectronAPI
    api: {
      minimize: () => void
      maximize: () => void
      close: () => void
      getChangelog: () => Promise<{ version: string; date: string; notes: string[] }[]>
      checkLatestRelease: () => Promise<{ version: string | null; downloadUrl: string | null } | null>
      loadConfig: () => Promise<{ cookie: string; apiKey: string; downloadPath: string }>
      saveConfig: (data: { cookie: string; apiKey: string; downloadPath: string }) => Promise<{ ok: boolean }>
      getJobState: () => Promise<JobState>
      getServerPort: () => Promise<number>
      getDownloadsPath: () => Promise<string>
      selectDownloadDir: () => Promise<string | null>
      selectInstallDir: () => Promise<string | null>
      selectNupkgFile: () => Promise<string | null>
      checkInstallStatus: (TargetPath: string) => Promise<{ installed: boolean; broken: boolean; installedVersion: string; currentVersion: string }>
      installApp: (Args: { sourcePathOrUrl: string; targetPath: string; openAfter: boolean; createShortcut: boolean }) => Promise<{ ok: boolean; error?: string }>
      launchInstalledApp: (TargetPath: string) => Promise<{ ok: boolean; error?: string }>
      onJobUpdate: (cb: (state: JobState) => void) => void
      onServerStatus: (cb: (status: { listening: boolean; port?: number; error?: string }) => void) => void
      removeListeners: () => void
    }
  }

  interface OutputEntry {
    index: number
    oldId: string
    newId: string
    status: string
  }

  interface JobState {
    status: 'idle' | 'processing' | 'complete' | 'error'
    total: number
    done: number
    ok: number
    failed: number
    mapping: Record<string, string>
    error: string | null
    failReasons: Record<string, number>
    sessionDir: string | null
    sessionName: string | null
    outputs: OutputEntry[]
  }
}
