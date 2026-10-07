# VTuber Era — Phase 2 game design

The Convergence Festival is a friendly fantasy contest. Units disperse into
sparks and return next round; Commanders remain in the UI.

## Match and loadout

Choose any of three Commanders, then exactly four unique army cards from fifteen.
Pure realm presets and mixed warbands are legal. A four-card Realm Bond depends
only on the cards' shared set, independently of the Commander. The rival selector
provides a Mirror loadout or a pure Fire, Water or Earth AI.

Both sides begin with four Hearts. Each Command Phase grants three points plus
one comeback point to the previous loser. Each action or prepared spell costs
one point; unused points disappear at battle start. Automatic combat permits no
manual commands, movement or targeting. Rematch resets all match state and seed.

## Commanders

| Commander | Passive | One-point active skill |
|---|---|---|
| Fire | All allies +5% attack damage; Fire allies +5% attack speed | Meteor Rain: 6 opening meteors, each 30 damage in a 34px area |
| Water | All allies +5% max HP; Water allies +10% healing and shields | Frozen Field: all enemies move 15% slower and have 8% less defence for the round |
| Earth | All allies take 5% less damage; Earth allies +5% max HP | Uproot: 3 solid earth walls on the enemy field for the round |

Preparation is once per round, preserves all three offers and applies only to
the next battle. The info icon on commander selection and beside Prepare explains
each active skill. Fire's two-second opening holds voluntary army movement and
the battle clock until all six impacts finish; death blasts can push units physically. Six zones distribute impacts across the
enemy field; each aims at a starting enemy in that zone when one exists. Damage
uses shields and defence, and triggers normal death passives. Opposing meteors
landing together resolve simultaneously, without unit-source attack bonuses,
Wildfire or lifesteal. Meteors fall from above and ignore earth walls.

Frozen Field covers the full battlefield and affects enemies wherever they
move, including revived Ninjas and newborn Slimes. Movement uses the strongest
active slow. Defence starts at 1.0; ice reduces it to 0.92. Incoming damage is
divided by that modifier (about 8.7% more damage), after commander reduction and
before shields. Earth passive under enemy ice therefore takes 0.95/0.92 damage.
Water affinity belongs to the recipient of healing/shields. Healing never
resurrects and never exceeds max HP.

Uproot places three staggered 12×72px walls between spawn columns, with clear
routes around every end. Both teams' units and projectiles collide with walls;
the walls are permanent for the round and cannot be destroyed. Melee and ranged
attacks require unobstructed line of sight. An obscured ranged unit selects an
available visible target or moves around the wall to shoot. A visibility graph
around expanded corners supplies routes, with the swept body solver handling
crowds and knockback. Projectiles check the entire step against walls before
damage or splash; split arrows also require visible targets. Projectile splash
cannot damage through a wall. Walls and ice remain visible with reduced effects.
All skill terrain, opening state and enemy modifiers clear when the round ends.

## Armies and bonds

| Realm | Army | Role | Group |
|---|---|---|---:|
| Fire | Fire Lizards | Ranged | 3 |
| Fire | Fire Imps | Melee | 3 |
| Fire | Magma Golems | Tank | 1 |
| Fire | Red Ninjas | Assassin | 1 |
| Fire | Candle | Mage: fire splash and burning ground | 2 |
| Water | Water Wizards | Mage: splash and non-stacking movement Slow | 2 |
| Water | Ice Golems | Tank: nearby initial shields | 1 |
| Water | Water Slimes | Melee: capped lifesteal | 3 |
| Water | Snowmen | Long-range ranged | 3 |
| Water | Penguin | Mage: water splash and stacking healing puddles | 2 |
| Earth | Trees | Highest-base-HP tank | 1 |
| Earth | Armadillos | Durable melee bruisers | 2 |
| Earth | Wood Archers | Heavy ranged hits | 2 |
| Earth | Wooden Siege | Slow, long-range cluster splash | 1 |
| Earth | Pitcher Plant | Melee: backline root pull and bite | 2 |

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
projectile; Fire Imps explode on death with radial pushback and a two-second Burn. Magma Golems carry moving 48px fire rings,
dealing 3 HP/s to enemies inside. Red Ninjas charge for 2s, then teleport behind
enemy lines once per battle. They still resurrect once with 30% max HP. Water Wizards push enemies back with every splash spell. Ice Golems
carry a moving 48px ice aura that slows enemy attack and movement speed by 15%. Water Slimes split
once into two smaller children at 50% damage and HP each; children do not split.
Snowmen throw their heads on death for a small area blast. Trees heal nearby
living allies, including themselves, for 5% max HP every 2s. Armadillos bounce
every 3s and reduce nearby enemies' attack speed by 20% for 2s. Wood Archers fire
three arrows sharing one attack's damage every 5s when in range. Wooden Siege
stones hit a huge 64px area. Exact initial parameters are documented in
`BALANCE.md` and each card's description.

