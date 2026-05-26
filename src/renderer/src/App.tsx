import { useState, useEffect, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  LayoutDashboard, Settings, Star, Minus, Square, X,
  Wifi, Key, Cookie, Download, CheckCircle, XCircle,
  ChevronRight, Activity, FolderOpen, Terminal, FolderSearch,
  Info, AlertTriangle,
} from 'lucide-react'

const cVar = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.07 } },
  exit: { opacity: 0, transition: { duration: 0.15 } },
}
const iVar = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { type: 'spring', stiffness: 320, damping: 26 } },
}

interface Config { cookie: string; apiKey: string; placeId: string; downloadPath: string }
interface ServerStatus { listening: boolean; port?: number; error?: string }

function CyberButton({
  children,
  className = '',
  disabled,
  onClick,
}: {
  children: React.ReactNode
  className?: string
  disabled?: boolean
  onClick?: () => void
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`relative inline-flex items-center justify-center gap-2 px-6 py-3 font-display font-bold text-sm uppercase tracking-widest text-primary-foreground bg-primary border-2 border-primary brutalist-shadow transition-all disabled:opacity-40 disabled:cursor-not-allowed disabled:transform-none ${className}`}
    >
      {children}
    </button>
  )
}

function StatusDot({ ok }: { ok: boolean }) {
  return (
    <span className={`inline-block w-2 h-2 rounded-full ${ok ? 'bg-primary animate-pulse' : 'bg-muted-foreground'}`} />
  )
}

function StatusCard({
  icon: Icon,
  label,
  value,
  sub,
  ok,
}: {
  icon: React.ElementType
  label: string
  value: string
  sub?: string
  ok: boolean
}) {
  return (
    <div className="border-2 border-border bg-card p-6 flex flex-col gap-4 relative group overflow-hidden">
      <div className="absolute top-0 right-0 p-3 opacity-5 font-display text-7xl font-black pointer-events-none select-none group-hover:opacity-10 transition-opacity text-primary">
        <Icon size={64} />
      </div>
      <div className="flex items-center gap-2">
        <StatusDot ok={ok} />
        <span className="text-[9px] font-mono uppercase tracking-[0.3em] text-muted-foreground">{label}</span>
      </div>
      <div className="relative z-10">
        <p className={`font-display font-bold text-lg uppercase tracking-tight ${ok ? 'text-primary' : 'text-muted-foreground'}`}>
          {value}
        </p>
        {sub ? <p className="text-[9px] font-mono text-muted-foreground mt-1 uppercase tracking-widest">{sub}</p> : null}
      </div>
    </div>
  )
}

function ProgressBar({ value, max }: { value: number; max: number }) {
  const Pct = max > 0 ? Math.min((value / max) * 100, 100) : 0
  return (
    <div className="w-full h-3 border-2 border-border bg-black/50 overflow-hidden p-0.5">
      <motion.div
        className="h-full bg-primary"
        initial={{ width: 0 }}
        animate={{ width: `${Pct}%` }}
        transition={{ ease: 'linear', duration: 0.3 }}
      />
    </div>
  )
}

