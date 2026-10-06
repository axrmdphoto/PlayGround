#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p echo "capture: validating environment"
if [[ -z "${CAPTURE_URL:-}" ]]; then
  /usr/bin/time -p echo "CAPTURE_URL is required" >&2
  exit 1
fi
if [[ -z "${CAPTURE_DIR:-}" ]]; then
  /usr/bin/time -p echo "CAPTURE_DIR is required" >&2
  exit 1
fi
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p echo "capture url: $CAPTURE_URL"
/usr/bin/time -p echo "capture dir: $CAPTURE_DIR"
TMP_BASE="${RUNNER_TEMP:-/tmp}"
/usr/bin/time -p mkdir -p "$TMP_BASE"
CAPTURE_JS="$TMP_BASE/playground-capture-$$.mjs"
/usr/bin/time -p cat > "$CAPTURE_JS" <<'NODEJS'
import { readFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createRequire } from 'node:module';
const runtime = join(process.env.HOME || '/home/runner', '.local/share/omgithub-playwright');
const require = createRequire(join(runtime, 'package.json'));
const { chromium } = require('playwright');
const platformFile = process.platform === 'darwin' ? 'metal.json' : 'linux.json';
let launchOptions = {};
try {
  const config = JSON.parse(readFileSync(join(runtime, platformFile), 'utf8'));
  launchOptions = config.browser?.launchOptions || {};
} catch (error) {
  console.error('Failed to read playwright config: ' + error.message);
  process.exit(1);
}
if (process.platform === 'linux') {
  try {
    const display = readFileSync(join(runtime, 'display'), 'utf8').trim();
    process.env.DISPLAY ||= ':' + display;
  } catch {}
}
const url = process.env.CAPTURE_URL;
const output = process.env.CAPTURE_DIR;
if (!url || !output) {
  console.error('Set CAPTURE_URL and CAPTURE_DIR.');
  process.exit(1);
}
mkdirSync(output, { recursive: true });
const transient = (error) => {
  console.error('transient infrastructure failure: ' + (error?.message || error));
  process.exit(75);
};
let browser;
try {
  browser = await chromium.launch({ ...launchOptions, timeout: 30000 }).catch(transient);
  for (const [name, width, height] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
    let page;
    try {
      page = await browser.newPage({ viewport: { width, height } }).catch(transient);
      page.setDefaultTimeout(30000);
      page.on('pageerror', (error) => console.error('pageerror: ' + error.message));
      const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 }).catch(transient);
      const status = response?.status();
      if (!response || !response.ok()) {
        console.error('Bad HTTP response: ' + status + ' loading ' + url);
        if (!response || [408, 429, 500, 502, 503, 504].includes(status)) process.exit(75);
        process.exit(1);
      }
      try {
        await page.locator(process.env.CAPTURE_READY_SELECTOR || 'body').waitFor({ state: 'visible', timeout: 30000 });
      } catch (error) {
        console.error('Ready selector not visible: ' + error.message);
        process.exit(1);
      }
      try {
        await page.waitForFunction(() => document.fonts.status === 'loaded', { timeout: 15000 });
      } catch {}
      const textLength = await page.evaluate(() => document.body?.innerText?.length || 0).catch(() => 0);
      if (!textLength) {
        console.error('Rendered content is empty.');
        process.exit(1);
      }
      await page.waitForTimeout(1500);
      await page.screenshot({ path: join(output, `final-${name}.png`), timeout: 30000 }).catch((error) => {
        if (error.name === 'TimeoutError' || !browser.isConnected()) transient(error);
        console.error('Screenshot failed: ' + error.message);
        process.exit(1);
      });
      console.log(`Captured final-${name}.png (${width}x${height})`);
      await page.close();
    } catch (error) {
      if (error && (error.message || '').includes('transient infrastructure failure')) process.exit(75);
      console.error(error);
      process.exit(error?.exitCode || process.exitCode || 1);
    }
  }
} catch (error) {
  console.error(error);
  process.exit(error?.exitCode || 1);
} finally {
  try {
    await browser?.close();
  } catch (error) {
    console.error('Browser close failed: ' + error.message);
    process.exit(process.exitCode || 75);
  }
}
NODEJS
/usr/bin/time -p node "$CAPTURE_JS"
STATUS="$?"
/usr/bin/time -p rm -f "$CAPTURE_JS"
/usr/bin/time -p ls -la "$CAPTURE_DIR"
/usr/bin/time -p echo "capture exit: $STATUS"
exit "$STATUS"
