import { app, BrowserWindow, ipcMain, shell, dialog } from 'electron'
import { join, basename, dirname, resolve, normalize } from 'path'
import * as fs from 'fs'
import * as http from 'http'
import * as https from 'https'
import { execSync, spawn } from 'child_process'
import AdmZip from 'adm-zip'
import { electronApp, optimizer, is } from '@electron-toolkit/utils'

app.commandLine.appendSwitch('no-sandbox')
import Icon from '../../resources/icon.png?asset'
import { FetchCsrfToken, FetchUserId, DownloadSound, UploadSound, SanitizeName } from './downloader'

interface Config {
  cookie: string
  apiKey: string
  downloadPath: string
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

let MainWindow: BrowserWindow | null = null
let HttpServer: http.Server | null = null
const ServerPort = 54321

let State: JobState = {
  status: 'idle',
  total: 0,
  done: 0,
  ok: 0,
  failed: 0,
  mapping: {},
  error: null,
  failReasons: {},
  sessionDir: null,
  sessionName: null,
  outputs: [],
}

const ConfigPath = (): string => join(app.getPath('userData'), 'bsnatcher.json')
const DefaultDownloadsBase = (): string => join(app.getPath('documents'), 'BarbsSnatcher', 'downloads')

function LoadConfig(): Config {
  try {
    const Raw = JSON.parse(fs.readFileSync(ConfigPath(), 'utf-8'))
    return {
      cookie: Raw.cookie ?? '',
      apiKey: Raw.apiKey ?? '',
      downloadPath: Raw.downloadPath ?? '',
    }
  } catch {
    return { cookie: '', apiKey: '', downloadPath: '' }
  }
}

function SaveConfig(C: Config): void {
  fs.writeFileSync(ConfigPath(), JSON.stringify(C, null, 2))
}

function EffectiveDownloadsBase(): string {
  const Cfg = LoadConfig()
  return Cfg.downloadPath || DefaultDownloadsBase()
}

function CreateSessionDir(Base: string): string {
  fs.mkdirSync(Base, { recursive: true })

  const Existing = fs.readdirSync(Base).filter((N) => /^session_\d{3}_/.test(N))
  let MaxNum = 0
  for (const Name of Existing) {
    const Num = parseInt(Name.split('_')[1] ?? '0', 10)
    if (Num > MaxNum) MaxNum = Num
  }

  const Num = String(MaxNum + 1).padStart(3, '0')
  const Now = new Date()
  const D = `${Now.getFullYear()}-${String(Now.getMonth() + 1).padStart(2, '0')}-${String(Now.getDate()).padStart(2, '0')}`
  const T = `${String(Now.getHours()).padStart(2, '0')}${String(Now.getMinutes()).padStart(2, '0')}${String(Now.getSeconds()).padStart(2, '0')}`
  const DirName = `session_${Num}_${D}_${T}`
  const FullPath = join(Base, DirName)
  fs.mkdirSync(FullPath, { recursive: true })
  return FullPath
}

function SetState(Patch: Partial<JobState>): void {
  State = { ...State, ...Patch }
  MainWindow?.webContents.send('job-update', State)
}

async function RunJob(Ids: string[], Names: Record<string, string>, PlaceIds: string[], CreatorType: string, CreatorId: number): Promise<void> {
  const Cfg = LoadConfig()
  if (!Cfg.apiKey) {
    SetState({ status: 'error', error: 'No API key set. Go to Settings and add your Open Cloud API key.' })
    return
  }
  if (!Cfg.cookie) {
    SetState({ status: 'error', error: 'No cookie set. Go to Settings and paste your .ROBLOSECURITY cookie.' })
    return
  }

  const SessionDir = CreateSessionDir(Cfg.downloadPath || DefaultDownloadsBase())
  const SessionName = basename(SessionDir)

  const Outputs: OutputEntry[] = Ids.map((Id, Index) => ({
    index: Index + 1,
    oldId: Id,
    newId: 'Pending',
    status: 'Waiting...',
  }))

  SetState({
    status: 'processing',
    total: Ids.length,
    done: 0,
    ok: 0,
    failed: 0,
    mapping: {},
    error: null,
    failReasons: {},
    sessionDir: SessionDir,
    sessionName: SessionName,
    outputs: Outputs,
  })

  const CsrfToken = await FetchCsrfToken(Cfg.cookie)
  const UserId = await FetchUserId(Cfg.cookie)

  if (!UserId) {
    SetState({ status: 'error', error: 'Could not resolve user ID from cookie. Cookie may be expired.' })
    return
  }

  const CONCURRENCY = 8
  const Queue = [...Ids]
  const Mapping: Record<string, string> = {}
  const FailReasons: Record<string, number> = {}
  let Done = 0, Ok = 0, Failed = 0
  const EffPlaceIds = PlaceIds

  const BumpReason = (Msg: string | null): void => {
    const Key = (Msg ?? 'unknown error').slice(0, 80)
    FailReasons[Key] = (FailReasons[Key] ?? 0) + 1
  }

  const Worker = async (): Promise<void> => {
    while (Queue.length > 0) {
      const Id = Queue.shift()
      if (!Id) break

      const Index = Ids.indexOf(Id)
      const Entry = Outputs[Index]
      Entry.status = 'Downloading...'
      SetState({ outputs: [...Outputs] })

      const SoundName = SanitizeName(Names[Id] || 'Sound')
      const CleanName = `${Entry.index}_(${SoundName})_${Id}`

      const DlResult = await DownloadSound(Id, SessionDir, Cfg.cookie, CsrfToken, Cfg.apiKey, EffPlaceIds, CleanName)

      if (!DlResult.Ok || !DlResult.FilePath) {
        Done++
        Failed++
        BumpReason(`[download] ${DlResult.Error}`)
        Entry.newId = 'Failed'
        Entry.status = `[download] ${DlResult.Error}`
        SetState({ done: Done, ok: Ok, failed: Failed, mapping: { ...Mapping }, failReasons: { ...FailReasons }, outputs: [...Outputs] })
        continue
      }

      Entry.status = 'Uploading...'
      SetState({ outputs: [...Outputs] })

      const UlResult = await UploadSound(DlResult.FilePath, Id, Cfg.apiKey, UserId, CreatorType, CreatorId)

      Done++
      if (UlResult.Ok && UlResult.NewId) {
        Ok++
        Mapping[Id] = UlResult.NewId
        Entry.newId = UlResult.NewId
        Entry.status = 'Success'
      } else {
        Failed++
        BumpReason(`[upload] ${UlResult.Error}`)
        Entry.newId = 'Failed'
        Entry.status = `[upload] ${UlResult.Error}`
      }
      SetState({ done: Done, ok: Ok, failed: Failed, mapping: { ...Mapping }, failReasons: { ...FailReasons }, outputs: [...Outputs] })
    }
  }

  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, Ids.length) }, Worker))

  try {
    fs.writeFileSync(join(SessionDir, 'mapping.json'), JSON.stringify(Mapping, null, 2))
  } catch {}

  SetState({ status: 'complete', done: Done, ok: Ok, failed: Failed, mapping: { ...Mapping }, failReasons: { ...FailReasons }, outputs: [...Outputs] })
}

