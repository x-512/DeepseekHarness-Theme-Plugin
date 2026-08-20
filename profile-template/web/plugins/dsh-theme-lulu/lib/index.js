import { existsSync } from 'node:fs'
import { mkdir, readFile, readdir, unlink, writeFile } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { randomUUID } from 'node:crypto'
import { execFile } from 'node:child_process'

const pluginDir = dirname(fileURLToPath(import.meta.url))
const dataRoot = resolve(process.env.DSH_HOME || join(process.cwd(), 'data'))
const root = join(dataRoot, 'custom-themes')
const statePath = join(dataRoot, 'theme-state.json')
const maxBytes = 200 * 1024 * 1024
const stateMaxBytes = 128 * 1024
const types = {
  'image/png': '.png',
  'image/jpeg': '.jpg',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'video/mp4': '.mp4',
  'video/webm': '.webm',
}
const colors = [
  ['#fff2a8', '#f3a51f'],
  ['#78110c', '#d9322d'],
  ['#eff7dc', '#70a84d'],
  ['#fff0f6', '#d9669a'],
  ['#fff1d9', '#df8c24'],
  ['#eaf7f5', '#389ca8'],
  ['#ffeded', '#d9474d'],
  ['#ebf7ff', '#3798ad'],
  ['#fff0da', '#e99120'],
  ['#f1eff5', '#8e7b9d'],
]
const limits = {
  opacity: [20, 100],
  blur: [0, 20],
  exposure: [40, 160],
  brightness: [40, 160],
  contrast: [40, 180],
  saturation: [0, 220],
  scale: [80, 140],
  speed: [20, 250],
  volume: [0, 100],
}

function pairingScript() {
  const candidates = [
    join(dataRoot, '..', 'mobile', 'tools', 'start-remote-installed.ps1'),
    'D:\\AI-Coding-Tools\\DeepSeekHarnessElectron\\mobile\\tools\\start-remote-installed.ps1',
    'D:\\AI-Coding-Tools\\work\\DeepSeekHarnessElectron\\mobile\\tools\\start-remote-installed.ps1',
  ]
  return candidates.find((candidate) => requireLikeExists(candidate)) || ''
}
function requireLikeExists(path) {
  return existsSync(path)
}
function startPairing() {
  const script = pairingScript()
  if (!script) return Promise.reject(new Error('pairing-script-not-found'))
  const node = process.env.DSH_NODE_PATH || process.execPath
  return new Promise((resolvePromise, reject) => {
    execFile('powershell.exe', ['-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, '-Node', node], { windowsHide: true }, (error) => {
      if (error) reject(error)
      else resolvePromise(true)
    })
  })
}

const json = (res, status, value) => {
  const body = Buffer.from(JSON.stringify(value))
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': String(body.length),
    'cache-control': 'no-store',
  })
  res.end(body)
}

const clean = (value) => decodeURIComponent(String(value || ''))
  .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '')
  .trim()
  .slice(0, 60) || '我的主题'

const safeColor = (value, fallback) => /^#[0-9a-f]{6}$/i.test(String(value || '')) ? String(value) : fallback

