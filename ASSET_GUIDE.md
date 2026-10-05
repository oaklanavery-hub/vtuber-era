# Asset provenance and replacement guide

## Original project assets

`tools/generate_assets.py` builds original, rectangular-grid SVG pixel art and
original PCM audio using the Python standard library. It does not fetch art,
sample recordings, models, fonts or other source media.

| Asset | Format / location | Source |
|---|---|---|
| Twelve chibi unit atlases | `assets/units/*.svg`, 192×32; six 32×32 frames | Original code-native pixel designs |
| Three Commander portraits | `assets/portraits/*_commander.svg`, 96×96 | Original pixel designs |
| Fire crest / app icon | `assets/icon.svg`, 32×32 | Original pixel design |
| Woodland, cottages, stream, lanterns, moss ruins, flowers, bunting | `scenes/world.gd` | Original Node2D drawing |
| Parchment, rounded borders, wax seals and runes | `ui/style.gd`, `ui/wax_seal.gd`, `ui/command_runes.gd` | Original Godot drawing and styling |
| Festival loop and six cues | `assets/audio/*.wav`, mono 22,050 Hz 16-bit PCM | Original synthesized score and plucked harmonics |
| Hit, projectile, healing, shield, Slow and defeat-spark visuals | `scenes/battlefield.gd` | Original Godot drawing |

The art is placeholder work, not a final commissioned VTuber identity. No
copyrighted game assets or specific character designs were copied. The project
owner has not approved an open-source licence for original assets or code.

Fire uses honey/coral/orange; Water turquoise, cornflower, seafoam, pearl and
lavender; Earth moss, sage, chestnut, ochre, stone grey and bronze. Tide staffs,
coral shields, runed hammers and a wooden trebuchet distinguish new silhouettes.

Rebuild the supplied originals with `python3 tools/generate_assets.py`.
This deliberately overwrites generated sprite/audio files and their initial
army Resources; do not run it over tuned Resources without preserving changes.

## Third-party components

| Component | Upstream | Licence / included notices |
|---|---|---|
| Godot Engine 4.5 and Web templates | [Official 4.5 release](https://github.com/godotengine/godot-builds/releases/tag/4.5-stable) | MIT engine licence, plus its dependency notices in `assets/licenses/Godot-LICENSE.txt` and `Godot-COPYRIGHT.txt` |
| DejaVu Sans (`body.ttf`) | [DejaVu fonts](https://dejavu-fonts.github.io/) | Bitstream Vera font licence with DejaVu changes in the public domain; complete packaged notices in `assets/fonts/LICENSE-DejaVu.txt` |
| DejaVu Serif Bold (`storybook.ttf`) | [DejaVu fonts](https://dejavu-fonts.github.io/) | Same font licence and notice file |

Fonts were copied from the environment's `fonts-dejavu-core` package. The included
notice also describes packaging files; those files are not game code. The
original typeface names remain documented; only local file names were changed.
Godot engine and templates were verified against the official SHA-512 release
checksums. Downloaded engine binaries and templates are excluded from source.

`tools/prepare_web.py` adds a readable `THIRD_PARTY_NOTICES.txt` beside the Web
entry point. Licence texts are also included in the exported resource pack.

## Replacing placeholders

Keep six 32×32 frames per horizontal unit atlas or update the battlefield frame
region code. Assign a replacement texture through `ArmyCardData.sprite`; assign
portrait artwork through `CommanderData.portrait`. Keep texture filtering set
to nearest. Audio replacements use the same cue IDs through the Sound autoload.

Store the source, permission and licence of every replacement here. Use only
original or properly licensed assets. Final VTuber portraits require the
relevant owner's approval. Avoid gore, realistic warfare, modern clothing,
firearms, machinery, neon or science-fiction armour.