function HandleRequest(Req: http.IncomingMessage, Res: http.ServerResponse): void {
  Res.setHeader('Access-Control-Allow-Origin', '*')
  Res.setHeader('Content-Type', 'application/json')

  if (Req.method === 'POST' && Req.url === '/sounds-process') {
    if (State.status === 'processing') {
      Res.writeHead(409)
      Res.end(JSON.stringify({ error: 'job already running' }))
      return
    }

    let Body = ''
    Req.on('data', (Chunk) => { Body += Chunk })
    Req.on('end', () => {
      try {
        const Data = JSON.parse(Body) as { ids?: string[]; names?: Record<string, string>; placeIds?: string[]; creatorType?: string; creatorId?: number }
        const Ids = (Data.ids ?? []).filter((Id) => /^\d+$/.test(Id))
        if (Ids.length === 0) {
          Res.writeHead(400)
          Res.end(JSON.stringify({ error: 'no valid IDs received' }))
          return
        }
        Res.writeHead(200)
        Res.end(JSON.stringify({ ok: true, count: Ids.length }))
        RunJob(Ids, Data.names ?? {}, Data.placeIds ?? [], Data.creatorType ?? 'User', Data.creatorId ?? 0)
      } catch {
        Res.writeHead(400)
        Res.end(JSON.stringify({ error: 'invalid JSON' }))
      }
    })
    return
  }

  if (Req.method === 'GET' && Req.url === '/sounds-status') {
    Res.writeHead(200)
    Res.end(JSON.stringify(State))
    return
  }

  Res.writeHead(404)
  Res.end(JSON.stringify({ error: 'not found' }))
}

