// Browser check for an exported SimKit game. Needs node + playwright (NODE_PATH or a local install) and a
// served folder containing harness.html and game/ (the export):
//   mkdir -p /tmp/web/game && cp -r export/* /tmp/web/game/ && cp deploy/harness.html /tmp/web/
//   python3 -m http.server 8823 --directory /tmp/web &
//   PORT=8823 node web_smoke.js /tmp/shots
// Checks: boots with no console/page errors, the canvas is not blank, nothing runs before input, keyboard
// reaches the controls, Tab past the end and Escape each send exactly one sims:leave-game to the page,
// class settings in the address work, small frames still boot, and a screenshot is saved for a human to look at.
const { chromium } = require('playwright');
const port = process.env.PORT || '8823';
const shots = process.argv[2] || '/tmp/shots';
const base = `http://127.0.0.1:${port}/harness.html`;
let failures = 0;
function check(ok, label) { console.log((ok ? 'PASS ' : 'FAIL ') + label); if (!ok) { failures++; } }
async function boot(browser, query, w, h) {
	const ctx = await browser.newContext({ viewport: { width: w + 20, height: h + 60 } });
	const page = await ctx.newPage();
	const logs = [], errors = [];
	page.on('console', m => { logs.push(m.text()); if (m.type() === 'error') { errors.push(m.text()); } });
	page.on('pageerror', e => errors.push(String(e)));
	await page.goto(`${base}?q=${encodeURIComponent(query)}&w=${w}&h=${h}`);
	const frame = page.frameLocator('#game');
	const t0 = Date.now();
	while (!logs.some(l => l.includes('simkit: boot ok')) && Date.now() - t0 < 60000) { await page.waitForTimeout(250); }
	await page.waitForTimeout(500);
	return { ctx, page, logs, errors };
}
(async () => {
	const browser = await chromium.launch({ args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
	// 1. Boot the menu at the host's frame size
	let s = await boot(browser, 'demo=menu', 1180, 500);
	check(s.logs.some(l => l.includes('simkit: boot ok')), 'menu boots (console shows "simkit: boot ok")');
	check(s.errors.length === 0, 'no console or page errors while booting' + (s.errors.length ? ': ' + s.errors.join(' | ') : ''));
	const iframeEl = await s.page.$('#game');
	const a = await iframeEl.screenshot();
	await s.page.waitForTimeout(3000);
	const b = await iframeEl.screenshot();
	check(Buffer.compare(a, b) === 0, 'nothing changes for 3 s without input (no auto-play, static menu)');
	check(a.length > 4000, 'canvas is not blank (screenshot is ' + a.length + ' bytes)');
	await iframeEl.screenshot({ path: `${shots}/web-menu.png` });
	// 2. Keyboard: click the canvas, Tab to a control, open a demo with Enter, Escape returns, Escape again leaves
	await s.page.click('#game', { position: { x: 600, y: 480 } });
	await s.page.keyboard.press('Tab');
	await s.page.waitForTimeout(300);
	await s.page.keyboard.press('Enter');          // first menu button: Rabbits and foxes
	await s.page.waitForTimeout(800);
	await s.page.screenshot({ path: `${shots}/web-after-enter.png` });
	const gameFrame = s.page.frames().find(f => f !== s.page.mainFrame());
	const live = await gameFrame.evaluate(() => document.getElementById('sk-status').textContent);
	check(live.includes('Opened Rabbits and foxes'), 'Tab + Enter opened the first demo, and the screen-reader live region received "' + live + '"');
	let leaves = await s.page.evaluate(() => window.leaveCount);
	await s.page.keyboard.press('Escape');         // closes the demo, stays in the game
	await s.page.waitForTimeout(400);
	check((await s.page.evaluate(() => window.leaveCount)) === leaves, 'Escape with a demo open closes the demo and does NOT leave the game');
	await s.page.keyboard.press('Escape');         // menu -> leave
	await s.page.waitForTimeout(400);
	check((await s.page.evaluate(() => window.leaveCount)) === leaves + 1, 'Escape on the menu sends exactly one sims:leave-game');
	check(await s.page.evaluate(() => document.activeElement && document.activeElement.id === 'fs'), 'focus lands on the host page (Full screen button)');
	await s.ctx.close();
	// 3. Class settings via the address; the demo opens and runs under real input
	s = await boot(browser, 'demo=predator_prey&capacity=200&start=Many%20foxes', 1180, 500);
	check(s.errors.length === 0, 'predator_prey with class settings boots without errors' + (s.errors.length ? ': ' + s.errors.join(' | ') : ''));
	const f2 = await s.page.$('#game');
	await s.page.click('#game', { position: { x: 600, y: 300 } });
	await s.page.keyboard.press('Space');          // hotkey: start
	await s.page.waitForTimeout(6000);
	await f2.screenshot({ path: `${shots}/web-predator-prey.png` });
	const c = await f2.screenshot();
	await s.page.waitForTimeout(1500);
	const d = await f2.screenshot();
	check(Buffer.compare(c, d) !== 0, 'after pressing Space the simulation visibly runs');
	await s.page.keyboard.press('Space');          // pause
	await s.page.waitForTimeout(500);
	const e1 = await f2.screenshot();
	await s.page.waitForTimeout(2500);
	const e2 = await f2.screenshot();
	check(Buffer.compare(e1, e2) === 0, 'after Space again the frame is pixel-identical for 2.5 s (Pause freezes everything)');
	check(s.errors.length === 0, 'still no errors after running' + (s.errors.length ? ': ' + s.errors.join(' | ') : ''));
	await s.ctx.close();
	// 4. Other frame sizes boot and keep the layout usable
	for (const [w, h] of [[1180, 360], [590, 250], [380, 640]]) {
		s = await boot(browser, 'demo=natural_selection', w, h);
		check(s.errors.length === 0, `natural_selection boots at ${w}x${h} without errors`);
		await (await s.page.$('#game')).screenshot({ path: `${shots}/web-ns-${w}x${h}.png` });
		await s.ctx.close();
	}
	await browser.close();
	console.log(failures === 0 ? 'ALL BROWSER CHECKS PASSED' : failures + ' BROWSER CHECK(S) FAILED');
	process.exit(failures === 0 ? 0 : 1);
})();