Candle spits full-damage fire into a 24px AOE, leaving ground that burns for 3s.
Penguin splashes a 30px AOE, leaving a 3s puddle that heals living allies for 5%
of each recipient's max HP every second. Puddles stack independently; ground
fire and rings each use their strongest overlap. These pools persist after
their caster dies and clear at round end. Pitcher Plant prefers visible backline
prey within 154px, extends roots for 0.5s, then pulls with swept collision and
bites only after reaching melee range. Obstacles stop the pull; failed pulls
release after 2s. All three armies summon two units; their individual caps are
four Candles, four Penguins and six Pitcher Plants.

Each realm's compendium displays all five cards together. Existing four-card
presets and saves remain compatible; players can replace any slot with the new
realm army or build a mixed warband. Any four unique armies from one realm still
activate that Realm Bond.

## Drafting and persistence

Commander selection fronts contain only their portrait and the top-left info
button. The details view contains their name, identity, passive bonuses and paid
active skill. The builder displays a single 5×3 grid of army portrait cards;
click to select or remove an army. Each face shows its character name, elemental
info button at top left, role symbol beside its name, and a numbered spawn-count
circle at top right. All detailed army effects and limits stay in the info view.
Compendium and draft cards share these symbols; draft action and point cost
remain visible so a player can tell Summon, Reinforce and Promote apart.

Army appearance scales are 1× for Red Ninja, Water Wizard, Snowman, Wood Archer,
Pitcher Plant and full Slime; 1.5× for Magma Golem, Ice Golem, Tree and Wooden
Siege; 0.6× for split Slime, Armadillo, Penguin, Candle, Fire Imp and Fire Lizard.
Preview and battle rendering use the same scales and feet anchor. Health bars
follow sprite height. Their solid 7.2px movement footprint is independent of art.

Wall navigation uses visibility-graph routes, with a body-width passing lane
around corners and complete-route costs for stationary firing allies. Exact
edge contact permits sliding and moving away, using a float32-sized tolerance;
movement into a wall or body remains blocked. Projectiles keep strict wall and
line-of-sight checks. Crowded armies can reposition rather than queuing forever
behind a firing ally at a corner.

Three unique offers contain a legal normal summon whenever one is available.
Other slots use editable 50/15/15/20 summon/reinforce/promote/power category
weights after filtering unavailable actions. Capped summons are removed. When
all unit counts are full, the first slot becomes a power card; at maximum counts
and ranks, all three choices are distinct power cards. The guaranteed first slot
makes overall frequencies differ from the weights. Army cards draw from that
side's four-card warband; the power pool is shared across all commanders.

After summoning at least one army, four power cards can appear: **+15% HP**,
**+10% Damage**, **+12% DEF**, and **+10% Attack Speed**. Each costs one Command
Point and upgrades all allied armies, including future summons, for the rest of
the match. Repeated cards add percentages: two HP cards give +30%, two damage
cards +20%, and so on. Their multiplier applies after rank and commander bonuses.
Defence divides incoming damage by `1 + 0.12 × cards`, so it never grants complete
immunity; Frozen Field still reduces the resulting defence by 8%. Damage powers
also scale unit explosions, fire-ring DPS, Candle ground fire and burns, while
commander meteor damage remains the commander's fixed skill value. Speed powers
shorten attack cycles without changing movement or timed passive intervals.
Slime children and revived Ninjas inherit the upgraded stats. Power bonuses
persist through wins and losses and reset on Rematch. They consume no army slots
and do not increase unit caps. Their clean fronts show an icon, bonus and cost;
the top-left info control explains duration, stacking and current/next bonus.