function StartHttpServer(): void {
  HttpServer = http.createServer(HandleRequest)
  HttpServer.listen(ServerPort, '127.0.0.1', () => {
    MainWindow?.webContents.send('server-status', { listening: true, port: ServerPort })
  })
  HttpServer.on('error', (Err) => {
    MainWindow?.webContents.send('server-status', { listening: false, error: Err.message })
  })
}

const IsInstallerArg = process.argv.includes('--installer')

const IsInstaller =
  process.env.PORTABLE_EXECUTABLE_DIR !== undefined ||
  app.getPath('exe').toLowerCase().includes('setup') ||
  IsInstallerArg

const GetDefaultInstallDir = (): string => join(app.getPath('home'), 'AppData', 'Local', 'barbs-snatcher')

function CreateShortcut(TargetExe: string, ShortcutPath: string): void {
  const Dir = dirname(ShortcutPath)
  if (!fs.existsSync(Dir)) {
    fs.mkdirSync(Dir, { recursive: true })
  }
  const Command = `$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut("${ShortcutPath}"); $Shortcut.TargetPath = "${TargetExe}"; $Shortcut.Save();`
  try {
    execSync(`powershell -NoProfile -ExecutionPolicy Bypass -Command "${Command}"`)
  } catch {}
}

function DownloadFile(Url: string, DestPath: string): Promise<void> {
  return new Promise((Resolve, Reject) => {
    const Protocol = Url.startsWith('https') ? https : http
    const Req = Protocol.get(Url, (Res) => {
      if (Res.statusCode && Res.statusCode >= 300 && Res.statusCode < 400 && Res.headers.location) {
        DownloadFile(Res.headers.location, DestPath).then(Resolve).catch(Reject)
        return
      }
      if (Res.statusCode !== 200) {
        Reject(new Error(`Failed to download: ${Res.statusCode}`))
        return
      }
      const FileStream = fs.createWriteStream(DestPath)
      Res.pipe(FileStream)
      FileStream.on('finish', () => {
        FileStream.close()
        Resolve()
      })
      FileStream.on('error', (Err) => {
        fs.unlink(DestPath, () => {})
        Reject(Err)
      })
    })
    Req.on('error', Reject)
  })
}

function CopyFolderSync(From: string, To: string): void {
  fs.mkdirSync(To, { recursive: true })
  const Names = fs.readdirSync(From)
  for (const Name of Names) {
    const Src = join(From, Name)
    const Dest = join(To, Name)
    const Stat = fs.lstatSync(Src)
    if (Stat.isDirectory() && !Name.endsWith('.asar')) {
      CopyFolderSync(Src, Dest)
    } else {
      fs.copyFileSync(Src, Dest)
    }
  }
}

