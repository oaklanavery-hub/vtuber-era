"""Finish a Godot Web export with deployment files and required notices."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
build = ROOT / 'build/web'
(build.parent / '.gdignore').touch()
for file in build.iterdir():
    if file.name.endswith('.import') or file.name.startswith('index.wasm-'):
        file.unlink()
for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
    file = build / name
    if not file.is_file() or file.stat().st_size == 0:
        raise SystemExit(f'Missing Web output: {name}')
(build / '.nojekyll').touch()
parts = ['VTuber Era third-party notices\n\nProject source and original assets have no open-source licence.\n']
for file in [ROOT/'assets/licenses/Godot-LICENSE.txt', ROOT/'assets/licenses/Godot-COPYRIGHT.txt', ROOT/'assets/fonts/LICENSE-DejaVu.txt']:
    parts.append(f'\n\n--- {file.name} ---\n\n{file.read_text()}')
(build / 'THIRD_PARTY_NOTICES.txt').write_text(''.join(parts))
html = (build / 'index.html').read_text()
if '"ensureCrossOriginIsolationHeaders":true' in html:
    raise SystemExit('Unexpected cross-origin isolation dependency')
print('Web files verified; .nojekyll and third-party notices added.')
