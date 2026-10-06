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
const cards = ['fire_archer', 'fire_melee', 'fire_tank', 'fire_assassin', 'fire_candle',
  'water_mage', 'water_tank', 'water_melee', 'water_ranged', 'water_penguin',
  'earth_tank', 'earth_melee', 'earth_ranged', 'earth_siege', 'earth_pitcher'];
const chosenCards = process.env.QA_WARBAND ? process.env.QA_WARBAND.split(',')
  : scenario === 'mixed' ? ['fire_candle', 'water_penguin', 'earth_pitcher', 'fire_tank']
  : [...cards.slice(realms.indexOf(scenario) * 5, realms.indexOf(scenario) * 5 + 3),
      cards[realms.indexOf(scenario) * 5 + (process.env.QA_NEW_ARMIES ? 4 : 3)]];
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
const cardDetails = [];
const commanderDetails = [];
const skillRounds = [];
let reinforcementCancelPassed = false;
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
  await page.addInitScript(() => {
    // Observe real WebAudio buffer starts; do not alter sound or game timing.
    window.vtuberEraAudioQA = { starts: 0, shortEffects: 0 };
    const originalStart = AudioBufferSourceNode.prototype.start;
    AudioBufferSourceNode.prototype.start = function (...args) {
      window.vtuberEraAudioQA.starts++;
      if (this.buffer?.duration >= 0.08 && this.buffer.duration <= 0.26) {
        window.vtuberEraAudioQA.shortEffects++;
      }
      return originalStart.apply(this, args);
    };
  });
  activePage = page;
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('response', response => { if (response.status() >= 400) errors.push(`HTTP ${response.status()} ${new URL(response.url()).pathname}`); });
  const snapshot = () => page.evaluate(() => window.vtuberEraQA);
  const waitScreen = async screen => {
    await page.waitForFunction(screen => window.vtuberEraQA?.screen === screen, screen, { timeout: 60000 });
    visited.add(screen);
    assert.equal((await snapshot()).text_font, 'Minecraft');
    assert.equal((await snapshot()).text_overflows, 0, 'text stays inside its UI boxes');
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
    await click(211 + i * 106, 99);
    await page.waitForFunction(realm => window.vtuberEraQA?.compendium_realm === realm, realms[i]);
    await screenshot(`compendium-${realms[i]}`);
    assert.deepEqual((await snapshot()).compendium_cards, cards.slice(i*5,i*5+5));
    for (let index = 0; index < 5; index++) {
      const id = cards[i * 5 + index];
      await click(34.5 + index * 123, 144.5);
      await page.waitForFunction(id => window.vtuberEraQA?.card_details === id, id);
      assert.equal((await snapshot()).text_overflows, 0, 'full effects fit in the detail popup');
      if (index === 0 || index === 4) await screenshot(`details-${id}`);
      await page.keyboard.press('Escape');
      await page.waitForFunction(() => window.vtuberEraQA?.card_details === '');
      assert.equal((await snapshot()).compendium_realm, realms[i], 'details return to the same compendium tab');
      cardDetails.push(id);
    }
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
  if (process.env.QA_BATTLE_SPEED === '1') {
    await click(383, 195);
    await click(383, 217);
    await page.waitForFunction(() => window.vtuberEraQA?.settings.combat_speed === 1);
  }
  await click(320, 337);
  await waitScreen('menu');
  await click(320, 190);
  await waitScreen('commander');
  for (let i = 0; i < realms.length; i++) {
    await click(114 + i * 206, 204);
    await page.waitForFunction(id => window.vtuberEraQA?.selected_commander === id, `${realms[i]}_commander`);
    await click(38.5 + i * 206, 145.5);
    await page.waitForFunction(id => window.vtuberEraQA?.card_details === id, `${realms[i]}_commander`);
    assert.equal((await snapshot()).text_overflows, 0, 'active skill details fit in their box');
    await screenshot(`skill-details-${realms[i]}`);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => window.vtuberEraQA?.card_details === '');
    commanderDetails.push(`${realms[i]}_commander`);
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
    await click(76 + (index % 5) * 122, 175 + Math.floor(index / 5) * 44);
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
  await click(523, 80 + 20 * (realms.indexOf(rival) + 1));
  await page.waitForFunction(realm => window.vtuberEraQA?.rival === realm, rival);
  await screenshot('warband');
  await click(509, 336);
  await waitScreen('battle');
  const initial = await snapshot();
  assert.equal(initial.release, 'elemental-garden-armies');
  assert.deepEqual(initial.arena, [600, 280]);
  assert.equal(initial.body_size, 7.2);
  assert.equal(initial.spawn_spacing, 24);
  assert.deepEqual(initial.caps, {fire_archer:8, fire_melee:10, fire_tank:3, fire_assassin:3,
    water_mage:5, water_tank:3, water_melee:10, water_ranged:8,
    earth_tank:3, earth_melee:10, earth_ranged:8, earth_siege:4,
    fire_candle:4, water_penguin:4, earth_pitcher:6});
  assert.equal(initial.commander, `${leaderRealm}_commander`);
  assert.equal(initial.commanders[1], `${rival}_commander`);
  assert.deepEqual(initial.warbands[0], chosenCards);
  assert.equal(initial.bond, scenario === 'mixed' ? '' : ({ fire: 'wildfire', water: 'tidal_recovery', earth: 'earthen_guard' })[scenario]);
  console.log(`PASS: ${scenario} warband and ${leaderRealm} commander enter a real match against ${rival}.`);
  const initialOffers = JSON.stringify(initial.offers);
  assert.equal(initial.modal, 'command', 'round one automatically opens the card popup');
  assert.equal(initial.command_popup, true);
  await screenshot('round-picker');
  await click(337.5, 322.5);
  await page.waitForFunction(id => window.vtuberEraQA?.card_details === id, initial.commander);
  await page.keyboard.press('Space');
  await page.keyboard.press('b');
  assert.equal((await snapshot()).points, 3, 'reading skill details cannot spend points');
  assert.equal((await snapshot()).phase, 'command', 'reading skill details cannot start battle');
  await screenshot('round-skill-details');
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.vtuberEraQA?.card_details === '');
  await click(187, 322);
  let now = await snapshot();
  assert.equal(now.points, 2);
  assert.equal(now.spell, true);
  assert.equal(JSON.stringify(now.offers), initialOffers);
  stats.spell++;
  console.log('PASS: spell costs one point and leaves all three offers intact.');

  const eligible = (choice, s) => {
    const army = s.roster[choice.card_id];
    const group = s.groups[choice.card_id];
    if (choice.kind === 'summon') return army.count < s.caps[choice.card_id] && s.total < 72;
    if (choice.kind === 'reinforce') return army.summons >= 2 && army.reinforcements < 2 && army.count > 0 && army.count < s.caps[choice.card_id] && s.total < 72;
    return army.summons >= 2 && army.rank < 3;
  };
  const value = (choice, s) => {
    const army = s.roster[choice.card_id];
    if (choice.kind === 'summon' && choice.card_id === process.env.QA_PRIORITY_CARD) return 300 - army.count;
    if (choice.kind === 'summon' && ['fire_candle','water_penguin','earth_pitcher'].includes(choice.card_id)) return 250 - army.count;
    if (choice.kind === 'reinforce') return 120 + army.count;
    if (choice.kind === 'promote') return 80 + army.count;
    return (army.summons === 1 ? 45 : 25) + (choice.card_id.includes('tank') && army.count === 0 ? 50 : 0) - army.count;
  };
  while ((await snapshot()).screen !== 'results') {
    now = await snapshot();
    assert(now.round <= 18, 'match must reach its conclusion');
    if (now.phase === 'command') {
      assert.equal(now.modal, 'command', 'each round opens the picker');
      if (now.points === 4) stats.comeback++;
      if (!now.spell && now.points > 1) {
        const pointsBefore = now.points;
        await click(187, 322);
        await page.waitForFunction(points => window.vtuberEraQA?.points === points && window.vtuberEraQA?.spell, pointsBefore - 1);
        stats.spell++;
        now = await snapshot();
      }
      const detailsBefore = now;
      await click(72.5, 140.5);
      await page.waitForFunction(id => window.vtuberEraQA?.card_details === id, now.offers[0].card_id);
      await screenshot('draft-card-details');
      await page.keyboard.press('Space');
      assert.equal((await snapshot()).phase, 'command', 'Space cannot start battle while reading card effects');
      assert.equal((await snapshot()).card_details, detailsBefore.offers[0].card_id, 'Space cannot activate Close and leak the following Escape into settings');
      await page.keyboard.press('Escape');
      await page.waitForFunction(() => window.vtuberEraQA?.card_details === '');
      now = await snapshot();
      assert.equal(now.screen, 'battle');
      assert.equal(now.modal, 'command');
      assert.equal(now.points, detailsBefore.points);
      assert.deepEqual(now.offers, detailsBefore.offers, 'reading effects never rerolls cards');
      while (now.points > 0) {
        const choices = now.offers.map((choice, index) => ({ choice, index }))
          .filter(({ choice }) => eligible(choice, now))
          .sort((a, b) => value(b.choice, now) - value(a.choice, now));
        if (!choices.length) break;
        const { choice, index } = choices[0];
        const before = now;
        await click(137 + index * 178, 205);
        if (choice.kind === 'reinforce') {
          await page.waitForFunction(() => window.vtuberEraQA?.modal === 'reinforce');
          await screenshot('reinforcement-confirmation');
          if (!reinforcementCancelPassed) {
            await page.keyboard.press('Escape');
            await page.waitForFunction(() => window.vtuberEraQA?.modal === 'command');
            const cancelled = await snapshot();
            assert.equal(cancelled.points, before.points);
            assert.deepEqual(cancelled.offers, before.offers);
            assert.deepEqual(cancelled.roster, before.roster, 'Cancel keeps armies and points unchanged');
            reinforcementCancelPassed = true;
            await click(137 + index * 178, 205);
            await page.waitForFunction(() => window.vtuberEraQA?.modal === 'reinforce');
          }
          await page.keyboard.press('Enter');
          await page.waitForFunction(points => window.vtuberEraQA?.points === points, before.points - 1);
          stats.reinforcements++;
        }
        now = await snapshot();
        assert.equal(now.points, before.points - 1);
        for (const id of Object.keys(now.roster)) assert(now.roster[id].count <= now.caps[id], 'draft cannot exceed a role cap');
        if (choice.kind === 'summon') assert.equal(now.roster[choice.card_id].count, Math.min(before.roster[choice.card_id].count + before.groups[choice.card_id], before.caps[choice.card_id], before.roster[choice.card_id].count + 72 - before.total));
        if (choice.kind === 'reinforce') {
          assert.equal(now.roster[choice.card_id].count, Math.min(before.roster[choice.card_id].count * 2, before.caps[choice.card_id], before.roster[choice.card_id].count + 72 - before.total));
          assert.equal(now.roster[choice.card_id].rank, before.roster[choice.card_id].rank);
        }
        if (choice.kind === 'promote') {
          assert.equal(now.roster[choice.card_id].rank, before.roster[choice.card_id].rank + 1);
          assert.equal(now.roster[choice.card_id].count, before.roster[choice.card_id].count);
          stats.promotions++;
        }
        actions.push({ round: now.round, choice, beforeCount: before.roster[choice.card_id].count, afterCount: now.roster[choice.card_id].count, cap: now.caps[choice.card_id] });
      }
      // Even exhausted/disabled offers keep their info icons usable.
      if (now.points === 0) {
        await click(72.5, 140.5);
        await page.waitForFunction(id => window.vtuberEraQA?.card_details === id, now.offers[0].card_id);
        assert.equal((await snapshot()).points, 0);
        await page.keyboard.press('Escape');
        await page.waitForFunction(() => window.vtuberEraQA?.card_details === '');
      }
      await screenshot(`command-round-${now.round}`);
      assert.equal(now.preview.length, now.total + now.preview.filter(unit => unit[0] === 1).length);
      for (let a = 0; a < now.preview.length; a++) {
        for (let b = a + 1; b < now.preview.length; b++) {
          const first = now.preview[a], second = now.preview[b];
          assert(Math.abs(first[2] - second[2]) >= 24 || Math.abs(first[3] - second[3]) >= 24,
            'all preview/spawn creature footprints must be separate');
        }
      }
      if (now.round === 1) {
        assert.equal(now.pixel_scale_mode, 'integer', 'comfortable windows use crisp integer pixels');
        await page.setViewportSize({ width: 1000, height: 720 });
        await page.waitForFunction(() => window.vtuberEraQA?.pixel_scale_mode === 'fit');
        await screenshot('aspect-ratio');
        await page.setViewportSize({ width: 1280, height: 720 });
        await page.waitForFunction(() => window.vtuberEraQA?.pixel_scale_mode === 'integer');
      }
      const hearts = now.hearts;
      // Both the actual Battle button and its shortcut start combat from the popup.
      if (now.round === 2) await page.keyboard.press('Space');
      else await click(493, 322);
      await page.waitForFunction(() => window.vtuberEraQA?.phase === 'combat');
      const combat = await snapshot();
      assert.equal(combat.command_popup, false);
      assert.equal(combat.battle_controls_visible, false, 'draft controls disappear so combat fills the arena');
      assert.equal(combat.modal, '');
      await page.waitForFunction(() => window.vtuberEraQA?.skills?.activated.some(Boolean));
      let skillState = await snapshot();
      const preparedSkills = [...skillState.skills.prepared];
      if (leaderRealm === 'fire') {
        if (skillState.skills.opening) assert.equal(skillState.tick, 0, 'battle clock waits for all six meteor strikes');
        else assert.equal(skillState.skills.counts.meteors[0], 6, 'a completed opening contains all six impacts');
        for (const body of skillState.combat_positions) {
          const spawn = now.preview[body[0]];
          if (spawn && skillState.skills.opening && !skillState.passives?.imp_explosion) assert.deepEqual(body.slice(2), spawn.slice(2), 'opening holds troop positions until a death blast applies physical pushback');
        }
        await screenshot(`meteor-opening-${now.round}`);
        await page.waitForFunction(() => window.vtuberEraQA?.skills && !window.vtuberEraQA.skills.opening);
        skillState = await snapshot();
        assert.equal(skillState.skills.counts.meteors[0], 6, 'exactly six player meteors land');
      }
      for (let side = 0; side < 2; side++) {
        if (preparedSkills[side] && initial.commanders[side] === 'earth_commander') {
          assert.equal(skillState.skills.counts.earth_walls[side], 3, 'Earth raises three walls in the enemy field');
        }
      }
      for (const status of skillState.combat_statuses) {
        const body = skillState.combat_positions.find(unit => unit[0] === status[0]);
        if (body) {
          const enemySide = 1 - body[1];
          const frozen = preparedSkills[enemySide] && initial.commanders[enemySide] === 'water_commander';
          assert(Math.abs(status[2] - (frozen ? 0.92 : 1)) < 0.001, 'ice reduces only enemy defence');
        }
      }
      await page.waitForTimeout(220);
      const chargeState = await snapshot();
      if (chargeState.combat_statuses?.some(status => status[6])) await screenshot(`ninja-charge-${now.round}`);
      await page.waitForTimeout(480);
      await screenshot(`combat-round-${now.round}`);
      await page.waitForFunction(() => {
        const state = window.vtuberEraQA;
        const bodies = state?.combat_positions || [];
        for (let a = 0; a < bodies.length; a++) {
          for (const wall of state.walls || []) {
            const half = state.body_size / 2 - 0.001;
            if (bodies[a][2] > wall[1] - half && bodies[a][2] < wall[1] + wall[3] + half &&
                bodies[a][3] > wall[2] - half && bodies[a][3] < wall[2] + wall[4] + half) {
              throw new Error(`Unit ${bodies[a][0]} clipped an Earth wall`);
            }
          }
          for (let b = a + 1; b < bodies.length; b++) {
            if (Math.abs(bodies[a][2] - bodies[b][2]) < state.body_size - 0.001 && Math.abs(bodies[a][3] - bodies[b][3]) < state.body_size - 0.001) {
              throw new Error(`Solid bodies overlapped: ${bodies[a][0]} / ${bodies[b][0]}`);
            }
          }
        }
        if (state?.text_overflows) throw new Error('Text escaped its assigned box');
        return ['round_result', 'finished'].includes(state?.phase);
      }, null, { timeout: 90000 });
      now = await snapshot();
      skillRounds.push({ round: now.round, prepared: preparedSkills, counts: now.skills.counts });
      for (let side = 0; side < 2; side++) {
        const key = ({fire_commander: 'meteors', water_commander: 'frozen_field', earth_commander: 'earth_walls'})[initial.commanders[side]];
        const expected = preparedSkills[side] ? ({meteors: 6, frozen_field: 1, earth_walls: 3})[key] : 0;
        assert.equal(now.skills.counts[key][side], expected, 'prepared skills cast exactly once per round');
      }
      const heartLoss = hearts[0] + hearts[1] - now.hearts[0] - now.hearts[1];
      assert(heartLoss === 0 || heartLoss === 1, 'a result consumes at most one Heart');
      rounds.push({ round: now.round, hearts: now.hearts, heartLoss, passives: now.passives });
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
  assert(final.combat_sounds > 0, 'combat events play actual sound effects');
  assert(Object.keys(final.passives || {}).length > 0, 'new army passives trigger in real browser combat');
  const audio = await page.evaluate(() => window.vtuberEraAudioQA);
  assert(audio.shortEffects > 0, 'new combat samples start in WebAudio');
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
    release: initial.release,
    browser: await browser.version(), screens: [...visited],
    seed: initial.seed, rounds, actions, stats, errors, headers: 'ordinary HTTP(S); no cross-origin isolation',
    testedViewport: ['1280x720', '1000x720'], arena: initial.arena, bodySize: initial.body_size,
    spawnCollisionPassed: true, combatCollisionPassed: true, settingsPersisted: true, rematchPassed: true };
  report.textFont = final.text_font;
  report.cardDetails = cardDetails;
  report.commanderDetails = commanderDetails;
  report.commanderSkills = skillRounds;
  report.wallCollisionPassed = true;
  report.armyCaps = initial.caps;
  report.priorityCard = process.env.QA_PRIORITY_CARD || '';
  report.battleSpeed = final.settings.combat_speed;
  report.armyCapsPassed = true;
  report.roundPopupPassed = true;
  report.combatControlsHidden = true;
  report.reinforcementCancelPassed = reinforcementCancelPassed;
  report.passives = final.passives;
  report.textOverflows = final.text_overflows;
  report.combatSoundsPlayed = final.combat_sounds;
  report.webAudio = audio;
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
