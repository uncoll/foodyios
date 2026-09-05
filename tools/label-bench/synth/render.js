// Renders every *.html in a directory to PNG with headless Chromium (Playwright).
// Usage: node render.js <html_dir> <out_dir> [deviceScaleFactor]
const fs = require('fs');
const path = require('path');
const { chromium } = require('/opt/node22/lib/node_modules/playwright');

(async () => {
  const [htmlDir, outDir, dsfArg] = process.argv.slice(2);
  const dsf = Number(dsfArg || 2);
  fs.mkdirSync(outDir, { recursive: true });
  const exe = process.env.CHROMIUM_PATH || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
  const browser = await chromium.launch({ executablePath: fs.existsSync(exe) ? exe : undefined, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 900, height: 600 }, deviceScaleFactor: dsf });
  for (const f of fs.readdirSync(htmlDir).filter(n => n.endsWith('.html')).sort()) {
    await page.goto('file://' + path.resolve(htmlDir, f));
    await page.waitForTimeout(50);
    const el = await page.$('#label');
    const out = path.join(outDir, f.replace(/\.html$/, '.png'));
    await el.screenshot({ path: out });
    console.log('rendered', out);
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
