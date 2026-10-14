import { createServer, request as proxyRequest } from 'node:http';
import { readFile } from 'node:fs/promises';
import { watch } from 'node:fs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const port = Number(process.env.PORT || 5173);
const backend = new URL(process.env.ORC_DASHBOARD_URL || 'http://127.0.0.1:47654');
if (backend.protocol !== 'http:' || backend.hostname !== '127.0.0.1') {
  throw new Error('The dashboard backend must use HTTP on 127.0.0.1.');
}
const clients = new Set();
const assets = new Map([
  ['/', ['index.html', 'text/html']],
  ['/assets/dashboard.js', ['assets/dashboard.js', 'application/javascript']],
  ['/assets/dashboard.css', ['assets/dashboard.css', 'text/css']],
  ['/assets/mark.svg', ['assets/mark.svg', 'image/svg+xml']],
]);
let dirty = false, building = false, timer;
async function build() {
  dirty = true;
  if (building) return;
  building = true;
  try {
    do {
      dirty = false;
      const code = await new Promise((resolve, reject) => {
        const child = spawn(process.execPath, ['build.mjs'], { cwd: root, stdio: 'inherit', windowsHide: true });
        child.once('error', reject);
        child.once('exit', resolve);
      });
      if (code !== 0) throw new Error('Dashboard build failed.');
    } while (dirty);
    for (const client of clients) client.write('data: reload\n\n');
  } catch (error) {
    console.error(error.message);
  } finally {
    building = false;
  }
}
await build();
const server = createServer(async (request, response) => {
  const origin = `http://${request.headers.host}`;
  if (![`http://127.0.0.1:${port}`, `http://localhost:${port}`].includes(origin)) {
    response.writeHead(403).end(); return;
  }
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'self'; script-src 'self'; connect-src 'self'; img-src 'self' data:");
  const target = new URL(request.url, origin);
  const pathname = target.pathname;
  if (pathname.startsWith('/api/')) {
    if (request.method !== 'GET' && !(request.method === 'POST' && request.headers.origin === origin)) {
      response.writeHead(403).end(); return;
    }
    const proxy = proxyRequest(new URL(target.pathname + target.search, backend), {
      method: request.method,
      headers: { ...request.headers, host: backend.host, origin: backend.origin },
      timeout: 10000,
    }, upstream => {
      response.writeHead(upstream.statusCode, upstream.headers);
      upstream.pipe(response);
    });
    proxy.on('timeout', () => proxy.destroy(new Error('Dashboard backend timeout.')));
    proxy.on('error', () => {
      if (!response.headersSent) response.writeHead(502, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ error: 'Start the Windows server to preview live dashboard data.' }));
    });
    request.pipe(proxy);
    return;
  }
  if (request.method !== 'GET') { response.writeHead(405).end(); return; }
  if (pathname === '/__dev/events') {
    response.writeHead(200, { 'Content-Type': 'text/event-stream', Connection: 'keep-alive' });
    response.write(': connected\n\n');
    clients.add(response);
    response.on('close', () => clients.delete(response));
    return;
  }
  if (pathname === '/__dev/client.js') {
    response.writeHead(200, { 'Content-Type': 'application/javascript' });
    response.end("new EventSource('/__dev/events').onmessage=()=>location.reload();");
    return;
  }
  const asset = assets.get(pathname);
  if (!asset) { response.writeHead(404).end(); return; }
  try {
    let content = await readFile(new URL(`dist/${asset[0]}`, import.meta.url));
    if (pathname === '/') content = content.toString().replace('</body>', '<script src="/__dev/client.js" defer></script></body>');
    response.writeHead(200, { 'Content-Type': `${asset[1]}; charset=utf-8` });
    response.end(content);
  } catch { response.writeHead(500).end('Unable to read dashboard assets.'); }
});
const watcher = watch(new URL('src/', import.meta.url), () => {
  clearTimeout(timer);
  timer = setTimeout(() => void build(), 100);
});
server.on('error', error => { console.error(error.message); watcher.close(); process.exitCode = 1; });
server.listen(port, '127.0.0.1', () => console.log(`Dashboard preview: http://127.0.0.1:${port}/ (live backend: ${backend.origin})`));