function MenuView({ config, serverStatus }: { config: Config; serverStatus: ServerStatus }) {
  const [JobState, SetJobState] = useState<JobState>({
    status: 'idle', total: 0, done: 0, ok: 0, failed: 0,
    mapping: {}, error: null, failReasons: {}, sessionDir: null, sessionName: null,
  })
  const [DownloadsPath, SetDownloadsPath] = useState('')

  useEffect(() => {
    window.api.getJobState().then(SetJobState)
    window.api.getDownloadsPath().then(SetDownloadsPath)
    window.api.onJobUpdate(SetJobState as (s: unknown) => void)
    return () => window.api.removeListeners()
  }, [])

  const CookieOk = !!config.cookie
  const ApiKeyOk = !!config.apiKey
  const NetworkOk = serverStatus.listening

  return (
    <motion.div variants={cVar} initial="hidden" animate="show" exit="exit" className="flex flex-col gap-8 w-full max-w-5xl mx-auto">
      <motion.div variants={iVar} className="border-l-4 border-primary pl-6 py-2">
        <h2 className="text-4xl font-display font-bold uppercase tracking-tight text-white">System Status</h2>
        <p className="text-muted-foreground mt-2 font-mono text-sm">REAL-TIME OVERVIEW OF ALL SERVICE COMPONENTS.</p>
      </motion.div>

      <motion.div variants={iVar} className="grid grid-cols-3 gap-6">
        <StatusCard
          icon={Cookie}
          label="Cookie"
          value={CookieOk ? 'Set' : 'Not Set'}
          sub={CookieOk ? `${config.cookie.length} chars` : 'required for downloads'}
          ok={CookieOk}
        />
        <StatusCard
          icon={Wifi}
          label="Network"
          value={NetworkOk ? 'Listening' : 'Offline'}
          sub={NetworkOk ? `:${serverStatus.port ?? 54321} — ready for Studio` : (serverStatus.error ?? 'server not started')}
          ok={NetworkOk}
        />
        <StatusCard
          icon={Key}
          label="API Key"
          value={ApiKeyOk ? 'Set' : 'Not Set'}
          sub={ApiKeyOk ? `${config.apiKey.length} chars` : 'required for reuploads'}
          ok={ApiKeyOk}
        />
      </motion.div>

      {JobState.status !== 'idle' ? (
        <motion.div
          variants={iVar}
          className="border-2 border-border bg-card p-8 flex flex-col gap-6 relative overflow-hidden"
        >
          <div className="absolute top-0 right-0 p-4 opacity-5 font-display text-8xl font-black pointer-events-none select-none text-primary">
            JOB
          </div>
          <div className="flex items-center justify-between relative z-10">
            <div>
              <label className="text-xs font-bold font-display uppercase tracking-widest text-primary flex items-center gap-2">
                <Activity size={14} />
                {JobState.status === 'processing' ? 'Live Job' : JobState.status === 'complete' ? 'Last Session' : 'Job Error'}
              </label>
              {JobState.sessionName ? (
                <p className="font-mono text-[10px] text-muted-foreground mt-1 uppercase tracking-widest">
                  {JobState.sessionName}
                </p>
              ) : null}
            </div>
            <div className="flex items-center gap-2">
              {JobState.status === 'processing' ? (
                <span className="text-[9px] font-mono uppercase tracking-widest text-primary animate-pulse flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-primary animate-ping inline-block" />
                  Processing
                </span>
              ) : JobState.status === 'complete' ? (
                <span className="text-[9px] font-mono uppercase tracking-widest text-primary flex items-center gap-2">
                  <CheckCircle size={12} />
                  Complete
                </span>
              ) : (
                <span className="text-[9px] font-mono uppercase tracking-widest text-destructive flex items-center gap-2">
                  <XCircle size={12} />
                  Error
                </span>
              )}
            </div>
          </div>

          {JobState.error ? (
            <p className="font-mono text-xs text-destructive border-2 border-destructive/30 bg-destructive/5 p-3">
              {JobState.error}
            </p>
          ) : null}

          {JobState.total > 0 && !JobState.error ? (
            <div className="flex flex-col gap-3 relative z-10">
              <ProgressBar value={JobState.done} max={JobState.total} />
              <div className="flex justify-between font-mono text-[10px] uppercase tracking-widest text-muted-foreground">
                <span>{JobState.done} / {JobState.total} sounds</span>
                <span className="flex gap-4">
                  <span className="text-primary">{JobState.ok} ok</span>
                  {JobState.failed > 0 ? <span className="text-destructive">{JobState.failed} failed</span> : null}
                </span>
              </div>
            </div>
          ) : null}

          {JobState.failed > 0 && Object.keys(JobState.failReasons).length > 0 ? (
            <div className="flex flex-col gap-2 border-2 border-destructive/30 bg-destructive/5 p-4 relative z-10">
              <p className="font-mono text-[9px] uppercase tracking-widest text-destructive font-bold">Failure Breakdown</p>
              {Object.entries(JobState.failReasons)
                .sort(([, A], [, B]) => B - A)
                .map(([Reason, Count]) => (
                  <div key={Reason} className="flex items-start justify-between gap-4">
                    <span className="font-mono text-[9px] text-muted-foreground break-all">{Reason}</span>
                    <span className="font-mono text-[9px] text-destructive shrink-0">{Count}x</span>
                  </div>
                ))}
            </div>
          ) : null}

          {JobState.status === 'complete' && JobState.sessionDir ? (
            <div className="flex items-center gap-3 border-2 border-border bg-black/40 p-3 relative z-10">
              <FolderOpen size={14} className="text-primary shrink-0" />
              <p className="font-mono text-[9px] text-muted-foreground uppercase tracking-widest truncate">
                {JobState.sessionDir}
              </p>
            </div>
          ) : null}
        </motion.div>
      ) : null}

      <motion.div variants={iVar} className="border-2 border-border bg-black/30 p-5">
        <div className="flex items-start gap-3">
          <Terminal size={13} className="text-primary mt-0.5 shrink-0" />
          <div className="font-mono text-[10px] text-muted-foreground space-y-1 uppercase tracking-wider">
            <p>&gt; Install the Studio plugin from <span className="text-primary">plugin/snatcher_plugin.lua</span></p>
            <p>&gt; Run it in Roblox Studio — it will connect to this app automatically</p>
            <p>&gt; Downloads saved to <span className="text-primary truncate inline-block max-w-xs align-bottom">{DownloadsPath || '...'}</span></p>
          </div>
        </div>
      </motion.div>
    </motion.div>
  )
}