function CreateInstallerWindow(): void {
  MainWindow = new BrowserWindow({
    width: 600,
    height: 560,
    show: false,
    autoHideMenuBar: true,
    frame: false,
    resizable: false,
    title: "Barb's Snatcher Installer",
    icon: Icon,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false,
    },
  })

  MainWindow.on('ready-to-show', () => {
    MainWindow!.show()
    MainWindow!.focus()
  })

  if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
    MainWindow.loadURL(`${process.env['ELECTRON_RENDERER_URL']}?mode=installer`)
  } else {
    MainWindow.loadFile(join(__dirname, '../renderer/index.html'), { query: { mode: 'installer' } })
  }
}

function CreateWindow(): void {
  MainWindow = new BrowserWindow({
    width: 920,
    height: 660,
    show: false,
    autoHideMenuBar: true,
    frame: false,
    titleBarStyle: 'hidden',
    icon: Icon,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false,
    },
  })

  MainWindow.on('ready-to-show', () => {
    MainWindow!.show()
    MainWindow!.focus()
  })

  setTimeout(() => {
    if (MainWindow && !MainWindow.isVisible()) {
      MainWindow.show()
      MainWindow.focus()
    }
  }, 5000)

  MainWindow.webContents.setWindowOpenHandler((Details) => {
    shell.openExternal(Details.url)
    return { action: 'deny' }
  })

  if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
    MainWindow.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    MainWindow.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

if (IsInstallerArg) {
  try {
    const D = dirname(process.execPath)
    fs.writeFileSync(join(D, 'version.json'), JSON.stringify({ version: app.getVersion() }))
    fs.writeFileSync(join(D, '.installer-version'), app.getVersion())
  } catch {}
}

