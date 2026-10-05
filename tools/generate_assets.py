"""Rebuild original grid-based SVG sprites and original PCM festival audio.

Standard library only. SVGs are editable, code-native pixel art: no external
images, models, copyrighted characters or generated-image dependencies.
"""
from pathlib import Path
import math
import struct
import wave
from army_sprites import army_figure

ROOT = Path(__file__).resolve().parents[1]
OUTLINE = '#51372f'
CREAM = '#f9e4b5'
HONEY = '#e8ba61'
ORANGE = '#d57346'
CORAL = '#efa278'
BRICK = '#a34b39'
MOSS = '#7d9661'


def figure(role, frame=0, realm='fire'):
    shapes = []
    bob = [0, -1, 0, 1, 0, -1][frame]
    palettes = {
        'fire': (OUTLINE, CREAM, HONEY, ORANGE, CORAL, BRICK, MOSS),
        'water': ('#354b69', '#eef3de', '#a9d4ce', '#659fbb', '#c3b6d9', '#47788e', '#7cbcb5'),
        'earth': ('#41483d', '#e7dbc3', '#c5a15e', '#7d9661', '#cbb18d', '#69725b', '#a7b686'),
    }
    outline, cream, honey, orange, coral, brick, moss = palettes[realm]

    def rect(x, y, w, h, color, static=False):
        # Keep the original Fire design intact while applying each realm's palette.
        color = dict(zip((OUTLINE, CREAM, HONEY, ORANGE, CORAL, BRICK, MOSS),
                         (outline, cream, honey, orange, coral, brick, moss))).get(color, color)
        shapes.append(f'<rect x="{x}" y="{y if static else y+bob}" width="{w}" height="{h}" fill="{color}"/>')

    step = 1 if frame in (1, 2) else -1 if frame in (4, 5) else 0
    if role == 'siege':
        # A tiny runed trebuchet, rather than a recolored humanoid.
        rect(3, 25, 26, 3, OUTLINE, True)
        for x in (5, 23):
            rect(x, 25, 5, 5, OUTLINE, True)
            rect(x+1, 26, 3, 3, HONEY, True)
        rect(8, 13, 3, 13, OUTLINE)
        rect(21, 13, 3, 13, OUTLINE)
        rect(11, 15, 10, 3, HONEY)
        rect(12, 5+step, 3, 16, OUTLINE)
        rect(14, 5+step, 8, 3, HONEY)
        rect(20, 7+step, 7, 5, OUTLINE)
        rect(21, 8+step, 5, 3, BRICK)
        rect(9, 19, 14, 5, BRICK)
        rect(14, 19, 4, 4, MOSS)
        rect(15, 20, 2, 2, CREAM)
        rect(5, 8-step, 6, 5, OUTLINE)
        rect(6, 9-step, 4, 3, MOSS)
        return ''.join(shapes)
    rect(10, 25+step, 5, 4, OUTLINE, True)
    rect(18, 25-step, 5, 4, OUTLINE, True)
    rect(8, 16, 16, 11, OUTLINE)
    rect(7, 18, 18, 6, OUTLINE)
    rect(10, 17, 12, 8, BRICK)
    rect(11, 17, 10, 5, ORANGE)
    rect(10, 24, 12, 2, HONEY)
    rect(14, 20, 5, 3, CREAM)
    rect(7, 18, 3, 5, CORAL)
    rect(22, 18, 3, 5, CORAL)
    # Rounded, stepped chibi head with warm outlines and expressive eyes.
    rect(10, 4, 12, 2, OUTLINE)
    rect(8, 6, 16, 9, OUTLINE)
    rect(10, 15, 12, 2, OUTLINE)
    rect(10, 7, 12, 8, CORAL)
    rect(11, 8, 10, 6, CREAM)
    rect(12, 10, 2, 3, OUTLINE)
    rect(19, 10, 2, 3, OUTLINE)
    rect(12, 10, 1, 1, '#fff5d7')
    rect(19, 10, 1, 1, '#fff5d7')
    rect(15, 14, 3, 1, BRICK)
    rect(10, 13, 2, 1, CORAL)
    rect(21, 13, 2, 1, CORAL)

    if role == 'mage':
        rect(11, 1, 8, 3, OUTLINE)
        rect(9, 4, 13, 3, OUTLINE)
        rect(6, 7, 20, 2, OUTLINE)
        rect(12, 2, 6, 3, ORANGE)
        rect(10, 5, 11, 3, ORANGE)
        rect(8, 8, 15, 1, HONEY)
        rect(9, 22, 15, 5, BRICK)
        rect(11, 23, 11, 3, ORANGE)
        rect(27, 10, 2, 18, OUTLINE)
        rect(25, 7, 6, 6, OUTLINE)
        rect(26, 8, 4, 4, MOSS)
        rect(27, 9, 2, 2, CREAM)
    elif role == 'ranged':
        rect(7, 5, 17, 3, OUTLINE)
        rect(10, 3, 12, 3, OUTLINE)
        rect(11, 4, 10, 3, MOSS)
        rect(8, 6, 16, 2, MOSS)
        rect(19, 1, 2, 5, HONEY)
        rect(21, 1, 2, 2, CREAM)
        for x, y in [(27, 14), (29, 16), (30, 19), (29, 22), (27, 24)]:
            rect(x, y, 2, 3, OUTLINE)
        rect(28, 16, 1, 8, HONEY)
        rect(26, 16, 1, 8, CREAM)
        rect(24, 19, 7, 1, HONEY)
        if realm == 'earth':
            rect(23, 17, 8, 2, OUTLINE)
            rect(24, 18, 6, 1, HONEY)
            rect(26, 19, 2, 6, BRICK)
        elif realm == 'water':
            rect(14, 3, 5, 2, CREAM)
    elif role == 'melee':
        rect(9, 5, 14, 3, BRICK)
        rect(10, 3, 12, 3, ORANGE)
        rect(8, 8, 3, 2, BRICK)
        rect(19, 6, 4, 4, BRICK)
        rect(26, 9, 3, 14, OUTLINE)
        rect(27, 10, 1, 10, CREAM)
        rect(24, 22, 7, 2, HONEY)
        rect(27, 24, 2, 4, OUTLINE)
        rect(6, 23, 6, 2, BRICK)
        if realm == 'earth':
            rect(24, 8, 7, 5, OUTLINE)
            rect(25, 9, 5, 3, HONEY)
            rect(12, 17, 8, 3, MOSS)
        elif realm == 'water':
            rect(12, 4, 8, 2, CREAM)
            rect(26, 13, 2, 2, MOSS)
    elif role == 'tank':
        rect(7, 4, 18, 5, OUTLINE)
        rect(9, 5, 14, 3, HONEY)
        rect(7, 8, 3, 8, OUTLINE)
        rect(22, 8, 3, 8, OUTLINE)
        rect(8, 9, 2, 5, HONEY)
        rect(22, 9, 2, 5, HONEY)
        rect(14, 2, 4, 5, BRICK)
        rect(5, 17, 8, 10, OUTLINE)
        rect(6, 18, 6, 7, HONEY)
        rect(7, 19, 4, 5, ORANGE)
        rect(8, 20, 2, 3, CREAM)
        rect(24, 17, 3, 9, OUTLINE)
        rect(25, 18, 2, 3, HONEY)
        if realm == 'water':
            rect(4, 17, 10, 3, MOSS)
            rect(5, 16, 2, 2, CORAL)
            rect(10, 15, 2, 3, CORAL)
        elif realm == 'earth':
            rect(5, 17, 9, 11, OUTLINE)
            rect(6, 18, 7, 9, BRICK)
            rect(8, 20, 3, 5, MOSS)
            rect(9, 21, 1, 3, CREAM)
    else:
        rect(9, 3, 14, 3, OUTLINE)
        rect(8, 6, 3, 10, BRICK)
        rect(22, 6, 3, 10, BRICK)
        rect(10, 4, 12, 4, BRICK)
        rect(11, 13, 11, 3, BRICK)
        rect(9, 16, 14, 4, ORANGE)
        rect(21, 18, 5, 3, BRICK)
        rect(24, 20, 4, 2, BRICK)
        rect(5, 18, 2, 9, OUTLINE)
        rect(6, 18, 1, 6, CREAM)
        rect(27, 18, 2, 9, OUTLINE)
        rect(27, 18, 1, 6, CREAM)
    return ''.join(shapes)