const svg = (index) => {
  const pair = colors[index]
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1440"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="${pair[0]}"/><stop offset="1" stop-color="${pair[1]}"/></linearGradient><filter id="b"><feGaussianBlur stdDeviation="45"/></filter></defs><rect width="100%" height="100%" fill="url(#g)"/><g fill="#fff" opacity=".32" filter="url(#b)"><circle cx="420" cy="360" r="280"/><circle cx="2050" cy="980" r="420"/><circle cx="1300" cy="620" r="220"/></g></svg>`)
}

async function list() {
  await mkdir(root, { recursive: true })
  const names = await readdir(root)
  const out = []
  for (const file of names.filter((name) => name.endsWith('.json'))) {
    try {
      const item = JSON.parse(await readFile(join(root, file), 'utf8'))
      if (item && item.id && item.file) {
        out.push({ ...item, url: '/lulu-custom-assets/' + item.file, localPath: join(root, item.file) })
      }
    } catch {}
  }
  return out.sort((a, b) => a.createdAt.localeCompare(b.createdAt))
}

function sanitizeState(input) {
  const id = String(input?.id || '').slice(0, 80)
  const motion = input?.motion !== false
  const params = {}
  const hiddenBuiltins = [...new Set(Array.isArray(input?.hiddenBuiltins)
    ? input.hiddenBuiltins.filter((value) => /^b\d+$/.test(value))
    : [])]
  if (!/^[a-zA-Z0-9_-]+$/.test(id)) throw new Error('invalid-theme-id')
  for (const [themeId, values] of Object.entries(input?.params || {})) {
    if (!/^[a-zA-Z0-9_-]{1,80}$/.test(themeId) || !values || typeof values !== 'object') continue
    const cleanParams = {}
    for (const [key, [min, max]] of Object.entries(limits)) {
      const value = Number(values[key])
      if (Number.isFinite(value)) cleanParams[key] = Math.max(min, Math.min(max, value))
    }
    params[themeId] = cleanParams
  }
  return { id, motion, params, hiddenBuiltins, updatedAt: new Date().toISOString() }
}

async function readState() {
  try {
    return JSON.parse(await readFile(statePath, 'utf8'))
  } catch {
    return null
  }
}

async function writeState(req) {
  const chunks = []
  let size = 0
  for await (const chunk of req) {
    size += chunk.length
    if (size > stateMaxBytes) throw new Error('state-too-large')
    chunks.push(chunk)
  }
  const next = sanitizeState(JSON.parse(Buffer.concat(chunks).toString('utf8')))
  await mkdir(dirname(statePath), { recursive: true })
  await writeFile(statePath, JSON.stringify(next, null, 2))
  return next
}

async function readRequestBody(req, limit) {
  const chunks = []
  let size = 0
  for await (const chunk of req) {
    size += chunk.length
    if (size > limit) throw new Error('too-large')
    chunks.push(chunk)
  }
  return { bytes: Buffer.concat(chunks), size }
}

export const name = 'dsh-theme-lulu'
export const inject = ['webServer']

export function apply(ctx) {
  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: '/lulu-start-phone-pairing',
    async handler(req, res) {
      if (req.method !== 'POST') { json(res, 405, { error: 'method' }); return }
      try {
        await startPairing()
        json(res, 202, { started: true, pairingUrl: 'http://127.0.0.1:3081/remote-pairing' })
      } catch (error) {
        json(res, 500, { error: error?.message || 'pairing-start-failed' })
      }
    },
  }), 'lulu phone pairing starter')

  ctx.effect(() => ctx.webServer.register({
    kind: 'prefix',
    path: '/lulu-assets',
    async handler(req, res) {
      const index = Number((req.url ?? '').split('?')[0].slice('/lulu-assets/'.length))
      if (!Number.isInteger(index) || !colors[index]) {
        res.writeHead(404)
        res.end()
        return
      }
      const bytes = svg(index)
      res.writeHead(200, {
        'content-type': 'image/svg+xml',
        'content-length': String(bytes.length),
        'cache-control': 'public,max-age=31536000,immutable',
      })
      res.end(req.method === 'HEAD' ? undefined : bytes)
    },
  }), 'lulu built-in assets')

  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: '/lulu-theme.js',
    async handler(req, res) {
      try {
        const bytes = await readFile(join(pluginDir, 'desktop-theme.js'))
        res.writeHead(200, {
          'content-type': 'application/javascript; charset=utf-8',
          'content-length': String(bytes.length),
          'cache-control': 'no-store',
        })
        res.end(req.method === 'HEAD' ? undefined : bytes)
      } catch {
        res.writeHead(500)
        res.end('theme script unavailable')
      }
    },
  }), 'lulu browser script')

  ctx.effect(() => ctx.webServer.tapIndex((html) => {
    if (html.includes('/lulu-theme.js')) return html
    return html.replace('</body>', '<script src="/lulu-theme.js"></script></body>')
  }), 'lulu script injection')

  ctx.effect(() => ctx.webServer.register({
    kind: 'prefix',
    path: '/lulu-custom-assets',
    async handler(req, res) {
      const file = clean((req.url ?? '').split('?')[0].slice('/lulu-custom-assets/'.length))
      if (!file || file.includes('..')) {
        res.writeHead(404)
        res.end()
        return
      }
      try {
        const bytes = await readFile(join(root, file))
        const type = file.endsWith('.png') ? 'image/png'
          : file.endsWith('.webp') ? 'image/webp'
          : file.endsWith('.gif') ? 'image/gif'
          : file.endsWith('.mp4') ? 'video/mp4'
          : file.endsWith('.webm') ? 'video/webm'
          : 'image/jpeg'
        const headers = {
          'content-type': type,
          'cache-control': 'public,max-age=31536000,immutable',
          'accept-ranges': 'bytes',
        }
        const match = /^bytes=(\d*)-(\d*)$/.exec(String(req.headers.range || ''))
        if (match && bytes.length) {
          const start = match[1] ? Number(match[1]) : Math.max(0, bytes.length - Number(match[2] || 0))
          const end = match[2] && match[1] ? Math.min(bytes.length - 1, Number(match[2])) : bytes.length - 1
          if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 0 || start > end || start >= bytes.length) {
            res.writeHead(416, { ...headers, 'content-range': `bytes */${bytes.length}` })
            res.end()
            return
          }
          const chunk = bytes.subarray(start, end + 1)
          res.writeHead(206, {
            ...headers,
            'content-range': `bytes ${start}-${end}/${bytes.length}`,
            'content-length': String(chunk.length),
          })
          res.end(req.method === 'HEAD' ? undefined : chunk)
          return
        }
        res.writeHead(200, { ...headers, 'content-length': String(bytes.length) })
        res.end(req.method === 'HEAD' ? undefined : bytes)
      } catch {
        res.writeHead(404)
        res.end()
      }
    },
  }), 'lulu custom assets')

  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: '/lulu-theme-state',
    async handler(req, res) {
      if (req.method === 'GET') {
        json(res, 200, await readState())
        return
      }
      if (req.method !== 'PUT') {
        json(res, 405, { error: 'method' })
        return
      }
      try {
        json(res, 200, await writeState(req))
      } catch (error) {
        json(res, error?.message === 'state-too-large' ? 413 : 400, { error: error?.message || 'invalid-state' })
      }
    },
  }), 'lulu shared theme state')

  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: '/lulu-custom-themes',
    async handler(req, res) {
      if (req.method === 'GET') {
        json(res, 200, await list())
        return
      }
      if (req.method === 'DELETE') {
        const id = clean(req.headers['x-lulu-theme-id'])
        try {
          const metaPath = join(root, id + '.json')
          const item = JSON.parse(await readFile(metaPath, 'utf8'))
          if (!item || item.id !== id || !item.file) throw new Error('not-found')
          await unlink(join(root, item.file))
          await unlink(metaPath)
          json(res, 200, { deleted: id })
        } catch {
          json(res, 404, { error: '主题不存在' })
        }
        return
      }
      if (req.method !== 'POST') {
        json(res, 405, { error: 'method' })
        return
      }
      const type = String(req.headers['content-type'] || '').split(';')[0]
      if (!types[type]) {
        json(res, 415, { error: '仅支持 PNG、JPEG、WebP、GIF、MP4 或 WebM' })
        return
      }
      const declared = Number(req.headers['content-length'] || 0)
      if (declared > maxBytes) {
        json(res, 413, { error: '主题文件不能超过 200 MiB' })
        return
      }
      try {
        const { bytes, size } = await readRequestBody(req, maxBytes)
        await mkdir(root, { recursive: true })
        const id = Date.now().toString(36) + '-' + randomUUID().slice(0, 8)
        const file = id + types[type]
        const metadata = {
          id,
          name: clean(req.headers['x-lulu-theme-name']),
          file,
          type,
          bytes: size,
          createdAt: new Date().toISOString(),
          accent: safeColor(req.headers['x-lulu-accent'], '#56aabd'),
          base: safeColor(req.headers['x-lulu-base'], '#eef9fb'),
          layer: safeColor(req.headers['x-lulu-layer'], '#ffffff'),
          text: safeColor(req.headers['x-lulu-text'], '#20343a'),
          effect: Math.floor(Math.random() * 10),
        }
        await writeFile(join(root, file), bytes, { flag: 'wx' })
        await writeFile(join(root, id + '.json'), JSON.stringify(metadata, null, 2), { flag: 'wx' })
        json(res, 201, { ...metadata, url: '/lulu-custom-assets/' + file, localPath: join(root, file) })
      } catch (error) {
        json(res, error?.message === 'too-large' ? 413 : 500, { error: error?.message || 'upload failed' })
      }
    },
  }), 'lulu permanent custom themes')
}
