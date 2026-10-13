import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const files = new Map([
  ['/', ['index.html', 'text/html']],
  ['/index.html', ['index.html', 'text/html']],
  ['/assets/style.css', ['assets/style.css', 'text/css']],
  ['/assets/mark.svg', ['assets/mark.svg', 'image/svg+xml']],
]);
const server = createServer(async (request, response) => {
  if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405); response.end(); return; }
  const file = files.get(new URL(request.url, 'http://127.0.0.1').pathname);
  if (!file) { response.writeHead(404); response.end('Not found'); return; }
  try {
    const content = await readFile(fileURLToPath(new URL(file[0], import.meta.url)));
    response.writeHead(200, { 'Content-Type': `${file[1]}; charset=utf-8`, 'Cache-Control': 'no-store' });
    response.end(request.method === 'HEAD' ? undefined : content);
  } catch { response.writeHead(500); response.end('Unable to read site file'); }
});
server.on('error', error => { console.error(error.message); process.exitCode = 1; });
server.listen(4173, '127.0.0.1', () => console.log('Open Remote Control site: http://127.0.0.1:4173/'));
