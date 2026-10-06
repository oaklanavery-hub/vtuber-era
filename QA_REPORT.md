# Commander active skills — 6 October 2026

Each commander now prepares an active skill for **one Command Point**, once per
round. Preparation preserves the three offers and the draft RNG. Skills cast
when Battle starts; commander passives remain active. Info buttons on commander
selection and beside Prepare show the full rules, with the existing readable
Minecraft font and protected detail-overlay keyboard behavior.

- **Meteor Rain:** six AOE impacts across the enemy field, 30 damage in a 34px
  radius each. Both armies and the battle clock wait during the two-second
  opening. Shields, defence and normal death passives apply. Opposing impacts
  resolve simultaneously and all six strikes complete before elimination.
- **Frozen Field:** full-field ice; all enemies move 15% slower and have defence
  multiplied by 0.92 for the round. Stronger slows take priority. Defence divides
  incoming damage before shields (about 8.7% more); new Slimes and revived Ninjas
  remain affected. Allies are unaffected by their own commander’s ice.
- **Uproot:** three staggered 12×72px walls on the enemy field for the round.
  Both armies route around their expanded corners. Swept collision stops units,
  knockback and projectiles. Attacks require clear line of sight; obscured ranged
  units seek visible targets or reposition. Split arrows and projectile splash
  obey wall visibility. Slimes cannot be born through or inside walls.

Pixel meteor warnings, falling stones, impact rings, icy ground, enemy debuff
marks and mossy earth walls show the effects. Skill casts, meteor impacts and
blocked shots use combat sound cues. Essential terrain and meteor warnings
remain visible with reduced effects. Terrain and modifiers clear at round end.
Unspecified damage, dimensions and round-long durations use the defaults above.

Native validation used exact Godot **4.5.stable.official.876b29033**:

| Runner | Checks | Failures |
|---|---:|---:|
| Rules and drafting | 1,016 | 0 |
| Elemental mechanics, full matches and replays | 18,674 | 0 |
| All twelve army passives | 24,522 | 0 |
| Ninja pursuit and resurrection | 976 | 0 |
| Permanent collision and formations | 75,098 | 0 |
| Commander active skills, terrain and 144-unit replays | 1,845 | 0 |
| **Gameplay total** | **122,131** | **0** |
| Native UI, skill details, audio and round flows | — | 0 |

Four complete WebAssembly/WebGL browser matches passed:

| Warband | Rival | Rounds | Combat sound cues | Errors / overflows |
|---|---|---:|---:|---:|
| Fire | Fire | 4 | 177 | 0 |
| Water | Earth | 4 | 418 | 0 |
| Earth | Water | 5 | 947 | 0 |
| Mixed | Fire | 5 | 289 | 0 |

Every match exercises all twelve army details and all three commander details,
preparation each round, exact skill counts, ice defence values, collision against
units and earth walls, card picking, reinforcement/promotions, Battle/Space,
hidden combat controls, Hearts, results, saved settings/loadouts and Rematch.
The Earth browser match recorded 14 blocked projectiles across its last three
rounds. The mixed match exercised the rival's six-meteor opening alongside ice.
The existing 1280×720 and 1000×720 layouts retain the full arena and fitted text.
Final terrain colour improvements passed native UI and targeted browser visual
inspection at normal playback. The workflow includes the new skill runner.

Evidence: `docs/qa/commander-native.txt` and
`docs/qa/commander-browser-{fire,water,earth,mixed}.json`.
Screenshots: `docs/screenshots/commander-{meteors,ice,walls,skill-details}.png`.
Following sections are historical evidence for earlier builds.

---

# Round picker, card details and expanded combat — 6 October 2026

Each Command Phase opens a centered card picker. Cards show the army, action,
short benefit and cost. A separate top-left info icon opens full base stats and
army effects. Reading effects neither spends points nor refreshes offers, and
Escape/Enter/Close returns to the same picker. The same component supplies the
compendium's clean card faces and effects popups. Info remains usable after all
points are spent. Keyboard shortcuts cannot activate controls behind an open
effects popup; focus returns to its info icon when closed.

