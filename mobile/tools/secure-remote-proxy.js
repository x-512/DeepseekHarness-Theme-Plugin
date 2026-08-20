const http = require('http')
const net = require('net')
const fs = require('fs')
const path = require('path')
const crypto = require('crypto')
const { execFileSync } = require('child_process')
const QRCode = require('./npm/node_modules/qrcode-terminal/vendor/QRCode')
const QRErrorCorrectLevel = require('./npm/node_modules/qrcode-terminal/vendor/QRCode/QRErrorCorrectLevel')

const root = path.resolve(__dirname, '..')
const dataDir = process.env.DSH_REMOTE_DATA_DIR || path.join(root, 'data')
const authPath = path.join(dataDir, 'remote-auth.json')
const publicPath = path.join(dataDir, 'remote-url.txt')
const apkPath = path.join(root, 'Android', 'DeepSeek-Harness-Android.apk')
const listenHost = process.env.REMOTE_PROXY_HOST || '127.0.0.1'
const listenPort = Number(process.env.REMOTE_PROXY_PORT || 3081)
const targetHost = '127.0.0.1'
const targetPort = 3080
fs.mkdirSync(dataDir, { recursive: true })

const randomToken = bytes => crypto.randomBytes(bytes).toString('base64url')
const digest = value => crypto.createHash('sha256').update(value).digest('hex')
let state
try { state = JSON.parse(fs.readFileSync(authPath, 'utf8')) } catch { state = {} }
if (!state.pairHash) {
  state.pairCode = randomToken(18)
  state.pairHash = digest(state.pairCode)
  state.devices = []
  save()
}

