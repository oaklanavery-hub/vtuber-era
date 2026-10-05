/* Optional browser QA. The game itself has no JavaScript framework dependency. */
const fs = require('fs');
const http = require('http');
const path = require('path');
const assert = require('assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const scenario = process.env.QA_REALM || 'fire';
const rival = process.env.QA_RIVAL || (scenario === 'water' ? 'earth' : scenario === 'earth' ? 'water' : 'fire');
const leaderRealm = scenario === 'mixed' ? 'water' : scenario;
const realms = ['fire', 'water', 'earth'];
const cards = ['fire_archer', 'fire_melee', 'fire_tank', 'fire_assassin',
  'water_mage', 'water_tank', 'water_melee', 'water_ranged',
  'earth_tank', 'earth_melee', 'earth_ranged', 'earth_siege'];
const chosenCards = scenario === 'mixed' ? ['fire_archer', 'water_melee', 'water_mage', 'earth_siege']
  : cards.slice(realms.indexOf(scenario) * 4, realms.indexOf(scenario) * 4 + 4);
const root = path.resolve(__dirname, '../build/web');
const output = path.resolve(__dirname, `../test-results/browser/${scenario}`);
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, '../.gdignore'), '');

const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  if (!pathname.startsWith('/vtuber-era/')) { res.writeHead(404); res.end(); return; }
  const file = path.resolve(root, pathname.slice('/vtuber-era/'.length) || 'index.html');
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    res.writeHead(404); res.end(); return;
  }
  res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript',
    '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png',
    '.txt': 'text/plain' })[path.extname(file)] || 'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});

