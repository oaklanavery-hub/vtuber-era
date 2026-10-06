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
| Fire | Fire Lizards | Ranged | 3 |
| Fire | Fire Imps | Melee | 3 |
| Fire | Magma Golems | Tank | 1 |
| Fire | Red Ninjas | Assassin | 1 |
| Water | Water Wizards | Mage: splash and non-stacking movement Slow | 2 |
| Water | Ice Golems | Tank: nearby initial shields | 1 |
| Water | Water Slimes | Melee: capped lifesteal | 3 |
| Water | Snowmen | Long-range ranged | 3 |
| Earth | Trees | Highest-base-HP tank | 1 |
| Earth | Armadillos | Durable melee bruisers | 2 |
| Earth | Wood Archers | Heavy ranged hits | 2 |
| Earth | Wooden Siege | Slow, long-range cluster splash | 1 |

Wildfire gives each Fire unit one first-hit, non-stacking Burn: 3 damage/s for
3s. Existing Burn is neither stacked nor refreshed; missed arrows do not consume
first successful hit eligibility. Tidal Recovery triggers once per Water unit
when damage first leaves it below 50% HP, healing 12% max HP over 3s. The threshold
is recorded before same-tick lifesteal can raise HP again. Earthen Guard grants
every deployed Earth unit an initial 10%-max-HP shield. Mixed warbands get no bond.

Ice Golems shield themselves and allies within 58px at battle start for 8%
of the recipient's max HP, expiring after 8s. Multiple shields use the strongest
value and never sum. Shields absorb reduced incoming damage before HP.
Water Wizard Slow reduces movement by 25% for 2s, can refresh and never adds
strength. Water Slime lifesteal heals 15% of actual HP damage dealt, excluding
shields, Burn and overkill, capped at 2% actual max HP per one-second window.
Buffered simultaneous hit credit is prorated fairly among attackers.

Each army also has a Resource-backed passive. Fire Lizards splash with every
projectile; Fire Imps explode on death. Magma Golems raise flame walls every 5s,
burning enemies crossing them for 2s. Red Ninjas resurrect once per battle with
30% max HP. Water Wizards push enemies back with every splash spell. Ice Golems
leave paths applying a non-stacking 15% movement Slow for 3s. Water Slimes split
once into two smaller children at 50% damage and HP each; children do not split.
Snowmen throw their heads on death for a small area blast. Trees heal nearby
living allies, including themselves, for 5% max HP every 2s. Armadillos bounce
every 3s and reduce nearby enemies' attack speed by 20% for 2s. Wood Archers fire
three arrows sharing one attack's damage every 5s when in range. Wooden Siege
stones hit a huge 64px area. Exact initial parameters are documented in
`BALANCE.md` and each card's description.

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
Slime children exist only in combat; persistent roster counts stay unchanged.
Revival eligibility also resets in each new battle.

## Deterministic combat and fair AI

Combat advances at 30 fixed ticks/s independently of rendering and uses no RNG.
The match owns the sole draft RNG. Both armies read start-of-tick positions,
move and buffer attacks before simultaneous damage resolution. Stable unit IDs
break equal targeting distances. Movement-snapshot siege cluster counts are
cached once per target/radius to avoid repeating density scans for every launcher.

Tanks spawn ahead of melee, ranged/mages behind, siege furthest back, and assassins
on flanks. Ninjas use their actual spawn lane (independent of roster ID parity),
prefer backline enemies while approaching, and attack a reachable defender
before chasing a distant target. Contact, no remaining backline or a six-second
deadline ends the opening flank. Their 30%-HP resurrection resumes pursuit with
the commander-adjusted attack cycle. Other
units choose nearest enemies; siege prefers the densest reachable enemy cluster.
Arrows and tide projectiles travel in the simulation. Siege stones aim at a fixed
landing location, so moving targets can leave the splash area. No elemental
rock-paper-scissors damage multipliers are used.

