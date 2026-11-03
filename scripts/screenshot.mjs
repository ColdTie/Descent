// Optional: builds the site, serves dist/ locally and saves shots/latest.png.
// Skips cleanly when Playwright is not installed in the environment.
import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { build, preview } from 'vite';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  console.log('[screenshot] playwright is not available here; skipping (this script is optional).');
  process.exit(0);
}

await build({ configFile: './vite.config.ts', logLevel: 'warn' });
const server = await preview({ configFile: './vite.config.ts', logLevel: 'silent', preview: { open: false } });
const url = server.resolvedUrls?.local[0] ?? 'http://localhost:4173/';

let browser;
try {
  browser = await chromium.launch({
    args: ['--no-proxy-server', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('pageerror', (err) => errors.push(err.message));
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(2500);
  mkdirSync('shots', { recursive: true });
  await page.screenshot({ path: 'shots/latest.png' });
  const hud = (await page.textContent('#ui'))?.replace(/\s+/g, ' ').trim();
  console.log(`[screenshot] saved shots/latest.png from ${url}`);
  console.log(`[screenshot] hud text: ${hud}`);
  if (errors.length) {
    console.error('[screenshot] page errors:\n  ' + errors.join('\n  '));
    process.exitCode = 1;
  }
} finally {
  await browser?.close();
  await server.close();
}