let browser;
let activePage;
const errors = [];
const actions = [];
const rounds = [];
const visited = new Set();
const stats = { reinforcements: 0, promotions: 0, spell: 0, comeback: 0 };

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = process.env.QA_URL || `http://127.0.0.1:${server.address().port}/vtuber-era/?qa=1`;
  const custom = process.env.CHROMIUM_EXECUTABLE;
  browser = await chromium.launch({ headless: true, ...(custom ? { executablePath: custom } : {}),
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
      ...(process.env.QA_SINGLE_PROCESS ? ['--single-process', '--no-zygote', '--in-process-gpu'] : [])] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  activePage = page;
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('response', response => { if (response.status() >= 400) errors.push(`HTTP ${response.status()} ${new URL(response.url()).pathname}`); });
  const snapshot = () => page.evaluate(() => window.vtuberEraQA);
  const waitScreen = async screen => {
    await page.waitForFunction(screen => window.vtuberEraQA?.screen === screen, screen, { timeout: 60000 });
    visited.add(screen);
  };
  const click = async (x, y) => { await page.mouse.click(x * 2, y * 2); await page.waitForTimeout(100); };
  const screenshot = name => page.screenshot({ path: path.join(output, `${name}.png`) });
  await page.goto(url);
  await waitScreen('menu');
  assert.equal(await page.evaluate(() => window.crossOriginIsolated), false);
  await screenshot('menu');
  console.log('PASS: WebAssembly/WebGL game loads at /vtuber-era/ without isolation headers.');

  await click(320, 232);
  await waitScreen('compendium');
  for (let i = 0; i < realms.length; i++) {
    await click(211 + i * 106, 93);
    await page.waitForFunction(realm => window.vtuberEraQA?.compendium_realm === realm, realms[i]);
    await screenshot(`compendium-${realms[i]}`);
  }
  await click(320, 333);
  await waitScreen('menu');
  await click(320, 270);
  await waitScreen('settings');
  await click(383, 195);
  await screenshot('speed-options');
  await click(383, 257);
  await page.waitForFunction(() => window.vtuberEraQA?.settings.combat_speed === 3);
  await click(341, 234);
  await page.waitForFunction(() => window.vtuberEraQA?.settings.reduced_effects === true);
  await screenshot('settings');
  await click(320, 337);
  await page.waitForTimeout(2000);
  await page.reload();
  await waitScreen('menu');
  let saved = await snapshot();
  assert.equal(saved.settings.combat_speed, 3);
  assert.equal(saved.settings.reduced_effects, true);
  console.log('PASS: speed and reduced-effects settings survive a browser reload.');
  await click(320, 270);
  await waitScreen('settings');
  await click(341, 234);
  await page.waitForFunction(() => window.vtuberEraQA?.settings.reduced_effects === false);
  await click(320, 337);
  await waitScreen('menu');
  await click(320, 190);
  await waitScreen('commander');
  for (let i = 0; i < realms.length; i++) {
    await click(114 + i * 206, 204);
    await page.waitForFunction(id => window.vtuberEraQA?.selected_commander === id, `${realms[i]}_commander`);
  }
  await click(114 + realms.indexOf(leaderRealm) * 206, 204);
  await page.waitForFunction(id => window.vtuberEraQA?.selected_commander === id, `${leaderRealm}_commander`);
  await screenshot('commander');
  await click(432, 328);
  await waitScreen('warband');
  await click(358, 135);
  await page.waitForFunction(() => window.vtuberEraQA?.selected_warband.length === 0);
  await click(530, 341);
  assert.equal((await snapshot()).screen, 'warband', 'an incomplete loadout cannot start');
  const pickCard = async id => {
    const index = cards.indexOf(id);
    await click(88 + (index % 4) * 152, 175 + Math.floor(index / 4) * 44);
  };
  for (const id of chosenCards) await pickCard(id);
  await page.waitForFunction(() => window.vtuberEraQA?.selected_warband.length === 4);
  await pickCard(cards.find(id => !chosenCards.includes(id)));
  assert.deepEqual((await snapshot()).selected_warband, chosenCards, 'a fifth card is blocked');
  await pickCard(chosenCards[3]);
  await page.waitForFunction(() => window.vtuberEraQA?.selected_warband.length === 3);
  await pickCard(chosenCards[3]);
  await click(535, 54);
  await screenshot('rival-options');
  await click(523, 75 + 23 * (realms.indexOf(rival) + 1));
  await page.waitForFunction(realm => window.vtuberEraQA?.rival === realm, rival);
  await screenshot('warband');
  await click(509, 336);
  await waitScreen('battle');
  const initial = await snapshot();
  assert.equal(initial.commander, `${leaderRealm}_commander`);
  assert.equal(initial.commanders[1], `${rival}_commander`);
  assert.deepEqual(initial.warbands[0], chosenCards);
  assert.equal(initial.bond, scenario === 'mixed' ? '' : ({ fire: 'wildfire', water: 'tidal_recovery', earth: 'earthen_guard' })[scenario]);
  console.log(`PASS: ${scenario} warband and ${leaderRealm} commander enter a real match against ${rival}.`);
  const initialOffers = JSON.stringify(initial.offers);
  await click(540, 280);
  let now = await snapshot();
  assert.equal(now.points, 2);
  assert.equal(now.spell, true);
  assert.equal(JSON.stringify(now.offers), initialOffers);
  stats.spell++;
  console.log('PASS: spell costs one point and leaves all three offers intact.');

  const eligible = (choice, s) => {
    const army = s.roster[choice.card_id];
    const group = s.groups[choice.card_id];
    if (choice.kind === 'summon') return army.count + group <= 24 && s.total + group <= 72;
    if (choice.kind === 'reinforce') return army.summons >= 2 && army.reinforcements < 2 && army.count * 2 <= 24 && s.total + army.count <= 72;
    return army.summons >= 2 && army.rank < 3;
  };
  const value = (choice, s) => {
    const army = s.roster[choice.card_id];
    if (choice.kind === 'reinforce') return 120 + army.count;
    if (choice.kind === 'promote') return 80 + army.count;
    return (army.summons === 1 ? 45 : 25) + (choice.card_id.includes('tank') && army.count === 0 ? 50 : 0) - army.count;
  };
  while ((await snapshot()).screen !== 'results') {
    now = await snapshot();
    assert(now.round <= 18, 'match must reach its conclusion');
    if (now.phase === 'command') {
      if (now.points === 4) stats.comeback++;
      while (now.points > 0) {
        const choices = now.offers.map((choice, index) => ({ choice, index }))
          .filter(({ choice }) => eligible(choice, now))
          .sort((a, b) => value(b.choice, now) - value(a.choice, now));
        if (!choices.length) break;
        const { choice, index } = choices[0];
        const before = now;
        await click(87 + index * 145, 302);
        if (choice.kind === 'reinforce') {
          await page.waitForFunction(() => window.vtuberEraQA?.modal === 'reinforce');
          await screenshot('reinforcement-confirmation');
          await page.keyboard.press('Enter');
          await page.waitForFunction(points => window.vtuberEraQA?.points === points, before.points - 1);
          stats.reinforcements++;
        }
        now = await snapshot();
        assert.equal(now.points, before.points - 1);
        if (choice.kind === 'reinforce') {
          assert.equal(now.roster[choice.card_id].count, before.roster[choice.card_id].count * 2);
          assert.equal(now.roster[choice.card_id].rank, before.roster[choice.card_id].rank);
        }
        if (choice.kind === 'promote') {
          assert.equal(now.roster[choice.card_id].rank, before.roster[choice.card_id].rank + 1);
          assert.equal(now.roster[choice.card_id].count, before.roster[choice.card_id].count);
          stats.promotions++;
        }
        actions.push({ round: now.round, choice });
      }
      await screenshot(`command-round-${now.round}`);
      if (now.round === 1) {
        await page.setViewportSize({ width: 1000, height: 720 });
        await page.waitForTimeout(100);
        await screenshot('aspect-ratio');
        await page.setViewportSize({ width: 1280, height: 720 });
      }
      const hearts = now.hearts;
      // Test Space while a draft button has focus: it must start combat.
      await page.keyboard.press('Space');
      await page.waitForFunction(() => window.vtuberEraQA?.phase === 'combat');
      await page.waitForTimeout(700);
      await screenshot(`combat-round-${now.round}`);
      await page.waitForFunction(() => ['round_result', 'finished'].includes(window.vtuberEraQA?.phase), null, { timeout: 90000 });
      now = await snapshot();
      const heartLoss = hearts[0] + hearts[1] - now.hearts[0] - now.hearts[1];
      assert(heartLoss === 0 || heartLoss === 1, 'a result consumes at most one Heart');
      rounds.push({ round: now.round, hearts: now.hearts, heartLoss });
      console.log(`PASS: round ${now.round} resolved; Hearts ${now.hearts.join(' / ')}.`);
    }
    if (now.phase === 'round_result') {
      assert.equal(now.modal, 'round_result');
      await screenshot(`result-round-${now.round}`);
      await page.keyboard.press('Enter');
      await page.waitForFunction(round => window.vtuberEraQA?.round > round, now.round);
    }
  }
  visited.add('results');
  const final = await snapshot();
  assert(final.hearts.includes(0), 'four-Heart match reaches a real result');
  await screenshot('results');
  await click(483, 333);
  await page.waitForFunction(() => window.vtuberEraQA?.screen === 'battle' && window.vtuberEraQA.round === 1);
  const rematch = await snapshot();
  assert.deepEqual(rematch.hearts, [4, 4]);
  assert.equal(rematch.total, 0);
  assert.equal(rematch.spell, false);
  assert.equal(rematch.points, 3);
  assert.notEqual(rematch.seed, final.seed);
  console.log('PASS: Rematch resets all persistent and temporary match state.');
  await page.reload();
  await waitScreen('menu');
  const loadout = await snapshot();
  assert.equal(loadout.selected_commander, `${leaderRealm}_commander`);
  assert.deepEqual(loadout.selected_warband, chosenCards);
  assert.equal(loadout.rival, rival);
  console.log('PASS: commander, mixed/pure loadout and rival persist after reload.');
  assert.deepEqual(errors, [], 'browser must have no engine, HTTP or JavaScript errors');
  const report = { status: 'passed', scenario, rival, commander: `${leaderRealm}_commander`, warband: chosenCards,
    browser: await browser.version(), screens: [...visited],
    seed: initial.seed, rounds, actions, stats, errors, headers: 'ordinary HTTP; no cross-origin isolation',
    testedViewport: ['1280x720', '1000x720'], settingsPersisted: true, rematchPassed: true };
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
})().catch(async error => {
  console.error(error);
  if (activePage) {
    console.error('Last state:', await activePage.evaluate(() => window.vtuberEraQA).catch(() => null));
    await activePage.screenshot({ path: path.join(output,'failure.png') }).catch(() => {});
  }
  process.exitCode = 1;
}).finally(async () => {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
});
