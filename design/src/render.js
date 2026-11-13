// Рендерит SVG из design/ в PNG через Chromium (Playwright).
// Запуск: node design/src/render.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const dir = path.resolve(__dirname, '..');

(async () => {
  const browser = await chromium.launch();
  for (const name of ['bit-states', 'screens']) {
    const svg = fs.readFileSync(path.join(dir, `${name}.svg`), 'utf8');
    const w = +svg.match(/width="(\d+(?:\.\d+)?)"/)[1];
    const h = +svg.match(/height="(\d+(?:\.\d+)?)"/)[1];
    const page = await browser.newPage({ viewport: { width: Math.ceil(w), height: Math.ceil(h) }, deviceScaleFactor: 2 });
    await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(dir, `${name}.png`), clip: { x: 0, y: 0, width: w, height: h } });
    await page.close();
  }
  await browser.close();
})();