function InputField({
  label,
  value,
  onChange,
  placeholder,
  hint,
  steps,
  currentCharCount,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder: string
  hint?: string
  steps?: string[]
  currentCharCount?: number
}) {
  return (
    <div className="border-2 border-border bg-card p-8 flex flex-col gap-6 relative group overflow-hidden">
      <div className="absolute top-0 right-0 p-4 opacity-5 font-display text-7xl font-black pointer-events-none select-none text-primary">
        {label.slice(0, 3)}
      </div>
      <label className="text-xs font-bold font-display uppercase tracking-widest text-primary flex items-center gap-2 relative z-10">
        <ChevronRight size={14} />
        {label}
      </label>
      {steps ? (
        <div className="flex flex-col gap-1 relative z-10">
          {steps.map((S, I) => (
            <p key={I} className="font-mono text-[10px] text-muted-foreground uppercase tracking-widest">
              {S}
            </p>
          ))}
        </div>
      ) : null}
      {currentCharCount !== undefined && currentCharCount > 0 ? (
        <div className="flex items-center gap-2 relative z-10">
          <StatusDot ok />
          <span className="font-mono text-[9px] text-primary uppercase tracking-widest">
            current: {currentCharCount} chars set
          </span>
        </div>
      ) : null}
      <input
        type="password"
        value={value}
        onChange={(E) => onChange(E.target.value)}
        placeholder={placeholder}
        className="w-full border-2 border-border bg-black/50 p-3 font-mono text-xs text-foreground placeholder:text-muted-foreground/40 outline-none focus:border-primary transition-colors relative z-10"
      />
      {hint ? (
        <p className="text-[9px] font-mono text-muted-foreground uppercase tracking-widest relative z-10">
          {hint}
        </p>
      ) : null}
    </div>
  )
}

function SettingsView({ config, onSave }: { config: Config; onSave: (c: Config) => void }) {
  const [Cookie, SetCookie] = useState('')
  const [ApiKey, SetApiKey] = useState('')
  const [PlaceId, SetPlaceId] = useState(config.placeId)
  const [DownloadPath, SetDownloadPath] = useState(config.downloadPath)

  useEffect(() => {
    SetPlaceId(config.placeId)
    SetDownloadPath(config.downloadPath)
  }, [config.placeId, config.downloadPath])
  const [EffectivePath, SetEffectivePath] = useState('')
  const [Saved, SetSaved] = useState(false)

  useEffect(() => {
    window.api.getDownloadsPath().then(SetEffectivePath)
  }, [DownloadPath])

  const HandleBrowse = useCallback(async () => {
    const Selected = await window.api.selectDownloadDir()
    if (Selected) SetDownloadPath(Selected)
  }, [])

  const HandleClearPath = useCallback(() => {
    SetDownloadPath('')
  }, [])

  const HandleSave = useCallback(async () => {
    const Next: Config = {
      cookie: Cookie || config.cookie,
      apiKey: ApiKey || config.apiKey,
      placeId: PlaceId,
      downloadPath: DownloadPath,
    }
    await window.api.saveConfig(Next)
    onSave(Next)
    SetCookie('')
    SetApiKey('')
    SetSaved(true)
    setTimeout(() => SetSaved(false), 1500)
  }, [Cookie, ApiKey, PlaceId, DownloadPath, config, onSave])

  return (
    <motion.div variants={cVar} initial="hidden" animate="show" exit="exit" className="flex flex-col gap-8 w-full max-w-5xl mx-auto">
      <motion.div variants={iVar} className="border-l-4 border-primary pl-6 py-2">
        <h2 className="text-4xl font-display font-bold uppercase tracking-tight text-white">Settings</h2>
        <p className="text-muted-foreground mt-2 font-mono text-sm">CONFIGURE AUTHENTICATION AND DOWNLOAD OPTIONS.</p>
      </motion.div>

      <motion.div variants={iVar} className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <InputField
          label="Cookie"
          value={Cookie}
          onChange={SetCookie}
          placeholder="Paste .ROBLOSECURITY value..."
          currentCharCount={config.cookie.length}
          steps={[
            '  1. Open roblox.com and log in',
            '  2. Press F12 → Application → Cookies',
            '  3. Copy the value of .ROBLOSECURITY',
          ]}
          hint="Required for downloading assets from your account."
        />
        <InputField
          label="API Key"
          value={ApiKey}
          onChange={SetApiKey}
          placeholder="Paste Open Cloud API key..."
          currentCharCount={config.apiKey.length}
          steps={[
            '  1. Go to create.roblox.com/credentials',
            '  2. Create API Key → Assets API',
            '  3. Enable asset:read and asset:write',
          ]}
          hint="Required for reuploading assets to your account."
        />
      </motion.div>

      <motion.div variants={iVar} className="border-2 border-border bg-card p-8 flex flex-col gap-4">
        <label className="text-xs font-bold font-display uppercase tracking-widest text-primary flex items-center gap-2">
          <ChevronRight size={14} />
          Place ID (optional)
        </label>
        <input
          type="text"
          value={PlaceId}
          onChange={(E) => SetPlaceId(E.target.value)}
          placeholder="e.g. 103612159864425"
          className="w-full border-2 border-border bg-black/50 p-3 font-mono text-xs text-foreground placeholder:text-muted-foreground/40 outline-none focus:border-primary transition-colors"
        />
        <p className="text-[9px] font-mono text-muted-foreground uppercase tracking-widest">
          Helps Roblox CDN serve assets owned by the place. Optional but recommended.
        </p>
      </motion.div>

      <motion.div variants={iVar} className="border-2 border-border bg-card p-8 flex flex-col gap-6 relative group overflow-hidden">
        <div className="absolute top-0 right-0 p-4 opacity-5 font-display text-7xl font-black pointer-events-none select-none group-hover:opacity-10 transition-opacity text-primary">
          <FolderSearch size={64} />
        </div>
        <label className="text-xs font-bold font-display uppercase tracking-widest text-primary flex items-center gap-2 relative z-10">
          <ChevronRight size={14} />
          Download Output Directory
        </label>
        <div className="flex items-stretch gap-0 relative z-10">
          <div className="flex-1 border-2 border-r-0 border-border bg-black/50 p-3 font-mono text-xs text-foreground truncate">
            {DownloadPath || <span className="text-muted-foreground/60">{EffectivePath || '...'} (default)</span>}
          </div>
          <button
            onClick={HandleBrowse}
            className="shrink-0 border-2 border-border bg-black/50 px-4 text-muted-foreground hover:text-primary hover:border-primary hover:bg-primary/5 transition-all font-mono text-[10px] uppercase tracking-widest"
          >
            Browse
          </button>
          {DownloadPath ? (
            <button
              onClick={HandleClearPath}
              className="shrink-0 border-2 border-l-0 border-border bg-black/50 px-3 text-muted-foreground hover:text-destructive hover:border-destructive/40 transition-all"
            >
              <X size={12} />
            </button>
          ) : null}
        </div>
        <p className="text-[9px] font-mono text-muted-foreground uppercase tracking-widest relative z-10">
          Where session folders are created. Leave blank to use the default documents folder.
        </p>
      </motion.div>

      <motion.div variants={iVar}>
        <CyberButton onClick={HandleSave} className="w-full">
          {Saved ? <><CheckCircle size={16} /> Saved</> : <><Download size={16} /> Save Configuration</>}
        </CyberButton>
      </motion.div>
    </motion.div>
  )
}