app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.barbssnatcher.app')
  app.on('browser-window-created', (_, W) => optimizer.watchWindowShortcuts(W))

  if (IsInstaller) {
    CreateInstallerWindow()
  } else {
    CreateWindow()
    StartHttpServer()
  }

  ipcMain.handle('get-changelog', () => {
    try {
      const P = app.isPackaged
        ? join(process.resourcesPath, 'changelog.json')
        : join(__dirname, '../../resources/changelog.json')
      return JSON.parse(fs.readFileSync(P, 'utf-8'))
    } catch {
      return []
    }
  })

  ipcMain.handle('check-latest-release', async () => {
    try {
      const Res = await fetch('https://api.github.com/repos/barbecueIs/barbs-snatcher/releases/latest', {
        headers: { 'User-Agent': 'barbs-snatcher-launcher', Accept: 'application/vnd.github+json' },
        signal: AbortSignal.timeout(8000),
      })
      if (!Res.ok) return null
      const Body = await Res.json() as { tag_name?: string; assets?: { name?: string; browser_download_url?: string }[] }
      const Version = (Body.tag_name ?? '').replace(/^v/, '') || null
      const Assets = Body.assets ?? []
      const NsisAsset = Assets.find((A) => A.name?.endsWith('-setup.exe') && !A.name?.includes('squirrel'))
      const NupkgAsset = Assets.find((A) => A.name?.includes('full') && A.name?.endsWith('.nupkg'))
      const DownloadUrl = NsisAsset?.browser_download_url ?? NupkgAsset?.browser_download_url ?? null
      return { version: Version, downloadUrl: DownloadUrl }
    } catch {
      return null
    }
  })

  ipcMain.handle('get-app-version', () => app.getVersion())
  ipcMain.handle('load-config', () => LoadConfig())
  ipcMain.handle('save-config', (_E, Data: Config) => { SaveConfig(Data); return { ok: true } })
  ipcMain.handle('get-job-state', () => State)
  ipcMain.handle('get-server-port', () => ServerPort)
  ipcMain.handle('get-downloads-path', () => EffectiveDownloadsBase())

  ipcMain.handle('select-download-dir', async () => {
    if (!MainWindow) return null
    const Result = await dialog.showOpenDialog(MainWindow, {
      properties: ['openDirectory', 'createDirectory'],
      title: 'Select Download Output Directory',
      defaultPath: EffectiveDownloadsBase(),
    })
    if (Result.canceled || !Result.filePaths[0]) return null
    return Result.filePaths[0]
  })

  ipcMain.handle('select-install-dir', async () => {
    if (!MainWindow) return null
    const Result = await dialog.showOpenDialog(MainWindow, {
      properties: ['openDirectory', 'createDirectory'],
      title: 'Select Installation Directory',
      defaultPath: GetDefaultInstallDir(),
    })
    if (Result.canceled || !Result.filePaths[0]) return null
    return Result.filePaths[0]
  })

  ipcMain.handle('select-nupkg-file', async () => {
    if (!MainWindow) return null
    const Result = await dialog.showOpenDialog(MainWindow, {
      properties: ['openFile'],
      filters: [{ name: 'NuGet Packages', extensions: ['nupkg'] }],
      title: 'Select Squirrel NuGet Package (.nupkg)',
    })
    if (Result.canceled || !Result.filePaths[0]) return null
    return Result.filePaths[0]
  })

  ipcMain.handle('check-install-status', (_E, TargetPath: string) => {
    const Dest = TargetPath || GetDefaultInstallDir()
    const ExeExists = fs.existsSync(join(Dest, 'barbs-snatcher.exe'))
    let InstalledVersion = ''
    let Broken = false
    if (fs.existsSync(Dest)) {
      const Files = fs.readdirSync(Dest)
      if (Files.length > 0 && !ExeExists) {
        Broken = true
      }
      const VerPath = join(Dest, 'version.json')
      if (fs.existsSync(VerPath)) {
        try {
          const Raw = JSON.parse(fs.readFileSync(VerPath, 'utf-8'))
          InstalledVersion = Raw.version ?? ''
        } catch {}
      }
    }
    return {
      installed: ExeExists || Broken,
      broken: Broken,
      installedVersion: InstalledVersion,
      currentVersion: app.getVersion(),
    }
  })

  ipcMain.handle('install-app', async (_E, Args: { sourcePathOrUrl: string; targetPath: string; openAfter: boolean; createShortcut: boolean }) => {
    const Dest = Args.targetPath || GetDefaultInstallDir()
    const ExePath = join(Dest, 'barbs-snatcher.exe')
    if (fs.existsSync(ExePath)) {
      try {
        const F = fs.openSync(ExePath, 'r+')
        fs.closeSync(F)
      } catch {
        return { ok: false, error: 'The application is currently running. Please close it before installing.' }
      }
    }

    try {
      fs.mkdirSync(Dest, { recursive: true })
      let Source = Args.sourcePathOrUrl.trim()
      let NupkgFile = ''

      if (Source) {
        if (Source.startsWith('http://') || Source.startsWith('https://')) {
          const TempPath = join(app.getPath('temp'), 'barbs-snatcher-download.nupkg')
          await DownloadFile(Source, TempPath)
          NupkgFile = TempPath
        } else {
          if (fs.existsSync(Source)) {
            if (fs.statSync(Source).isDirectory()) {
              const Files = fs.readdirSync(Source)
              const Matches = Files.filter((F) => F.endsWith('.nupkg'))
              if (Matches.length > 0) {
                NupkgFile = join(Source, Matches[0])
              }
            } else if (Source.endsWith('.nupkg')) {
              NupkgFile = Source
            }
          }
        }
      }

      if (NupkgFile && fs.existsSync(NupkgFile)) {
        const Zip = new AdmZip(NupkgFile)
        const ZipEntries = Zip.getEntries()
        const OriginalNoAsar = process.noAsar
        process.noAsar = true
        try {
          for (const Entry of ZipEntries) {
            if (Entry.entryName.startsWith('lib/net45/')) {
              const RelPath = Entry.entryName.substring('lib/net45/'.length)
              if (!RelPath) continue
              const DestFile = join(Dest, RelPath)
              if (Entry.isDirectory) {
                fs.mkdirSync(DestFile, { recursive: true })
              } else {
                fs.mkdirSync(dirname(DestFile), { recursive: true })
                fs.writeFileSync(DestFile, Zip.readFile(Entry))
              }
            }
          }
        } finally {
          process.noAsar = OriginalNoAsar
        }
        if (Source.startsWith('http')) {
          try { fs.unlinkSync(NupkgFile) } catch {}
        }
      } else {
        const CurrentDir = dirname(process.execPath)
        const IsSameDir = normalize(resolve(CurrentDir)) === normalize(resolve(Dest))
        if (!IsSameDir) {
          const OriginalNoAsar = process.noAsar
          process.noAsar = true
          try {
            CopyFolderSync(CurrentDir, Dest)
          } finally {
            process.noAsar = OriginalNoAsar
          }
        }
      }

      fs.writeFileSync(join(Dest, 'version.json'), JSON.stringify({ version: app.getVersion() }))

      if (Args.createShortcut) {
        const DesktopLnk = join(app.getPath('desktop'), "Barb's Snatcher.lnk")
        CreateShortcut(ExePath, DesktopLnk)
        const StartMenuLnk = join(app.getPath('appData'), 'Microsoft', 'Windows', 'Start Menu', 'Programs', "Barb's Snatcher.lnk")
        CreateShortcut(ExePath, StartMenuLnk)
      }

      if (Args.openAfter) {
        const Env = { ...process.env }
        delete Env.PORTABLE_EXECUTABLE_PATH
        delete Env.PORTABLE_EXECUTABLE_DIR
        delete Env.PORTABLE_EXECUTABLE_APP_FILENAME
        spawn(ExePath, [], { detached: true, stdio: 'ignore', env: Env }).unref()
      }

      return { ok: true }
    } catch (Err: any) {
      return { ok: false, error: Err.message || 'Unknown error occurred during installation.' }
    }
  })

  ipcMain.handle('launch-installed-app', (_E, TargetPath: string) => {
    const Dest = TargetPath || GetDefaultInstallDir()
    const ExePath = join(Dest, 'barbs-snatcher.exe')
    if (fs.existsSync(ExePath)) {
      const Env = { ...process.env }
      delete Env.PORTABLE_EXECUTABLE_PATH
      delete Env.PORTABLE_EXECUTABLE_DIR
      delete Env.PORTABLE_EXECUTABLE_APP_FILENAME
      spawn(ExePath, [], { detached: true, stdio: 'ignore', env: Env }).unref()
      app.quit()
      return { ok: true }
    }
    return { ok: false, error: 'Executable not found.' }
  })

  ipcMain.handle('download-and-launch-update', async (_E, Url: string) => {
    const TempPath = join(app.getPath('temp'), 'barbs-snatcher-update.exe')
    try {
      MainWindow?.webContents.send('update-download-progress', 5)
      await DownloadFile(Url, TempPath)
      MainWindow?.webContents.send('update-download-progress', 100)
      spawn(TempPath, [], { detached: true, stdio: 'ignore' }).unref()
      setTimeout(() => app.quit(), 600)
      return { ok: true }
    } catch (Err) {
      return { ok: false, error: Err instanceof Error ? Err.message : 'download failed' }
    }
  })

  ipcMain.on('window-minimize', () => BrowserWindow.getFocusedWindow()?.minimize())
  ipcMain.on('window-maximize', () => {
    const W = BrowserWindow.getFocusedWindow()
    if (W?.isMaximized()) W.unmaximize()
    else W?.maximize()
  })
  ipcMain.on('window-close', () => BrowserWindow.getFocusedWindow()?.close())

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      if (IsInstaller) {
        CreateInstallerWindow()
      } else {
        CreateWindow()
      }
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