def svg(w, h, inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" shape-rendering="crispEdges">{inner}</svg>\n'


def art():
    names = [('fire_archer', 'Fire Lizards', 'Fire Lizard', 'ranged', 3, 34, 9, 1.0, 34, 138,
              'Long-tailed fire lizards with quick ranged attacks. Protect them with a frontline.'),
             ('fire_melee', 'Fire Imps', 'Fire Imp', 'melee', 3, 64, 8, 1.05, 39, 20,
              'Horned, clawed imps who rush into close combat.'),
             ('fire_tank', 'Magma Golems', 'Magma Golem', 'tank', 1, 220, 7, .65, 27, 23,
              'Heavy basalt golems with molten cores. Absorb attacks and protect allies.'),
             ('fire_assassin', 'Red Ninjas', 'Red Ninja', 'assassin', 1, 60, 13, 1.55, 62, 19,
              'Fast flankers who hunt archers, mages and siege behind the frontline.'),
             ('water_mage', 'Water Wizards', 'Water Wizard', 'mage', 2, 34, 6, .60, 30, 146,
              'Splash spells slow enemy movement by 25% for 2s. Slow never stacks.'),
             ('water_tank', 'Ice Golems', 'Ice Golem', 'tank', 1, 180, 6, .55, 24, 23,
              'At battle start, shield nearby allies for 8% of their max HP for 8s.'),
             ('water_melee', 'Water Slimes', 'Water Slime', 'melee', 3, 52, 6, .90, 35, 21,
              'Heal for 15% of HP damage dealt, capped at 2% max HP per second.'),
             ('water_ranged', 'Snowmen', 'Snowman', 'ranged', 3, 34, 7, 1.0, 32, 154,
              'Snowmen with long-range snowball attacks. Keep them safe behind allies.'),
             ('earth_tank', 'Trees', 'Tree', 'tank', 1, 250, 6, .55, 22, 25,
              'Walking trees with tough bark and branch arms. Hold the frontline.'),
             ('earth_melee', 'Armadillos', 'Armadillo', 'melee', 2, 80, 10, .75, 32, 23,
              'Durable, shell-plated armadillos who strike hard in close combat.'),
             ('earth_ranged', 'Wood Archers', 'Wood Archer', 'ranged', 2, 44, 13, .65, 28, 150,
              'Steady marksmen with slow, heavy ranged attacks.'),
             ('earth_siege', 'Wooden Siege', 'Wooden Siege', 'siege', 1, 75, 20, .20, 17, 220,
              'Slow, long-range stones hit enemy clusters. Small group size; protect it.')]
    extras = {
        'water_mage': dict(projectile_speed=220.0, splash_radius=22.0, splash_falloff=.50, slow_fraction=.25, slow_duration=2.0),
        'water_tank': dict(ally_shield_fraction=.08, ally_shield_radius=58.0, ally_shield_duration=8.0),
        'water_melee': dict(lifesteal_fraction=.15, lifesteal_cap_per_second=.02),
        'water_ranged': dict(projectile_speed=280.0),
        'earth_ranged': dict(projectile_speed=240.0),
        'earth_siege': dict(projectile_speed=140.0, splash_radius=34.0),
    }
    for ident, name, short, role, group, hp, damage, aps, speed, reach, description in names:
        realm = ident.split('_')[0]
        content = ''.join(f'<g transform="translate({frame*32} 0)">{army_figure(ident, frame)}</g>' for frame in range(6))
        (ROOT / f'assets/units/{ident}.svg').write_text(svg(192, 32, content))
        resource = f'''[gd_resource type="Resource" script_class="ArmyCardData" load_steps=5 format=3]
[ext_resource type="Script" path="res://data/types/army_card_data.gd" id="1"]
[ext_resource type="Script" path="res://data/types/unit_stats.gd" id="2"]
[ext_resource type="Texture2D" path="res://assets/units/{ident}.svg" id="3"]
[sub_resource type="Resource" id="Stats"]
script = ExtResource("2")
max_hp = {float(hp)}
damage = {float(damage)}
attacks_per_second = {aps}
move_speed = {float(speed)}
attack_range = {float(reach)}
{''.join(f'{key} = {value}\n' for key, value in extras.get(ident, {}).items()).rstrip()}
[resource]
script = ExtResource("1")
id = "{ident}"
display_name = "{name}"
short_name = "{short}"
set_id = "{realm}"
role = "{role}"
group_size = {group}
description = "{description}"
stats = SubResource("Stats")
sprite = ExtResource("3")
'''
        (ROOT / f'data/armies/{ident}.tres').write_text(resource)
    portrait = '<rect width="32" height="32" fill="#e8ba61"/><rect x="2" y="2" width="28" height="28" fill="#f9e4b5"/>'
    portrait += '<rect x="3" y="18" width="26" height="12" fill="#e9ad75"/>'
    portrait += figure('melee')
    portrait += '<rect x="14" y="0" width="4" height="3" fill="#d57346"/><rect x="15" y="0" width="2" height="2" fill="#e8ba61"/>'
    (ROOT / 'assets/portraits/fire_commander.svg').write_text(svg(96, 96, f'<g transform="scale(3)">{portrait}</g>'))
    for realm, role, border, background in [('water', 'mage', '#659fbb', '#eef3de'),
                                             ('earth', 'tank', '#7d9661', '#e7dbc3')]:
        portrait = f'<rect width="32" height="32" fill="{border}"/><rect x="2" y="2" width="28" height="28" fill="{background}"/>'
        portrait += figure(role, realm=realm)
        (ROOT / f'assets/portraits/{realm}_commander.svg').write_text(svg(96, 96, f'<g transform="scale(3)">{portrait}</g>'))
    flame = '<rect x="4" y="4" width="24" height="24" fill="#51372f"/><rect x="6" y="6" width="20" height="20" fill="#e8ba61"/><path d="M10 24V16H13V11H16V7H18V13H21V16H24V24Z" fill="#d57346"/><rect x="15" y="18" width="5" height="6" fill="#f9e4b5"/>'
    (ROOT / 'assets/icon.svg').write_text(svg(32, 32, flame))


RATE = 22050


def note(buffer, start, duration, freq, gain=.15):
    begin = int(start * RATE)
    end = min(len(buffer), int((start + duration) * RATE))
    for i in range(begin, end):
        t = (i-begin)/RATE
        env = min(1.0, t/.015) * math.exp(-t*4.5/duration) * min(1.0, (end-i)/(RATE*.06))
        sample = math.sin(2*math.pi*freq*t) + .22*math.sin(2*math.pi*freq*2*t) + .08*math.sin(2*math.pi*freq*3*t)
        buffer[i] += sample * env * gain


def wav(name, data):
    with wave.open(str(ROOT / f'assets/audio/{name}.wav'), 'wb') as f:
        f.setparams((1, 2, RATE, len(data), 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x))*28000)) for x in data))


def audio():
    melody = [62, 66, 69, 71, 69, 66, 64, 62, 64, 66, 69, 74, 71, 69, 66, 64,
              62, 66, 69, 71, 74, 71, 69, 66, 64, 66, 69, 66, 64, 62, 64, 62]
    data = [0.] * (RATE * 16)
    for i, midi in enumerate(melody):
        note(data, i*.5, .7, 440*2**((midi-69)/12), .15)
        if i % 4 == 0:
            note(data, i*.5, 1.8, 440*2**(((50 if i%8==0 else 57)-69)/12), .1)
    wav('festival', data)
    cues = {'click': [76], 'summon': [62, 66, 69], 'spell': [69, 74, 78, 81],
            'battle': [50, 57, 62], 'victory': [62, 66, 69, 74], 'defeat': [69, 66, 62]}
    for name, phrase in cues.items():
        data = [0.] * int(RATE * (len(phrase)*.12+.65))
        for i, midi in enumerate(phrase):
            note(data, i*.12, .55, 440*2**((midi-69)/12), .24)
        wav(name, data)


if __name__ == '__main__':
    art()
    audio()
    print('Twelve original six-frame SVG atlases, three portraits, icon and seven PCM WAV files rebuilt.')
