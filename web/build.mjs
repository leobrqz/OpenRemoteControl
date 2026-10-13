import { cpSync, mkdirSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const dist = resolve(root, 'dist');
mkdirSync(resolve(dist, 'assets'), { recursive: true });
const cliRoot = resolve(root, 'node_modules/@tailwindcss/cli');
const cliPackage = JSON.parse(readFileSync(resolve(cliRoot, 'package.json'), 'utf8'));
const result = spawnSync(process.execPath, [resolve(cliRoot, cliPackage.bin.tailwindcss), '-i', 'src/dashboard.input.css', '-o', 'dist/assets/dashboard.css', '--minify'], { cwd: root, stdio: 'inherit' });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
cpSync(resolve(root, 'src/index.html'), resolve(dist, 'index.html'));
cpSync(resolve(root, 'src/dashboard.js'), resolve(dist, 'assets/dashboard.js'));
cpSync(resolve(root, 'server/assets/branding/mark.svg'), resolve(dist, 'assets/mark.svg'));
for (const name of ['LICENSE.tailwindcss', 'LICENSE.daisyui', 'LICENSE.tailwindcss-cli']) {
  cpSync(resolve(root, 'src', name), resolve(dist, name));
}