function CreditsView() {
  return (
    <motion.div variants={cVar} initial="hidden" animate="show" exit="exit" className="flex flex-col gap-8 w-full max-w-5xl mx-auto">
      <motion.div variants={iVar} className="border-l-4 border-primary pl-6 py-2">
        <h2 className="text-4xl font-display font-bold uppercase tracking-tight text-white">Credits</h2>
        <p className="text-muted-foreground mt-2 font-mono text-sm">THE PEOPLE BEHIND THIS TOOL.</p>
      </motion.div>

      <motion.div variants={iVar} className="border-2 border-border bg-card p-12 flex flex-col items-center gap-8 relative overflow-hidden">
        <div className="absolute inset-0 bg-grid-pattern opacity-60 pointer-events-none" />
        <div className="relative z-10 text-center flex flex-col items-center gap-6">
          <div className="border-2 border-primary bg-primary/10 px-8 py-4">
            <h1 className="font-display font-black text-3xl uppercase tracking-tighter text-white">
              Barb&apos;s <span className="text-primary">Snatcher</span>
            </h1>
            <p className="font-mono text-[10px] text-primary tracking-[0.3em] mt-1">SOUND ASSET TOOL v1.0.0</p>
          </div>

          <div className="border-2 border-border bg-black/50 px-10 py-6 flex flex-col items-center gap-3">
            <div className="w-full h-px bg-border" />
            <div className="flex flex-col items-center gap-1">
              <p className="font-display font-bold text-xl uppercase tracking-widest text-primary">Barbecue</p>
              <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-muted-foreground">
                Coder and maker of Barb&apos;s Snatcher
              </p>
            </div>
            <div className="w-full h-px bg-border" />
          </div>

          <p className="font-mono text-[9px] text-muted-foreground uppercase tracking-widest max-w-sm text-center">
            Built with Electron, React, and TypeScript.
          </p>
        </div>
      </motion.div>
    </motion.div>
  )
}

function SidebarItem({
  icon: Icon,
  label,
  active,
  onClick,
}: {
  icon: React.ElementType
  label: string
  active: boolean
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={`w-full flex items-center gap-4 px-6 py-4 transition-all font-display uppercase tracking-widest text-sm font-bold border-l-4 ${
        active
          ? 'border-primary bg-primary/10 text-primary'
          : 'border-transparent text-muted-foreground hover:bg-white/5 hover:text-white hover:border-white/10'
      }`}
    >
      <Icon size={18} className={active ? 'text-primary' : ''} />
      {label}
    </button>
  )
}