Playing a card spends one point and refreshes the offers inside the picker;
spell preparation remains independent. Reinforcement Confirm and Cancel both
return to the picker. Battle and Space start actual combat and remove all draft
controls. The battlefield expands from 600×202 to **600×280** (38.6% more area),
with nine 24px-spaced spawn rows, wider movement bounds and aligned Ninja flanks.
The score/Hearts/clock remain in the compact top header.

Proportional Minecraft-style lettering uses Idrees Hassan's unchanged fan font,
SIL OFL notice, explicit symbol fallback, disabled antialiasing/subpixel
positioning, and a 10px logical minimum. The existing 640×360 viewport scaling
policy still provides crisp 2× pixels or fit scaling in smaller windows.

Native validation, exact Godot **4.5.stable.official.876b29033**:

| Runner | Checks | Failures |
|---|---:|---:|
| Rules and draft mechanics | 1,002 | 0 |
| Elemental mechanics and full-match replays | 17,440 | 0 |
| All twelve army passives | 24,522 | 0 |
| Ninja pursuit and resurrection | 976 | 0 |
| Permanent collision and formations | 75,098 | 0 |
| **Gameplay total** | **119,038** | **0** |
| Native UI, all card details, modal guards, reinforcement and results | — | 0 |

Four complete WebAssembly/WebGL browser matches passed:

| Warband | Rival | Rounds | Combat sound cues | Errors / overflows |
|---|---|---:|---:|---:|
| fire | fire | 4 | 155 | 0 |
| water | earth | 7 | 950 | 0 |
| earth | water | 5 | 450 | 0 |
| mixed | fire | 5 | 351 | 0 |

Each run covers all 12 compendium info icons, draft effects without point/offer
changes, the keyboard-focus regression, info on exhausted cards, per-round
popups, Battle/Space, hidden combat controls, collisions, spell preparation,
settings/loadout persistence, Hearts, results and Rematch. Reinforcement Cancel
and Confirm are covered in the native UI fixture and applicable browser runs.
1280×720 and 1000×720 layouts were visually inspected. A final singular/plural
wording correction passed the native UI checks after these browser matches.

Evidence: `docs/qa/round-picker-native.txt`,
`docs/qa/round-picker-browser-{fire,water,earth,mixed}.json`.
Screenshots: `docs/screenshots/{round-picker,clean-compendium,card-effects,expanded-battle,small-round-picker}.png`.
The Web export was verified with the new font's OFL notice and existing notices.
Prior sections are historical evidence for earlier builds.

---

# Ninja pursuit and pixel graphics — 6 October 2026

Ninjas now end their opening flank at contact, derive their lane from their
actual spawn position, fight a reachable defender before chasing the backline,
and approach directly when no backline remains. A six-second deadline prevents
an indefinitely blocked opening flank. Resurrection remains once per battle at
exactly 30% actual max HP, with a commander-adjusted cooldown, a distinct sprite
frame, a one-second pixel ring and a persistent gold mark.

All twelve original armies were redrawn on a 32×32 grid with a shared 32-color
palette, shaded material details and eight-frame atlases. They render at native
size in battle and cards. Pixelify Sans supplies light pixel lettering at a
10px minimum; an explicit DejaVu fallback supplies arrows and missing symbols.
Panels, Settings switches/slider, environment details and ability rings use
pixel graphics. Nearest-filtered viewport scaling uses integer factors at 2× or
larger, and fit scaling below 2× to avoid an unreadable 1× UI in smaller windows.

- Rules/economy/combat: **1,072 checks; 0 failures**.
- Elemental mechanics and 33 complete matches/replays: **18,930 checks; 0 failures**.
- Twelve army passives: **24,522 checks; 0 failures**.
- Permanent collision and formations: **75,098 checks; 0 failures**.
- Ninja pursuit and resurrection: **976 checks; 0 failures**.
- Total gameplay assertions: **120,598; 0 failures**.
- Native UI, typography, arrow fallbacks and audio: **0 failures**.

