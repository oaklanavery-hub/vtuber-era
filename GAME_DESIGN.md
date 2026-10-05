# VTuber Era — Phase 2 game design

The Convergence Festival is a friendly fantasy contest. Units disperse into
sparks and return next round; Commanders remain in the UI.

## Match and loadout

Choose any of three Commanders, then exactly four unique army cards from twelve.
Pure realm presets and mixed warbands are legal. A four-card Realm Bond depends
only on the cards' shared set, independently of the Commander. The rival selector
provides a Mirror loadout or a pure Fire, Water or Earth AI.

Both sides begin with four Hearts. Each Command Phase grants three points plus
one comeback point to the previous loser. Each action or prepared spell costs
one point; unused points disappear at battle start. Automatic combat permits no
manual commands, movement or targeting. Rematch resets all match state and seed.

## Commanders

| Commander | Passive | One-point spell |
|---|---|---|
| Fire | All allies +5% attack damage; Fire allies +5% attack speed | Blazing Orders: all allies +25% attack speed for 6s |
| Water | All allies +5% max HP; Water allies +10% healing and shields | Healing Current: all living allies heal 3% max HP/s for 5s |
| Earth | All allies take 5% less damage; Earth allies +5% max HP | Stonewall Formation: all allies take 20% less damage for 7s |

Preparation is once per round, preserves all three offers and applies only to
the next battle. Earth reductions multiply: 0.95 × 0.80 incoming damage while
Stonewall is active. Water affinity belongs to the recipient of healing/shields.
Healing never resurrects and never exceeds max HP.

## Armies and bonds

| Realm | Army | Role | Group |
|---|---|---|---:|
| Fire | Emberbow Rangers | Ranged | 3 |
| Fire | Ashblade Warriors | Melee | 3 |
| Fire | Cinderwall Guardians | Tank | 1 |
| Fire | Flameveil Stalkers | Assassin | 1 |
| Water | Tidecallers | Mage: splash and non-stacking movement Slow | 2 |
| Water | Coral Wardens | Tank: nearby initial shields | 1 |
| Water | Waveblade Fighters | Melee: capped lifesteal | 3 |
| Water | Moonwater Rangers | Long-range ranged | 3 |
| Earth | Stoneguard Sentinels | Highest-base-HP tank | 1 |
| Earth | Ironroot Warriors | Durable melee bruisers | 2 |
| Earth | Runestone Marksmen | Heavy ranged hits | 2 |
| Earth | Runewood Trebuchet | Slow, long-range cluster splash | 1 |

Wildfire gives each Fire unit one first-hit, non-stacking Burn: 3 damage/s for
3s. Existing Burn is neither stacked nor refreshed; missed arrows do not consume
first successful hit eligibility. Tidal Recovery triggers once per Water unit
when damage first leaves it below 50% HP, healing 12% max HP over 3s. The threshold
is recorded before same-tick lifesteal can raise HP again. Earthen Guard grants
every deployed Earth unit an initial 10%-max-HP shield. Mixed warbands get no bond.

Coral Wardens shield themselves and allies within 58px at battle start for 8%
of the recipient's max HP, expiring after 8s. Multiple shields use the strongest
value and never sum. Shields absorb reduced incoming damage before HP.
Tidecaller Slow reduces movement by 25% for 2s, can refresh and never adds
strength. Waveblade lifesteal heals 15% of actual HP damage dealt, excluding
shields, Burn and overkill, capped at 2% actual max HP per one-second window.
Buffered simultaneous hit credit is prorated fairly among attackers.

## Drafting and persistence

Three unique offers always contain a normal card. Other slots use editable
70/15/15 summon/reinforce/promote category weights after filtering unavailable
categories. The mandatory normal slot makes overall frequencies differ from
those weights. Each side draws only from its own equipped cards.

Two normal summons unlock Reinforcements and Promotions for that army.
Reinforcement doubles count without changing Rank; confirm before spending.
There are two uses per army, Rank caps at 3, and unit caps are 24 per army and
72 per side. Exceeding a cap is rejected, never silently clamped. Promotion affects
current and future units. Counts, Ranks and action history survive rounds;
combat HP, projectiles, shields, Burn, Slow and spell/recovery timers reset.

## Deterministic combat and fair AI

Combat advances at 30 fixed ticks/s independently of rendering and uses no RNG.
The match owns the sole draft RNG. Both armies read start-of-tick positions,
move and buffer attacks before simultaneous damage resolution. Stable unit IDs
break equal targeting distances. Movement-snapshot siege cluster counts are
cached once per target/radius to avoid repeating density scans for every launcher.

Tanks spawn ahead of melee, ranged/mages behind, siege furthest back, and assassins
on flanks. Flankers prioritize ranged, mage and siege before melee/tanks. Other
units choose nearest enemies; siege prefers the densest reachable enemy cluster.
Arrows and tide projectiles travel in the simulation. Siege stones aim at a fixed
landing location, so moving targets can leave the splash area. No elemental
rock-paper-scissors damage multipliers are used.

At 45s compare remaining HP fractions, then survivors. Exact ties enter escalating
sudden death. Simultaneous dispersal yields a visible draw, no Heart loss and no
comeback point. There is no random winner or unit-ID initiative advantage.

The AI uses identical legal offers, costs, spells and caps. It scores frontline
need, army size, upgrade value, enemy backline concentration and previous loss.
Repeated assassin purchases have diminishing value to preserve a main army.
Each side's opponent snapshot is frozen at Command Phase start, excluding current
player actions. F3 shows decisions and scores.

## Presentation and saves

Parchment and a sunny woodland frame original six-frame 32×32 sprites. Fire uses
honey/coral/orange, Water turquoise/seafoam/pearl/lavender, Earth moss/ochre/stone.
Health bars, shield lines, Slow marks and healing crosses expose combat effects.
Reduced effects removes bounces, flashes and particles. All values live in custom
Resources; portraits and sprites remain replaceable placeholders.

Version 2 settings preserve volume, display speed, effects, Commander, warband
and rival. Version 0/1 saves migrate in place using the existing file name;
invalid loadouts safely fall back to the chosen Commander's realm. Browser saves
use Godot's local storage; active matches are not persisted.