function save() {
  fs.writeFileSync(authPath, JSON.stringify(state, null, 2), { mode: 0o600 })
  if (process.platform === 'win32') {
    try {
      const user = process.env.USERNAME
      execFileSync('icacls.exe', [authPath, '/inheritance:r', '/grant:r', `${user}:F`, '/grant:r', 'SYSTEM:F'], { windowsHide: true, stdio: 'ignore' })
    } catch {}
  }
}
function cookies(request) {
  return Object.fromEntries(String(request.headers.cookie || '').split(';').map(item => item.trim().split('=').map(decodeURIComponent)).filter(item => item.length === 2))
}
function authorized(request) {
  const token = cookies(request).dsh_remote_device
  return Boolean(token && state.devices.some(device => crypto.timingSafeEqual(Buffer.from(device.hash), Buffer.from(digest(token)))))
}
function html(response, status, body) {
  response.writeHead(status, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'x-frame-options': 'DENY', 'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; img-src data:" })
  response.end(`<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>DeepSeek Harness 远程配对</title><style>body{font:16px system-ui;margin:0;min-height:100vh;display:grid;place-items:center;background:#eef9fb;color:#20343a}.card{max-width:560px;margin:24px;padding:28px;border:2px solid #56aabd;border-radius:22px;background:#ffffffdd;box-shadow:0 20px 60px #20343a22}code{word-break:break-all}svg{width:min(78vw,360px);height:auto;display:block;margin:20px auto}button{padding:12px 18px;border:0;border-radius:12px;background:#56aabd;color:white;font-weight:700}</style><div class="card">${body}</div>`)
}
function qrSvg(text) {
  const qr = new QRCode(-1, QRErrorCorrectLevel.M)
  qr.addData(text)
  qr.make()
  const count = qr.getModuleCount(), cell = 6, margin = 4, size = (count + margin * 2) * cell
  let paths = ''
  for (let row = 0; row < count; row++) for (let column = 0; column < count; column++) if (qr.isDark(row, column)) paths += `M${(column + margin) * cell} ${(row + margin) * cell}h${cell}v${cell}h-${cell}z`
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" aria-label="配对二维码"><rect width="100%" height="100%" fill="white"/><path d="${paths}" fill="#111"/></svg>`
}
function remoteBase(request) {
  const forwarded = String(request.headers['x-forwarded-host'] || request.headers.host || '')
  const protocol = request.headers['x-forwarded-proto'] || (forwarded.includes('trycloudflare.com') ? 'https' : 'http')
  return `${protocol}://${forwarded}`
}
function proxyHttp(request, response) {
  const headers = { ...request.headers, host: `${targetHost}:${targetPort}` }
  delete headers['x-forwarded-host']
  const upstream = http.request({ host: targetHost, port: targetPort, method: request.method, path: request.url, headers }, proxyResponse => {
    response.writeHead(proxyResponse.statusCode || 502, proxyResponse.headers)
    proxyResponse.pipe(response)
  })
  upstream.on('error', error => html(response, 502, `<h1>电脑端 Harness 未启动</h1><p>${error.message}</p>`))
  request.pipe(upstream)
}
const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`)
  if (url.pathname === '/install') {
    const code = url.searchParams.get('code') || ''
    if (code.length !== state.pairCode.length || !crypto.timingSafeEqual(Buffer.from(digest(code)), Buffer.from(state.pairHash))) return html(response, 403, '<h1>安装链接无效或已过期</h1><p>请在电脑端重新打开配对二维码。</p>')
    const base = remoteBase(request)
    const encoded = encodeURIComponent(code)
    const pairUrl = `${base}/pair?code=${encoded}`
    const appLink = `deepseek-harness://pair?url=${encodeURIComponent(pairUrl)}`
    return html(response, 200, `<h1>DeepSeek Harness 手机端</h1><p>第一步：直接下载安装包。</p><p><a href="${base}/download-apk?code=${encoded}"><button>下载 Android APK 1.2.1</button></a></p><p>安装后回到此页面，点击：</p><p><a href="${appLink}"><button>打开 App 并自动配对</button></a></p><p><a href="${pairUrl}">无法唤起时使用 HTTPS 备用配对</a></p><p>Android 可能提示允许浏览器“安装未知应用”。无需 ZIP，也无需文件管理器解压。</p>`)
  }
  if (url.pathname === '/download-apk') {
    const code = url.searchParams.get('code') || ''
    if (code.length !== state.pairCode.length || !crypto.timingSafeEqual(Buffer.from(digest(code)), Buffer.from(state.pairHash)) || !fs.existsSync(apkPath)) return html(response, 404, '<h1>APK 不存在或下载链接已过期</h1>')
    const stat = fs.statSync(apkPath)
    response.writeHead(200, { 'content-type': 'application/vnd.android.package-archive', 'content-disposition': 'attachment; filename="DeepSeek-Harness-Android.apk"', 'content-length': String(stat.size), 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' })
    fs.createReadStream(apkPath).pipe(response)
    return
  }
  if (url.pathname === '/pair') {
    const code = url.searchParams.get('code') || ''
    if (code.length !== state.pairCode.length || !crypto.timingSafeEqual(Buffer.from(digest(code)), Buffer.from(state.pairHash))) return html(response, 403, '<h1>配对密钥无效或已使用</h1><p>请回到电脑端重新生成二维码。</p>')
    const token = randomToken(32)
    state.devices.push({ hash: digest(token), pairedAt: new Date().toISOString() })
    state.pairCode = randomToken(18)
    state.pairHash = digest(state.pairCode)
    save()
    response.writeHead(302, { location: '/', 'set-cookie': `dsh_remote_device=${encodeURIComponent(token)}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000`, 'cache-control': 'no-store' })
    response.end()
    return
  }
  if (url.pathname === '/remote-pairing' && request.socket.remoteAddress === '127.0.0.1') {
    const base = fs.existsSync(publicPath) ? fs.readFileSync(publicPath, 'utf8').trim() : remoteBase(request)
    const link = `${base}/install?code=${encodeURIComponent(state.pairCode)}`
    return html(response, 200, `<h1>手机安装与远程配对</h1>${qrSvg(link)}<p>手机扫码后可直接下载 APK，再点按钮打开 App 完成配对。</p><p>也可复制：</p><p><code>${link}</code></p><p>一次性密钥：<code>${state.pairCode}</code></p><p>配对后手机与电脑访问同一 Harness，电脑上的会话和配置实时一致。</p>`)
  }
  if (!authorized(request)) return html(response, 401, '<h1>此设备尚未配对</h1><p>请在电脑端打开配对二维码并使用手机扫描。</p>')
  proxyHttp(request, response)
})
server.on('upgrade', (request, socket, head) => {
  if (!authorized(request)) return socket.destroy()
  const upstream = net.connect(targetPort, targetHost, () => {
    let raw = `${request.method} ${request.url} HTTP/${request.httpVersion}\r\n`
    for (let index = 0; index < request.rawHeaders.length; index += 2) {
      const name = request.rawHeaders[index]
      const value = name.toLowerCase() === 'host' ? `${targetHost}:${targetPort}` : request.rawHeaders[index + 1]
      raw += `${name}: ${value}\r\n`
    }
    upstream.write(`${raw}\r\n`)
    if (head.length) upstream.write(head)
    socket.pipe(upstream).pipe(socket)
  })
  upstream.on('error', () => socket.destroy())
})
server.listen(listenPort, listenHost, () => console.log(`Secure remote proxy: http://${listenHost}:${listenPort}`))