Before the fix, focused reproductions failed opening contact, reachable-defender
attacks, two roster-parity lane cases and direct pursuit without a backline.
The Ninja runner now leaves real movement and flanking enabled on both sides,
checks contact attacks, exact revival HP and cooldowns, replay signatures, and
collision during interpolation. The hostile-defender formation test enables
Ninja attacks so it can clear a blocking tank before reaching the backline.

Four full WebAssembly/WebGL match types passed with zero engine, JavaScript or
HTTP errors and zero text-box overflows. Tests cover all Compendium tabs,
settings/loadout persistence, actual drafting/spells, collision, Hearts,
results and Rematch. Resize assertions confirm fit scaling at 1000×720 and
integer scaling after restoring 1280×720. Fire was rerun after the final cosmetic
Settings icons and contrast pass; the other reports use the same final combat,
font and resize logic. The final native UI test covers those Settings assets.

| Player | Rival | Rounds | Combat sounds played | New samples observed in WebAudio |
|---|---|---:|---:|---:|
| Fire | Fire | 4 | 300 | 300 |
| Water | Earth | 5 | 591 | 591 |
| Earth | Water | 5 | 587 | 587 |
| Mixed | Fire | 5 | 215 | 215 |

Reports: `docs/qa/pixel-polish-browser-*.json` and `pixel-polish-native.txt`.
Visually inspected examples: `docs/screenshots/pixel-polish-{compendium,battle,settings,small-window}.png`.
Official Godot 4.5 engine and matching Web templates passed SHA-512 verification;
the single-threaded export includes the new font licence and existing notices.

The evidence below is historical and describes earlier releases.

# Army passives and readable text — 6 October 2026

All interface text now uses smooth DejaVu Sans, with a 9px logical minimum and
rectangle-based fitting. The compact HUD, 600×202 battlefield, 7.2×7.2 permanent
collision bodies, depth order, existing save format and combat audio remain.
Compendium cards explain all twelve passives directly and retain full stats in
tooltips. Resource-backed parameters and unspecified defaults are in `BALANCE.md`.

- Rules/economy/combat: **1,016 checks; 0 failures**.
- Elemental mechanics and 33 complete matches/replays: **17,900 checks; 0 failures**.
- All twelve army passives: **24,522 checks; 0 failures**.
- Permanent collision and formations: **74,858 checks; 0 failures**.
- Native UI, font fitting and audio resources/events: **0 failures**.

The passive runner covers projectile splash, enemy-only death explosions and
simultaneous explosion chains; two-second wall Burn independent of Wildfire;
once-per-battle 30%-HP Ninja revival; swept pushback stopped by blockers and arena
edges; separate, non-stacking Wizard/ice Slow timers; two half-damage Slime
children without recursive splitting; the last Snowman's head landing before
round resolution; 5%-max-HP Tree healing every 2s; 20% attack Slow and an in-place
Armadillo bounce; three arrows sharing exactly one attack's damage every 5s;
huge siege radius/falloff; and complete cleanup and new-battle reset.

Maximum drafted crowds splitting every Slime produce 240 recorded units and
192 living bodies (96 per side). Spawn positions, swept movement, interpolation,
health bounds and deterministic replay all remain valid. Children never change
persistent roster counts, caps, draft history or the next battle's base roster.

Official Godot 4.5 engine and Web templates match the release SHA-512 checksums.
All twelve army Resources reproduce from the original asset generator. The
single-threaded WebAssembly/WebGL release passes four full browser match types
with zero engine, JavaScript or HTTP errors, zero text-box overflows, settings
and loadout persistence, real spell/draft actions, Hearts, results and Rematch.
All twelve requested passives were observed across the browser scenarios.
Fire/Fire is unaffected by the final Armadillo animation synchronization; the
Water, Earth and mixed scenarios were rerun after that change.

| Player | Rival | Rounds | Combat sounds played | New samples observed in WebAudio |
|---|---|---:|---:|---:|
| Fire | Fire | 6 | 385 | 385 |
| Water | Earth | 4 | 296 | 296 |
| Earth | Water | 5 | 730 | 730 |
| Mixed | Fire | 6 | 266 | 266 |