const IsInstallerMode = new URLSearchParams(window.location.search).get('mode') === 'installer'

interface InstallStatus {
  installed: boolean
  broken: boolean
  installedVersion: string
  currentVersion: string
}

function InstallerPage() {
  const [InstallPath, SetInstallPath] = useState('')
  const [SourcePath, SetSourcePath] = useState('')
  const [Status, SetStatus] = useState<InstallStatus | null>(null)
  const [Progress, SetProgress] = useState(0)
  const [StatusText, SetStatusText] = useState('')
  const [OpenAfter, SetOpenAfter] = useState(true)
  const [CreateShortcut, SetCreateShortcut] = useState(true)
  const [Screen, SetScreen] = useState<'welcome' | 'installing' | 'success' | 'error'>('welcome')
  const [ErrorMessage, SetErrorMessage] = useState('')

  const RefreshStatus = useCallback(async (Path: string) => {
    const Res = await window.api.checkInstallStatus(Path)
    SetStatus(Res)
  }, [])

  useEffect(() => {
    const DefaultPath = `C:\\Users\\${window.process?.env?.USERNAME || 'Bar2D2'}\\AppData\\Local\\barbs-snatcher`
    SetInstallPath(DefaultPath)
    RefreshStatus(DefaultPath)
  }, [RefreshStatus])

  const HandleBrowseInstallDir = async () => {
    const Selected = await window.api.selectInstallDir()
    if (Selected) {
      SetInstallPath(Selected)
      RefreshStatus(Selected)
    }
  }

  const HandleBrowseSource = async () => {
    const Selected = await window.api.selectNupkgFile()
    if (Selected) {
      SetSourcePath(Selected)
    }
  }

  const RunInstallation = async (Action: 'install' | 'repair' | 'update' | 'reinstall') => {
    SetScreen('installing')
    SetProgress(10)
    SetStatusText('Initializing...')

    const Interval = setInterval(() => {
      SetProgress((Prev) => {
        if (Prev >= 90) {
          clearInterval(Interval)
          return 90
        }
        return Prev + 10
      })
    }, 400)

    if (Action === 'repair') {
      SetStatusText('Repairing installation...')
    } else if (Action === 'update') {
      SetStatusText('Updating version...')
    } else {
      SetStatusText('Installing files...')
    }

    const Result = await window.api.installApp({
      sourcePathOrUrl: SourcePath,
      targetPath: InstallPath,
      openAfter: OpenAfter,
      createShortcut: CreateShortcut,
    })

    clearInterval(Interval)

    if (Result.ok) {
      SetProgress(100)
      SetStatusText('Completed!')
      setTimeout(() => {
        if (OpenAfter) {
          window.api.close()
        } else {
          SetScreen('success')
        }
      }, 1000)
    } else {
      SetErrorMessage(Result.error || 'Installation failed.')
      SetScreen('error')
    }
  }

  const HandleLaunch = async () => {
    await window.api.launchInstalledApp(InstallPath)
  }

  return (
    <div className="h-screen w-full flex flex-col bg-background text-foreground overflow-hidden select-none relative p-8">
      <div className="noise-overlay" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30 pointer-events-none" />

      <div
        className="absolute top-0 left-0 w-full h-8 z-50 flex justify-end px-2 gap-1 items-center"
        style={{ WebkitAppRegion: 'drag' } as React.CSSProperties}
      >
        <button
          onClick={() => window.api.minimize()}
          className="p-1.5 hover:bg-white/10 text-muted-foreground pointer-events-auto transition-colors"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          <Minus size={13} />
        </button>
        <button
          onClick={() => window.api.close()}
          className="p-1.5 hover:bg-destructive text-muted-foreground pointer-events-auto transition-colors"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          <X size={13} />
        </button>
      </div>

      <div className="flex-1 flex flex-col justify-between relative z-10 pt-4">
        <header className="border-b-2 border-border pb-4 flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 text-primary mb-1">
              <Terminal size={12} />
              <span className="font-mono text-[9px] uppercase tracking-widest">setup.wizard</span>
            </div>
            <h1 className="font-display font-black text-xl uppercase tracking-tighter text-white">
              B-<span className="text-primary">Snatcher Setup</span>
            </h1>
          </div>
          {Status ? (
            <div className="font-mono text-[10px] text-muted-foreground text-right">
              <div>Installer v{Status.currentVersion}</div>
              {Status.installed && <div>Installed v{Status.installedVersion || 'unknown'}</div>}
            </div>
          ) : null}
        </header>

        <main className="flex-1 py-6 overflow-y-auto">
          {Screen === 'welcome' && (
            <div className="flex flex-col gap-5">
              <div className="flex flex-col gap-4">
                <div className="flex flex-col gap-2">
                  <label className="text-xs font-bold font-display uppercase tracking-widest text-primary flex items-center gap-2">
                    <ChevronRight size={14} />
                    Install Destination Directory
                  </label>
                  <div className="flex items-stretch gap-0">
                    <input
                      type="text"
                      value={InstallPath}
                      onChange={(E) => {
                        SetInstallPath(E.target.value)
                        RefreshStatus(E.target.value)
                      }}
                      className="flex-1 border-2 border-r-0 border-border bg-black/50 p-2 font-mono text-xs text-foreground outline-none focus:border-primary transition-colors"
                    />
                    <button
                      onClick={HandleBrowseInstallDir}
                      className="shrink-0 border-2 border-border bg-black/50 px-4 text-muted-foreground hover:text-primary hover:border-primary hover:bg-primary/5 transition-all font-mono text-[10px] uppercase tracking-widest"
                    >
                      Browse
                    </button>
                  </div>
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-xs font-bold font-display uppercase tracking-widest text-primary flex items-center gap-2">
                    <ChevronRight size={14} />
                    Download / nupkg Source (Optional)
                  </label>
                  <div className="flex items-stretch gap-0">
                    <input
                      type="text"
                      placeholder="Enter URL or file path, or leave empty to use built-in files..."
                      value={SourcePath}
                      onChange={(E) => SetSourcePath(E.target.value)}
                      className="flex-1 border-2 border-r-0 border-border bg-black/50 p-2 font-mono text-xs text-foreground placeholder:text-muted-foreground/30 outline-none focus:border-primary transition-colors"
                    />
                    <button
                      onClick={HandleBrowseSource}
                      className="shrink-0 border-2 border-border bg-black/50 px-4 text-muted-foreground hover:text-primary hover:border-primary hover:bg-primary/5 transition-all font-mono text-[10px] uppercase tracking-widest"
                    >
                      Select File
                    </button>
                  </div>
                </div>
              </div>

              {Status && (
                <div className="border-2 border-border bg-card p-4 flex flex-col gap-3">
                  {Status.broken ? (
                    <div className="flex items-start gap-2 text-destructive font-mono text-xs">
                      <AlertTriangle size={16} className="shrink-0 mt-0.5" />
                      <div>
                        <span className="font-bold">WARNING:</span> Installation at this location is broken. Click Repair to fix it.
                      </div>
                    </div>
                  ) : Status.installed ? (
                    <div className="flex items-start gap-2 text-primary font-mono text-xs">
                      <Info size={16} className="shrink-0 mt-0.5" />
                      <div>
                        Barb&apos;s Snatcher is already installed in this directory (v{Status.installedVersion || 'unknown'}).
                        {Status.installedVersion && Status.installedVersion !== Status.currentVersion && (
                          <span className="block mt-1 font-bold text-white">
                            {Status.installedVersion < Status.currentVersion
                              ? `An update is available (v${Status.installedVersion} -> v${Status.currentVersion}).`
                              : `Installed version is newer than installer version (v${Status.installedVersion} > v${Status.currentVersion}).`}
                          </span>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-start gap-2 text-muted-foreground font-mono text-xs">
                      <Info size={16} className="shrink-0 mt-0.5" />
                      <div>Ready to perform a clean installation of Barb&apos;s Snatcher v{Status.currentVersion}.</div>
                    </div>
                  )}
                </div>
              )}

              <div className="flex flex-col gap-2 font-mono text-xs border-2 border-border bg-black/30 p-4">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={OpenAfter}
                    onChange={(E) => SetOpenAfter(E.target.checked)}
                    className="accent-primary"
                  />
                  <span>Launch application after installation</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={CreateShortcut}
                    onChange={(E) => SetCreateShortcut(E.target.checked)}
                    className="accent-primary"
                  />
                  <span>Create Desktop & Start Menu Shortcuts</span>
                </label>
              </div>
            </div>
          )}

          {Screen === 'installing' && (
            <div className="flex flex-col gap-6 justify-center h-full">
              <div className="flex flex-col gap-2">
                <div className="flex justify-between font-mono text-xs uppercase tracking-widest text-muted-foreground">
                  <span>{StatusText}</span>
                  <span>{Progress}%</span>
                </div>
                <ProgressBar value={Progress} max={100} />
              </div>
            </div>
          )}

          {Screen === 'success' && (
            <div className="flex flex-col gap-6 items-center justify-center text-center h-full">
              <div className="border-2 border-primary bg-primary/10 p-6 rounded-full">
                <CheckCircle size={48} className="text-primary" />
              </div>
              <div className="flex flex-col gap-2">
                <h3 className="font-display font-bold text-lg uppercase tracking-tight text-white">Setup Completed</h3>
                <p className="font-mono text-xs text-muted-foreground">
                  Barb&apos;s Snatcher has been successfully configured.
                </p>
              </div>
            </div>
          )}

          {Screen === 'error' && (
            <div className="flex flex-col gap-6 items-center justify-center text-center h-full">
              <div className="border-2 border-destructive bg-destructive/10 p-6 rounded-full">
                <XCircle size={48} className="text-destructive" />
              </div>
              <div className="flex flex-col gap-2">
                <h3 className="font-display font-bold text-lg uppercase tracking-tight text-destructive">Installation Failed</h3>
                <p className="font-mono text-xs text-muted-foreground max-w-md break-words">
                  {ErrorMessage}
                </p>
              </div>
            </div>
          )}
        </main>

        <footer className="border-t-2 border-border pt-4 flex gap-4 justify-end">
          {Screen === 'welcome' && Status && (
            <>
              {Status.broken ? (
                <>
                  <CyberButton onClick={() => RunInstallation('repair')} className="border-destructive text-destructive bg-destructive/10">
                    Repair
                  </CyberButton>
                  <CyberButton onClick={() => RunInstallation('reinstall')}>
                    Reinstall
                  </CyberButton>
                </>
              ) : Status.installed ? (
                <>
                  <CyberButton onClick={HandleLaunch} className="border-primary text-primary bg-primary/10">
                    Launch
                  </CyberButton>
                  {Status.installedVersion && Status.installedVersion < Status.currentVersion ? (
                    <CyberButton onClick={() => RunInstallation('update')}>
                      Update
                    </CyberButton>
                  ) : (
                    <CyberButton onClick={() => RunInstallation('reinstall')}>
                      Reinstall
                    </CyberButton>
                  )}
                </>
              ) : (
                <CyberButton onClick={() => RunInstallation('install')}>
                  Install
                </CyberButton>
              )}
            </>
          )}

          {Screen === 'success' && (
            <>
              <CyberButton onClick={HandleLaunch}>
                Launch App
              </CyberButton>
              <CyberButton onClick={() => window.api.close()} className="border-muted bg-transparent text-muted-foreground">
                Exit
              </CyberButton>
            </>
          )}

          {Screen === 'error' && (
            <CyberButton onClick={() => SetScreen('welcome')}>
              Try Again
            </CyberButton>
          )}
        </footer>
      </div>
    </div>
  )
}

function OutputView() {
  const [JobState, SetJobState] = useState<JobState>({
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
  })

  useEffect(() => {
    window.api.getJobState().then((S) => SetJobState(S as JobState))
    window.api.onJobUpdate((S) => SetJobState(S as JobState))
    return () => window.api.removeListeners()
  }, [])

  return (
    <motion.div variants={cVar} initial="hidden" animate="show" exit="exit" className="flex flex-col gap-8 w-full max-w-5xl mx-auto h-[calc(100vh-8rem)]">
      <motion.div variants={iVar} className="border-l-4 border-primary pl-6 py-2 flex justify-between items-end">
        <div>
          <h2 className="text-4xl font-display font-bold uppercase tracking-tight text-white">Download Output</h2>
          <p className="text-muted-foreground mt-2 font-mono text-sm">REAL-TIME SNATCHER OUTPUT AND ERRORS.</p>
        </div>
        {JobState.sessionName ? (
          <span className="font-mono text-xs text-primary uppercase tracking-widest border-2 border-primary/20 bg-primary/5 px-3 py-1">
            {JobState.sessionName}
          </span>
        ) : null}
      </motion.div>

      <motion.div variants={iVar} className="flex-1 min-h-0 border-2 border-border bg-card flex flex-col overflow-hidden">
        <div className="flex-1 overflow-y-auto p-6 font-mono text-xs text-foreground select-text selection:bg-primary selection:text-primary-foreground space-y-2 scrollbar-thin">
          {JobState.outputs && JobState.outputs.length > 0 ? (
            JobState.outputs.map((O) => {
              let StatusColor = 'text-muted-foreground'
              if (O.status === 'Success') {
                StatusColor = 'text-primary'
              } else if (O.status.includes('[download]') || O.status.includes('[upload]')) {
                StatusColor = 'text-destructive'
              } else if (O.status === 'Downloading...' || O.status === 'Uploading...') {
                StatusColor = 'text-yellow-400 font-bold'
              }

              return (
                <div key={O.index} className="flex items-start py-1.5 border-b border-border/30 hover:bg-white/5 px-2 transition-colors">
                  <span className="text-muted-foreground/60 w-10 shrink-0">[{O.index}]</span>
                  <span className="font-bold text-white shrink-0 w-48">{O.oldId} : {O.newId}</span>
                  <span className="shrink-0 text-muted-foreground/45 px-2 font-bold font-sans">|</span>
                  <span className={`flex-1 break-all ${StatusColor}`}>{O.status}</span>
                </div>
              )
            })
          ) : (
            <div className="flex flex-col items-center justify-center py-20 text-muted-foreground gap-2">
              <Terminal size={24} className="opacity-40 animate-pulse text-primary" />
              <p className="uppercase tracking-widest text-[10px]">No active session output available.</p>
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  )
}

export default function App() {
  if (IsInstallerMode) {
    return <InstallerPage />
  }

  const [View, SetView] = useState('menu')
  const [Config, SetConfig] = useState<Config>({ cookie: '', apiKey: '', placeId: '', downloadPath: '' })
  const [ServerStatus, SetServerStatus] = useState<ServerStatus>({ listening: false })

  useEffect(() => {
    window.api.loadConfig().then(SetConfig)
    window.api.getServerPort().then((Port) => {
      SetServerStatus((S) => ({ ...S, port: Port }))
    })
    window.api.onServerStatus((S) => SetServerStatus(S as ServerStatus))
    return () => window.api.removeListeners()
  }, [])

  const HandleSaveConfig = useCallback((C: Config) => {
    SetConfig(C)
  }, [])

  return (
    <div className="h-screen w-full flex bg-background text-foreground overflow-hidden select-none relative">
      <div className="noise-overlay" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30 pointer-events-none" />

      <div
        className="absolute top-0 left-0 w-full h-8 z-50 flex justify-end px-2 gap-1 items-center"
        style={{ WebkitAppRegion: 'drag' } as React.CSSProperties}
      >
        <button
          onClick={() => window.api.minimize()}
          className="p-1.5 hover:bg-white/10 text-muted-foreground pointer-events-auto transition-colors"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          <Minus size={13} />
        </button>
        <button
          onClick={() => window.api.maximize()}
          className="p-1.5 hover:bg-white/10 text-muted-foreground pointer-events-auto transition-colors"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          <Square size={10} />
        </button>
        <button
          onClick={() => window.api.close()}
          className="p-1.5 hover:bg-destructive text-muted-foreground pointer-events-auto transition-colors"
          style={{ WebkitAppRegion: 'no-drag' } as React.CSSProperties}
        >
          <X size={13} />
        </button>
      </div>

      <aside className="w-[260px] border-r-2 border-border bg-background/90 backdrop-blur-md flex flex-col z-20 relative shrink-0">
        <div className="h-24 flex items-center px-6 border-b-2 border-border relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-1 bg-primary/20">
            <div className="h-full w-2/5 bg-primary animate-pulse" />
          </div>
          <div>
            <div className="flex items-center gap-2 text-primary mb-1">
              <Terminal size={12} />
              <span className="font-mono text-[9px] uppercase tracking-widest">sys.ready</span>
            </div>
            <h1 className="font-display font-black text-lg uppercase tracking-tighter text-white select-none">
              B-<span className="text-primary">Snatcher</span>
            </h1>
          </div>
        </div>

        <div className="flex-1 overflow-auto py-6">
          <nav className="flex flex-col gap-1">
            <SidebarItem icon={LayoutDashboard} label="Menu" active={View === 'menu'} onClick={() => SetView('menu')} />
            <SidebarItem icon={Terminal} label="Output" active={View === 'output'} onClick={() => SetView('output')} />
            <SidebarItem icon={Settings} label="Settings" active={View === 'settings'} onClick={() => SetView('settings')} />
            <SidebarItem icon={Star} label="Credits" active={View === 'credits'} onClick={() => SetView('credits')} />
          </nav>
        </div>

        <div className="p-5 border-t-2 border-border bg-black/40">
          <div className="text-[9px] font-mono uppercase tracking-widest text-muted-foreground flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span>Server</span>
              <span className={ServerStatus.listening ? 'text-primary font-bold' : 'text-muted-foreground'}>
                {ServerStatus.listening ? `LISTENING :${ServerStatus.port ?? 54321}` : 'OFFLINE'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span>Cookie</span>
              <span className={Config.cookie ? 'text-primary' : 'text-muted-foreground'}>
                {Config.cookie ? 'SET' : 'NOT SET'}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span>API Key</span>
              <span className={Config.apiKey ? 'text-primary' : 'text-muted-foreground'}>
                {Config.apiKey ? 'SET' : 'NOT SET'}
              </span>
            </div>
            <div className="w-full h-px bg-border mt-1" />
          </div>
        </div>
      </aside>

      <main className="flex-1 flex flex-col min-w-0 overflow-hidden z-10 relative pt-8">
        <div className="flex-1 overflow-auto p-8 lg:p-12 scrollbar-thin">
          <AnimatePresence mode="wait">
            {View === 'menu' && (
              <MenuView key="menu" config={Config} serverStatus={ServerStatus} />
            )}
            {View === 'output' && (
              <OutputView key="output" />
            )}
            {View === 'settings' && (
              <SettingsView key="settings" config={Config} onSave={HandleSaveConfig} />
            )}
            {View === 'credits' && (
              <CreditsView key="credits" />
            )}
          </AnimatePresence>
        </div>
      </main>
    </div>
  )
}
