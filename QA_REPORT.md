# Phase 1 validation — 5 October 2026

## Release configuration

- Exact engine: `4.5.stable.official.876b29033`.
- Standard GDScript project; Compatibility renderer.
- Logical 640×360, preserved 16:9, nearest-neighbour textures.
- Web threads and GDExtensions disabled.
- Official engine and template SHA-512 checksums verified locally.
- Required `.html`, `.js`, `.wasm` and `.pck` outputs verified.
- `.nojekyll` and engine/font notices included in Web output.

## Automated gameplay

`godot --headless --path . --script res://tests/run_tests.gd`

**1,016 checks; 0 failures.** Coverage includes four-card uniqueness, Wildfire,
starting/comeback points, skill costs and duration, offer preservation, summons,
eligibility, two-use Reinforcements, Rank 3, 24/72 caps, persistence, full-HP
reset, effects cleanup, Hearts, no double result application, legal AI actions,
frozen opponent information, seeded full-match replay, differently batched ticks,
melee/projectile damage, Burn timing, assassin priority, timeout comparisons,
escalating sudden death and invalid save recovery.

`godot --headless --path . --script res://tests/ui_smoke.gd`

**0 failures.** Loading, menu, compendium, settings, Commander, Warband, actual
summoning/spell UI, combat, round results, Victory, Defeat and Rematch exercised.
No script errors, resource leak warnings or engine errors in the final runners.

## Exported browser play

Playwright controls a real Chromium 151 browser with the release WebAssembly
build served through ordinary localhost HTTP at `/vtuber-era/`. The browser is
not cross-origin isolated and receives no COOP/COEP workaround headers.

The recorded full match (seed `1791185542`) completed six rounds: player Hearts
3 → 2 → 1 → 1 → 1 → 0; AI Hearts 4 → 4 → 4 → 3 → 2 → 2. It exercised five
Reinforcements, three Promotions, one prepared spell and three comeback phases.
Each observed action spent one point; Reinforcements doubled without changing
Rank; Promotions kept counts; spell preparation preserved offers. The match
ended in Defeat and Rematch restored four Hearts, three points, empty armies,
no queued spell and a new seed. Zero engine, JavaScript or HTTP errors occurred.

Settings survived a browser reload through IndexedDB. Viewports 1280×720 and
1000×720 preserved the logical 16:9 field. Space started combat even while a
card had focus. Both the raw trace and action list are in
`docs/qa/browser-report.json`. A final layout pass fixed portrait sizing, header
roster placement, enemy sprite/HP alignment and the settings popup palette.

The final export was then tested through another complete browser match (seed
`1791186025`, four rounds, two Reinforcements, three comeback phases), with saved
settings, zero errors and successful Rematch again. Its trace is retained in
`docs/qa/browser-report-final.json`. Screenshots of the final export were visually
reviewed; enemy portraits and HP bars share the same position.

## External deployment status

The public repository is
[`oaklanavery-hub/vtuber-era`](https://github.com/oaklanavery-hub/vtuber-era),
and the browser release is live at
[`oaklanavery-hub.github.io/vtuber-era`](https://oaklanavery-hub.github.io/vtuber-era/).

GitHub Actions run
[`37285925817`](https://github.com/oaklanavery-hub/vtuber-era/actions/runs/37285925817)
completed successfully on 5 October 2026. Its build job installed the exact
engine/templates, verified checksums, imported resources, passed both test
runners, exported the Web release and uploaded the Pages artifact. The dependent
deploy job also completed successfully. The live page serves the `VTuber Era`
document and Godot loader from the expected `/vtuber-era/` project path.

## Remaining validation

Firefox, Safari, mobile performance and large-scale balance playtesting remain
future work. Correctness tests do not establish competitive balance. Placeholder
art and original synthesized audio are Phase 1 production limits.
