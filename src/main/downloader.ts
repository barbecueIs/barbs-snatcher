import * as fs from 'fs'
import * as path from 'path'
import FormData from 'form-data'

const ALL_EXTS = ['ogg', 'mp3', 'm4a', 'flac', 'wav']
const MAX_RETRIES = 2
const RETRY_MS = 150

const Sleep = (Ms: number): Promise<void> => new Promise((R) => setTimeout(R, Ms))

function DetectExt(Buf: Buffer): string {
  if (!Buf || Buf.length < 12) return 'ogg'
  if (Buf[0] === 0x4f && Buf[1] === 0x67 && Buf[2] === 0x67 && Buf[3] === 0x53) return 'ogg'
  if (Buf[0] === 0x49 && Buf[1] === 0x44 && Buf[2] === 0x33) return 'mp3'
  if (Buf[0] === 0xff && (Buf[1] & 0xe0) === 0xe0) return 'mp3'
  if (Buf[4] === 0x66 && Buf[5] === 0x74 && Buf[6] === 0x79 && Buf[7] === 0x70) return 'm4a'
  if (Buf[0] === 0x66 && Buf[1] === 0x4c && Buf[2] === 0x61 && Buf[3] === 0x43) return 'flac'
  if (Buf[0] === 0x52 && Buf[1] === 0x49 && Buf[2] === 0x46 && Buf[3] === 0x46) return 'wav'
  return 'ogg'
}

function IsValidAudio(Buf: Buffer): boolean {
  if (!Buf || Buf.length < 12) return false
  if (Buf[0] === 0x4f && Buf[1] === 0x67 && Buf[2] === 0x67 && Buf[3] === 0x53) return true
  if (Buf[0] === 0x49 && Buf[1] === 0x44 && Buf[2] === 0x33) return true
  if (Buf[0] === 0xff && (Buf[1] & 0xe0) === 0xe0) return true
  if (Buf[4] === 0x66 && Buf[5] === 0x74 && Buf[6] === 0x79 && Buf[7] === 0x70) return true
  if (Buf[0] === 0x66 && Buf[1] === 0x4c && Buf[2] === 0x61 && Buf[3] === 0x43) return true
  if (Buf[0] === 0x52 && Buf[1] === 0x49 && Buf[2] === 0x46 && Buf[3] === 0x46) return true
  return false
}