Reports: `docs/qa/army-passives-browser-*.json` and
`docs/qa/army-passives-native.txt`. Visually inspected 1280×720 and 1000×720
screenshots show readable text, bounded compact controls, visible ability
descriptions and flame/ice/heal cues. Current examples:
`docs/screenshots/passives-compendium.png` and `passives-battle.png`.

The evidence below is historical and describes earlier releases.

# Compact collisions, pixel fonts and combat audio — 5 October 2026
Collision remains permanent on both teams. Its width and height are reduced by 70%, from 24px to 7.2px. Spawn spacing remains 24px, while depth-sorted sprites may partially overlap above the smaller bodies. Out-of-range pursuit and detours remain active.
All UI text uses licensed Tiny5 with pixel rendering and rectangle-based fitting. Original pixel heart icons avoid unsupported font glyphs. Twelve new synthesized combat effects use event coalescing, cooldowns and a separate quiet six-voice pool; the existing volume setting controls them.
- Rules/economy/combat: **1,002 checks; 0 failures**.
- Elemental mechanics and 33 complete matches/replays: **17,482 checks; 0 failures**.
- Permanent collisions and formations: **74,858 checks; 0 failures**.
- Native UI, font layout and audio resources/events: **0 failures**.
Official Godot 4.5 engine and Web-template SHA-512 checksums match. The release export includes Tiny5 OFL notices. Four complete WebAssembly/WebGL browser matches passed collision sampling, pixel-font box checks, settings/loadout persistence, spells/drafting, Hearts, results and Rematch, with no engine, JavaScript or HTTP errors.
| Player | Rival | Rounds | Combat sounds played | New samples observed in WebAudio |
|---|---|---:|---:|---:|
| Fire | Fire | 6 | 369 | — |
| Water | Earth | 7 | 892 | 892 |
| Earth | Water | 5 | 476 | 476 |
| Mixed | Fire | 4 | 228 | 228 |

Reports: `docs/qa/pixel-audio-browser-*.json`. Visually inspected screenshots at 1280×720 and 1000×720 show readable menus, all twelve army names, compact controls and closer combat crowds. Current examples: `docs/screenshots/pixel-audio-battle.png` and `pixel-audio-warband.png`.

The evidence below is historical and describes the earlier 24px-footprint release.

# Creature-army and collision validation — 5 October 2026

## Creature update

All twelve army IDs, base stats, roles, effects and saved loadouts are preserved.
Their names and original six-frame sprites now match the requested creature
appearances. Commander portraits are unchanged. The 600×202 arena has about
52% more area than the old 560×142; battle cards shrink from 96px to 64px tall.

- Rules/economy/combat runner: **932 checks; 0 failures**.
- Elemental runner: **15,800 checks; 0 failures**, including 33 full matches
  and deterministic replay across pure and mixed warbands.
- Permanent collision/formation runner: **74,855 checks; 0 failures**.
- Native UI smoke: **0 failures**.

Collision coverage includes maximum 144-unit crowds, mixed duplicate-role armies,
unique preview/spawn positions, mirrored formations, in-bounds motion, swept-body
collision on both teams, interpolation without clipping, speed limits, detours
around allied and hostile blockers, arena-edge escape, pursuit into attack range,
functional melee contact and fixed-tick replay. No collision toggle or temporary
spawn-only bypass exists. Completely blocked units wait for a safe lane rather
than passing through another body.

The final release WebAssembly/WebGL export passed four complete browser matches,
saved-settings/loadout reloads, real spells and draft actions, round Hearts,
results and Rematch. Each scenario checked non-overlapping previews and live
combat positions on both teams throughout the match, with zero engine,
JavaScript or HTTP errors.

| Player | Rival | Rounds | Reinforcements | Promotions |
|---|---|---:|---:|---:|
| Fire | Fire | 5 | 4 | 4 |
| Water | Earth | 5 | 6 | 4 |
| Earth | Water | 5 | 3 | 3 |
| Mixed | Fire | 7 | 2 | 6 |

Traces are in `docs/qa/creature-browser-*.json`. Visually inspected screenshots
show all twelve creature designs, the compact header/cards and larger arena at
1280×720 and 1000×720. Current presentation examples are
`docs/screenshots/creature-battle.png` and `creature-warband.png`.