Preview and combat share a unique-slot allocator, including mixed armies with
duplicate roles. Each side has 77 potential 24px-spaced slots for its 72-unit
cap. Alive units on both teams keep solid 7.2×7.2 bodies throughout combat,
70% smaller in each dimension than the previous footprint. Spawn spacing and
spatial bucket size remain 24px, independently of collision size.
Swept movement reserves the whole tick's path, preventing both simulation
penetration and interpolated body crossing. Sprites are painted in depth order
and may partially overlap above their feet, leaving rear creatures visible.
Dead units do not block movement.
Pushback uses the same swept collision solver, including blockers and arena
edges. It cannot detour or tunnel through another body. Slime births search for
free positions checked against other units' whole interpolation paths; if no
position is available, they wait. Stable IDs remain valid when children append.
Spatial buckets limit collision checks; deterministic rotating movement priority
avoids permanent first-unit/first-team lane priority.

Out-of-range units advance toward their selected target, testing side lanes and
backward detours when blocked. A stable escape-side bias prevents oscillation
against a wall. Crowded units wait if no safe lane is free; they never jump over
or pass through allies or enemies. Short-range melee attacks meet at solid body
edges (a 7.2px minimum contact distance), with any reach above 7.2 extending the
edge gap. Ranged attacks retain their Resource-defined centre distance. This
keeps short-range melee functional without changing any stored army stats.

At 45s compare remaining HP fractions, then survivors. Exact ties enter escalating
sudden death. Simultaneous dispersal yields a visible draw, no Heart loss and no
comeback point. There is no random winner or unit-ID attack initiative advantage.
Death explosions resolve in simultaneous waves, with each dead unit triggering
once. Ninjas revive after the waves, and Slime children spawn in free slots.
The last Snowman's head is allowed to land before declaring the round's winner.

The AI uses identical legal offers, costs, spells and caps. It scores frontline
need, army size, upgrade value, enemy backline concentration and previous loss.
Repeated assassin purchases have diminishing value to preserve a main army.
Each side's opponent snapshot is frozen at Command Phase start, excluding current
player actions. F3 shows decisions and scores.

## Presentation and saves

Parchment and a sunny woodland frame original eight-frame 32×32 creature sprites,
drawn at their native size in battle. Shared 32-color ramps, one-pixel outlines,
shaded material details and dedicated attack frames preserve each silhouette.
Ninja revival uses a distinct frame, a one-second pixel ring and a persistent
gold mark after the resurrection is spent. Compact cards and header open a 600×202 arena within
the same 640×360 logical resolution, up from 560×142. Fire uses
honey/coral/orange, Water turquoise/seafoam/pearl/lavender, Earth moss/ochre/stone.
Health bars, shield lines, Slow marks and healing crosses expose combat effects.
Reduced effects removes bounces, flashes and particles. All values live in custom
Resources; portraits and sprites remain replaceable placeholders.

All interface lettering uses lightly pixelated Pixelify Sans with grayscale
antialiasing, disabled subpixel positioning and a 10px logical minimum
(20px in a 1280×720 window). DejaVu is an explicit fallback for symbols.
The 640×360 viewport uses nearest filtering and integer scaling at 2× or larger.
Smaller windows use fit scaling to avoid a tiny 1× interface. Stepped panel
corners, pixel rings and original environment details share its logical grid. Labels measure their text, wrap descriptions where room
permits, and reduce the font size to fit their assigned rectangles. Buttons
account for their inner margins; compact rosters use ellipsis and full tooltips
when needed. Hearts are original pixel icons rather than fallback font glyphs.
Compendium cards show each passive directly, with full stats in their tooltip.
Flame walls and ice paths stay visible in Reduced Effects mode because they
affect gameplay. Cosmetic bounce motion never moves a unit's collision body.

Twelve original short combat cues cover melee, ninja slashes, arrows, snowballs,
fire breath, water magic, siege launches/impacts, shield hits, impacts, healing
and dispersal. Frame events are coalesced, each cue has a cooldown, and a quiet
six-voice pool plays at most three new cues per rendered frame. Music and menu
cues have separate players. The existing volume setting controls all audio.

Version 2 settings preserve volume, display speed, effects, Commander, warband
and rival. Version 0/1 saves migrate in place using the existing file name;
invalid loadouts safely fall back to the chosen Commander's realm. Browser saves
use Godot's local storage; active matches are not persisted.