export function SanitizeName(Raw: string): string {
  const Clean = Raw
    .replace(/[<>:"/\\|?*\x00-\x1f]/g, '')
    .replace(/\s+/g, '_')
    .replace(/_{2,}/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80)
  return Clean || 'sound'
}

async function FetchAssetName(Id: string, UserAgent: string): Promise<string> {
  try {
    const Res = await fetch(`https://api.roblox.com/marketplace/productinfo?assetId=${Id}`, {
      headers: { 'User-Agent': UserAgent },
      signal: AbortSignal.timeout(6000)
    })
    if (!Res.ok) return Id
    const Body = (await Res.json()) as { Name?: string }
    if (!Body.Name) return Id
    return `${SanitizeName(Body.Name)}_${Id}`
  } catch {
    return Id
  }
}

function FindExistingFile(Dir: string, Id: string): string | null {
  if (!fs.existsSync(Dir)) return null
  try {
    for (const File of fs.readdirSync(Dir)) {
      const Base = File.replace(/\.[^.]+$/, '')
      if (Base === Id || Base.endsWith(`_${Id}`)) return path.join(Dir, File)
    }
  } catch { /* ignore */ }
  return null
}

function SanitizeCookie(Raw: string): string {
  if (!Raw || !Raw.trim()) return ''
  const V = Raw.trim()
  return V.startsWith('.ROBLOSECURITY=') ? V.slice('.ROBLOSECURITY='.length) : V
}

function BuildCdnHeaders(
  Cookie: string,
  CsrfToken: string,
  PlaceId: string
): Record<string, string> {
  const H: Record<string, string> = { 'User-Agent': 'Roblox/WinInet', Accept: '*/*' }
  const C = SanitizeCookie(Cookie)
  if (C) H['Cookie'] = `.ROBLOSECURITY=${C}`
  if (PlaceId) H['Roblox-Place-Id'] = PlaceId
  if (CsrfToken) H['x-csrf-token'] = CsrfToken
  return H
}

export async function FetchCsrfToken(Cookie: string): Promise<string> {
  try {
    const C = SanitizeCookie(Cookie)
    const Res = await fetch('https://auth.roblox.com/v2/logout', {
      method: 'POST',
      headers: { Cookie: `.ROBLOSECURITY=${C}`, 'User-Agent': 'Roblox/WinInet' },
      signal: AbortSignal.timeout(8000)
    })
    return Res.headers.get('x-csrf-token') ?? ''
  } catch {
    return ''
  }
}

export async function FetchUserId(Cookie: string): Promise<number | null> {
  try {
    const C = SanitizeCookie(Cookie)
    const Res = await fetch('https://users.roblox.com/v1/users/authenticated', {
      headers: { Cookie: `.ROBLOSECURITY=${C}`, 'User-Agent': 'Roblox/WinInet' },
      signal: AbortSignal.timeout(8000)
    })
    if (!Res.ok) return null
    const Body = (await Res.json()) as { id?: number }
    return Body.id ?? null
  } catch {
    return null
  }
}

async function FetchBinary(
  Url: string,
  Headers: Record<string, string>
): Promise<Buffer | null> {
  try {
    const Res = await fetch(Url, { headers: Headers, signal: AbortSignal.timeout(20000) })
    if (!Res.ok) return null
    const Buf = Buffer.from(await Res.arrayBuffer())
    return IsValidAudio(Buf) ? Buf : null
  } catch {
    return null
  }
}

async function TryCdnWithPlaceId(
  Id: string,
  Headers: Record<string, string>
): Promise<Buffer | null> {
  const [V2Result, V1Result] = await Promise.allSettled([
    (async (): Promise<Buffer | null> => {
      try {
        const Meta = await fetch(
          `https://assetdelivery.roblox.com/v2/asset?id=${Id}`,
          { headers: Headers, signal: AbortSignal.timeout(10000) }
        )
        if (!Meta.ok) return null
        const MetaBody = (await Meta.json()) as { location?: string; locations?: { assetUrl?: string }[] }
        const CdnUrl = MetaBody.location ?? MetaBody.locations?.[0]?.assetUrl
        return CdnUrl ? FetchBinary(CdnUrl, Headers) : null
      } catch {
        return null
      }
    })(),
    FetchBinary(`https://assetdelivery.roblox.com/v1/asset/?id=${Id}`, Headers),
  ])
  const V2Buf = V2Result.status === 'fulfilled' ? V2Result.value : null
  const V1Buf = V1Result.status === 'fulfilled' ? V1Result.value : null
  return V2Buf ?? V1Buf
}

export async function DownloadSound(
  Id: string,
  Dir: string,
  Cookie: string,
  CsrfToken: string,
  ApiKey: string,
  PlaceIds: string[],
  FileName: string
): Promise<{ Ok: boolean; FilePath: string | null; Error: string | null }> {
  for (const Ext of ALL_EXTS) {
    const P = path.join(Dir, `${FileName}.${Ext}`)
    if (fs.existsSync(P)) return { Ok: true, FilePath: P, Error: null }
  }

  let AudioBuf: Buffer | null = null
  let LastErr = 'unknown'

  if (ApiKey) {
    try {
      const Res = await fetch(`https://apis.roblox.com/assets/v1/assets/${Id}/content`, {
        headers: { 'x-api-key': ApiKey, Accept: '*/*' },
        signal: AbortSignal.timeout(20000)
      })
      if (Res.ok) {
        const Buf = Buffer.from(await Res.arrayBuffer())
        if (IsValidAudio(Buf)) AudioBuf = Buf
        else LastErr = 'invalid audio data'
      } else {
        LastErr = `HTTP ${Res.status}`
      }
    } catch (E: unknown) {
      LastErr = E instanceof Error ? E.message : 'fetch error'
    }
  }

  if (!AudioBuf) {
    const PidsToTry = PlaceIds.length > 0 ? PlaceIds : ['']
    outer: for (const Pid of PidsToTry) {
      const H = BuildCdnHeaders(Cookie, CsrfToken, Pid)
      for (let Attempt = 1; Attempt <= MAX_RETRIES; Attempt++) {
        const CdnBuf = await TryCdnWithPlaceId(Id, H)
        if (CdnBuf) {
          AudioBuf = CdnBuf
          break outer
        }
        if (Attempt < MAX_RETRIES) await Sleep(RETRY_MS)
      }
    }
    if (!AudioBuf) LastErr = 'all CDN strategies failed'
  }

  if (AudioBuf) {
    const Ext = DetectExt(AudioBuf)
    const FilePath = path.join(Dir, `${FileName}.${Ext}`)
    fs.writeFileSync(FilePath, AudioBuf)
    return { Ok: true, FilePath, Error: null }
  }

  return { Ok: false, FilePath: null, Error: LastErr }
}

async function PollOperation(
  OpPath: string,
  ApiKey: string
): Promise<{ NewId: string | null; Error: string | null }> {
  await Sleep(400)
  for (let I = 0; I < 25; I++) {
    try {
      const Res = await fetch(`https://apis.roblox.com/assets/v1/${OpPath}`, {
        headers: { 'x-api-key': ApiKey },
        signal: AbortSignal.timeout(10000)
      })
      if (!Res.ok) {
        const ErrText = await Res.text().catch(() => '')
        return { NewId: null, Error: `Poll HTTP ${Res.status}: ${ErrText.slice(0, 120)}` }
      }
      const Body = (await Res.json()) as {
        done?: boolean
        response?: { assetId?: string | number }
        error?: { code?: number; message?: string }
      }
      if (Body.error) {
        return { NewId: null, Error: `Operation error ${Body.error.code}: ${Body.error.message}` }
      }
      if (Body.done) {
        const Id = Body.response?.assetId?.toString() ?? null
        return { NewId: Id, Error: Id ? null : 'operation completed but returned no assetId' }
      }
    } catch (E: unknown) {
      return { NewId: null, Error: E instanceof Error ? E.message : 'poll exception' }
    }
    await Sleep(400)
  }
  return { NewId: null, Error: 'operation timed out after 10s' }
}

const MIME_MAP: Record<string, string> = {
  ogg: 'audio/ogg',
  mp3: 'audio/mpeg',
  m4a: 'audio/mp4',
  flac: 'audio/flac',
  wav: 'audio/wav',
}

export async function UploadSound(
  FilePath: string,
  OldId: string,
  ApiKey: string,
  UserId: number
): Promise<{ Ok: boolean; NewId: string | null; Error: string | null }> {
  try {
    const FileData = fs.readFileSync(FilePath)
    const Ext = path.extname(FilePath).slice(1).toLowerCase()
    const MimeType = MIME_MAP[Ext] ?? 'audio/mpeg'

    const ReqJson = JSON.stringify({
      assetType: 'Audio',
      displayName: `sound_${OldId}`,
      description: '',
      creationContext: { creator: { userId: UserId } },
    })

    const Form = new FormData()
    Form.append('request', ReqJson, { contentType: 'application/json' })
    Form.append('fileContent', FileData, {
      filename: `sound_${OldId}.${Ext}`,
      contentType: MimeType,
    })

    const FormBuffer = Form.getBuffer()
    const Res = await fetch('https://apis.roblox.com/assets/v1/assets', {
      method: 'POST',
      headers: {
        'x-api-key': ApiKey,
        ...Form.getHeaders(),
        'Content-Length': FormBuffer.length.toString(),
      },
      body: FormBuffer,
      signal: AbortSignal.timeout(30000)
    })

    if (!Res.ok) {
      const ErrText = await Res.text().catch(() => '')
      return { Ok: false, NewId: null, Error: `HTTP ${Res.status}: ${ErrText.slice(0, 120)}` }
    }

    const Body = (await Res.json()) as { path?: string }
    const OpPath = Body.path
    if (!OpPath) return { Ok: false, NewId: null, Error: 'no operation path in response' }

    const PollResult = await PollOperation(OpPath, ApiKey)
    if (!PollResult.NewId) return { Ok: false, NewId: null, Error: PollResult.Error }

    return { Ok: true, NewId: PollResult.NewId, Error: null }
  } catch (Err: unknown) {
    return { Ok: false, NewId: null, Error: Err instanceof Error ? Err.message : 'unknown error' }
  }
}