Two normal summons unlock Reinforcements and Promotions for that army.
Reinforcement adds up to the current count without changing Rank; confirm the
exact final count before spending. Both normal summons and reinforcements fill
remaining slots at the cap. Maximum counts per army type are ranged 8, melee 10,
tanks 3, mages 5, assassins 3 and siege 4; mixed cards sharing a role each have
that limit. Candle and Penguin override their mage cap to 4, and Pitcher Plant
overrides its melee cap to 6. The 72-per-side ceiling remains an additional safety guard. There
are up to two reinforcements per army and Rank caps at 3. A capped army cannot
spend a point on more units, but can still promote. Promotion affects
current and future units. Counts, Ranks, power stacks and action history survive rounds;
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
on flanks. Ninjas hold position during a visible two-second charge, then teleport
to free positions beyond the enemy rear line. They can blink across terrain,
but destinations must fit inside the arena and avoid all units and walls.
Simultaneous Ninjas reserve distinct landing lanes; at an arena edge they land
in an adjacent free lane. The teleport has no movement interpolation across the
field, so it never clips through other units visually. After landing, Ninjas
prefer reachable backline enemies and fight blocking defenders before chasing
distant targets. Resurrection preserves the spent teleport; death during the
charge retains the original deadline. Their 30%-HP revival resumes pursuit with
the commander-adjusted attack cycle. Other units prefer reachable visible enemies;
siege prefers the densest reachable enemy cluster with clear line of sight.
Arrows and tide projectiles travel in the simulation. Siege stones aim at a fixed
landing location, so moving targets can leave the splash area. No elemental
rock-paper-scissors damage multipliers are used.

Preview and combat share a unique-slot allocator, including mixed armies with
duplicate roles. Each side has 99 potential 24px-spaced slots for its 72-unit
cap. Alive units on both teams keep solid 7.2×7.2 bodies throughout combat,
70% smaller in each dimension than the previous footprint. Spawn spacing and
spatial bucket size remain 24px, independently of collision size.
Swept movement reserves the whole tick's path, preventing both simulation
penetration and interpolated body crossing. Sprites are painted in depth order
and may partially overlap above their feet, leaving rear creatures visible.
Dead units do not block movement.
Pushback uses the same swept collision solver, including blockers and arena
edges and solid earth walls. It cannot detour or tunnel through another body.
Slime births search for free positions reachable from the parent, checked against
walls and other units' whole interpolation paths; if no
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
gold mark after the resurrection is spent. A compact score header opens a 600×280 arena within
the same 640×360 logical resolution. Nine spawn rows retain 24px spacing;
movement can use the full expanded arena. Ninja charge bars, pixel smoke and
arrival rings show the teleport timing; ice auras mark their true radius. Fire uses
honey/coral/orange, Water turquoise/seafoam/pearl/lavender, Earth moss/ochre/stone.
Health bars, shield lines, Slow marks and healing crosses expose combat effects.
Reduced effects removes bounces, flashes and particles. All values live in custom
Resources; portraits and sprites remain replaceable placeholders.

All interface lettering uses Idrees Hassan's proportional Minecraft-inspired
font with antialiasing and subpixel positioning disabled, and a 10px logical minimum
(20px in a 1280×720 window). DejaVu is an explicit fallback for symbols.
The 640×360 viewport uses nearest filtering and integer scaling at 2× or larger.
Smaller windows use fit scaling to avoid a tiny 1× interface. Stepped panel
corners, pixel rings and original environment details share its logical grid. Labels measure their text, wrap descriptions where room
permits, and reduce the font size to fit their assigned rectangles. Buttons
account for their inner margins. The score header keeps persistent rosters in
its tooltips. Hearts are original pixel icons rather than fallback font glyphs.
Every Command Phase opens a centered round picker containing the three offers,
Command Points, spell preparation and Battle. Playing a card spends a point and
refreshes the offers there; reinforcement still requires confirmation. Battle
closes the picker and removes all draft controls. The clean card faces show an
army portrait, name, action and short benefit. A separate top-left info button
opens full base stats and army effects without spending points or rerolling.
The same card component is used by the compendium. Its details popup closes back
to the same realm tab; during drafting it returns to the same offers and points.
Info remains available on disabled/capped offers. Escape/Enter closes effects,
and keyboard focus returns to the original icon.
Flame walls, ice auras and Ninja charge indicators stay visible in Reduced Effects mode because they
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
