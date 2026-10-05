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
