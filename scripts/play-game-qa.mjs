import { chromium } from "playwright";

const url = "http://127.0.0.1:8080/";
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e)));
page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });

await page.goto(url, { waitUntil: "networkidle" });
await page.waitForTimeout(1500);

// Start game via probe
await page.evaluate(() => {
  window.__controlsTest?.start();
});
await page.waitForTimeout(500);
await page.screenshot({ path: "/workspace/screenshots/playing.png" });

// Test A = left, D = right
const x0 = await page.evaluate(() => window.__controlsTest.getX());
await page.evaluate(() => window.__controlsTest.setKeys(["KeyA"]));
await page.waitForTimeout(400);
const xA = await page.evaluate(() => window.__controlsTest.getX());
await page.evaluate(() => window.__controlsTest.setKeys([]));
await page.waitForTimeout(100);
await page.evaluate(() => window.__controlsTest.setKeys(["KeyD"]));
await page.waitForTimeout(400);
const xD = await page.evaluate(() => window.__controlsTest.getX());
await page.evaluate(() => window.__controlsTest.setKeys([]));

// Punch
await page.evaluate(() => window.__controlsTest.setKeys(["KeyJ"]));
await page.waitForTimeout(50);
await page.evaluate(() => window.__controlsTest.setKeys([]));
await page.waitForTimeout(500);
await page.screenshot({ path: "/workspace/screenshots/combat.png" });

// Mobile viewport
await page.setViewportSize({ width: 390, height: 844 });
await page.waitForTimeout(300);
await page.screenshot({ path: "/workspace/screenshots/mobile.png" });

const phase = await page.evaluate(() => window.__controlsTest.getPhase());
const result = {
  errors,
  x0, xA, xD,
  aMovesLeft: xA < x0,
  dMovesRight: xD > xA,
  phase,
  body: await page.locator("body").innerText(),
};
console.log(JSON.stringify(result, null, 2));
await browser.close();
process.exit(result.aMovesLeft && result.dMovesRight && errors.length === 0 ? 0 : 1);