The earlier Phase 2 evidence below is historical. Its balance sample predates
solid collision and must not be interpreted as current movement-system win rates.

# Previous Phase 2 validation — historical

## Release configuration

Exact Godot `4.5.stable.official.876b29033`, standard GDScript, Compatibility
renderer, 640x360 with preserved 16:9 and nearest filtering. Web threads and
GDExtensions are disabled. Official engine/templates were SHA-512 verified;
exported HTML, JavaScript, WebAssembly and resource-pack files were checked.
The Web output includes `.nojekyll` and engine/font notices.

## Automated correctness

- `tests/run_tests.gd`: **1,030 checks; 0 failures**.
- `tests/elemental_tests.gd`: **16,212 checks; 0 failures**.
- `tests/ui_smoke.gd`: **0 failures**, without engine/script errors.

Coverage includes shared economy/caps/offers, all three Commanders and spells,
independent mixed loadouts, per-side AI offers/frozen snapshots, shield absorption
and expiry, affinity bonuses, non-stacking Slow and Burn, timed healing without
resurrection, actual-damage lifesteal and caps, Tidal Recovery's same-tick threshold,
siege travel/targeting/splash, assassin backline priority and version 0/1 migration.
The elemental suite completes 33 full four-Heart matches including seeded replay
across all nine ordered realm pairings and all Commanders with a mixed warband.
Every completed battle checks finite bounded HP and cleared temporary effects.

UI smoke exercises all Commander/compendium pages, incomplete/overfull loadout
rejection, mixed drafting against an independent rival, spells, real combat,
round advancement, Victory, Defeat and Rematch.

## Exported browser play

Real Chromium 151 runs the release WebAssembly/WebGL build over ordinary HTTP
at `/vtuber-era/`, without custom cross-origin isolation headers. All four final
scenarios passed complete matches, settings/loadout persistence across reload,
spell offer preservation, one-point draft actions, reinforcement confirmation,
promotions, comeback points, round Hearts, results and Rematch.

| Player warband | Rival | Rounds | Reinforcements | Promotions |
|---|---|---:|---:|---:|
| Fire | Fire | 5 | 1 | 4 |
| Water | Earth | 6 | 6 | 3 |
| Earth | Water | 5 | 2 | 2 |
| Mixed | Fire | 6 | 5 | 3 |

Each scenario recorded **zero engine, JavaScript or HTTP errors**. Screenshots
were visually inspected at 1280x720 and 1000x720. Commander cards, all twelve
army selections, pure/mixed bond information, long spell names, ranged/siege
sprites and dynamic opposing realms fit the logical layout. Space starts combat
while a card has focus. Rematch restores four Hearts, three points, no armies,
no queued spell and a new seed while retaining the chosen loadout.

The traces and real actions are in `docs/qa/phase2-browser-*.json`;
`docs/screenshots/phase2.png` shows Earth versus Water combat, and
`phase2-warband.png` shows an independent Water Commander with mixed cards.

## Balance sample

`tests/balance_simulations.gd` completed **72 full AI matches**: eight fixed seeds
for all nine ordered realm pairings, using the same AI policy and budgets on both
sides. Final results are in `docs/qa/phase2-balance.json`. All pairings produced
wins for both sides in the sample. Mean match lengths ranged from 5.25 to 6 rounds.
Initial Water/Earth dominance led to stat/splash reductions and diminishing value
for repeated assassin summons. Original Fire base stats are preserved.

This sample demonstrates varied outcomes and termination, not competitive player
balance. Additional seeds, player strategies and larger roster performance tests
remain useful.

## Publishing

The existing public source is
[oaklanavery-hub/vtuber-era](https://github.com/oaklanavery-hub/vtuber-era).
The Pages workflow installs the exact engine/templates, runs all three
correctness suites, exports and deploys to the existing
[playable URL](https://oaklanavery-hub.github.io/vtuber-era/).

## Remaining validation

Firefox, Safari and mobile performance remain untested. Portraits/art/music are
replaceable placeholders, and active matches are not saved. Versioned settings
and selected loadouts preserve existing saves without resetting them.
