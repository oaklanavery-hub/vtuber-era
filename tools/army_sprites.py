"""Original 32x32 pixel creatures: six movement frames, attack, resurrection.

All shapes are rasterized onto one integer grid, then encoded as SVG pixel runs.
The battle renderer uses a 1:1 grid; palettes and top-left lighting are shared.
"""

FRAME_SIZE = 32
FRAME_COUNT = 8


class Pixels:
    def __init__(self):
        self.grid = [[None] * FRAME_SIZE for _ in range(FRAME_SIZE)]

    def dot(self, x, y, color):
        x, y = int(x), int(y)
        if 0 <= x < FRAME_SIZE and 0 <= y < FRAME_SIZE:
            self.grid[y][x] = color

    def rect(self, x, y, w, h, color):
        for row in range(int(y), int(y+h)):
            for column in range(int(x), int(x+w)):
                self.dot(column, row, color)

    def line(self, x0, y0, x1, y1, color):
        dx, dy = abs(x1-x0), -abs(y1-y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        error = dx+dy
        while True:
            self.dot(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            twice = 2*error
            if twice >= dy:
                error += dy
                x0 += sx
            if twice <= dx:
                error += dx
                y0 += sy

    def poly(self, points, color):
        # Test pixel centers: no vector edges, antialiasing or fractional texels.
        for y in range(FRAME_SIZE):
            for x in range(FRAME_SIZE):
                inside = False
                px, py = x+.5, y+.5
                for a, b in zip(points, points[1:]+points[:1]):
                    if (a[1] > py) != (b[1] > py) and px < (b[0]-a[0])*(py-a[1])/(b[1]-a[1])+a[0]:
                        inside = not inside
                if inside:
                    self.dot(x, y, color)

    def oval(self, x, y, w, h, color):
        for yy in range(y, y+h):
            for xx in range(x, x+w):
                if ((xx+.5-x-w/2)/(w/2))**2+((yy+.5-y-h/2)/(h/2))**2 <= 1:
                    self.dot(xx, yy, color)

    def svg(self):
        parts = []
        for y, row in enumerate(self.grid):
            x = 0
            while x < FRAME_SIZE:
                color = row[x]
                end = x+1
                while end < FRAME_SIZE and row[end] == color:
                    end += 1
                if color:
                    parts.append(f'<rect x="{x}" y="{y}" width="{end-x}" height="1" fill="{color}"/>')
                x = end
        return ''.join(parts)


INK = '#382e3c'
CREAM = '#fff1cf'
STEEL = '#c6dae0'
SKIN = '#eeb893'
GOLD = '#e8b75a'
FIRE = ['#733740', '#ac4145', '#d65c49', '#ee8e58', '#ffc477']
WATER = ['#30445f', '#476e93', '#699fbc', '#a7d6dd', '#e7f6ed']
EARTH = ['#34463f', '#4d6850', '#719365', '#a2bc79', '#d5de9f']
WOOD = ['#523b37', '#79523f', '#ac7950', '#d3a368', '#f0ca8b']


def army_figure(ident, frame):
    p = Pixels()
    moving = frame < 6
    bob = (0, -1, 0, 0, -1, 0)[frame] if moving else 0
    step = (0, 1, 1, 0, -1, -1)[frame] if moving else 0
    attack = frame == 6
    revive = frame == 7

    def r(x, y, w, h, color, fixed=False):
        p.rect(x, y if fixed else y+bob, w, h, color)

    def line(x0, y0, x1, y1, color):
        p.line(x0, y0+bob, x1, y1+bob, color)

    def poly(points, color):
        p.poly([(x, y+bob) for x, y in points], color)

    def oval(x, y, w, h, color):
        p.oval(x, y+bob, w, h, color)

    def eye(x, y, color=CREAM):
        r(x, y, 3, 3, INK)
        r(x, y, 2, 1, color)
        r(x+1, y+1, 1, 1, color)

    def boots(x0=10, x1=19, color=FIRE[0]):
        for x, stride in ((x0, step), (x1, -step)):
            r(x+stride, 25, 4, 5, INK, True)
            r(x+stride, 26, 3, 3, color, True)
            r(x+stride-1, 29, 5, 1, INK, True)

    if ident == 'fire_archer':
        # Curled, spined tail; overlapping scales, belly plates, flame mane.
        poly([(2,13),(5,16),(6,21),(11,21),(12,26),(6,27),(2,24),(0,18)], INK)
        poly([(2,15),(4,18),(4,23),(10,23),(10,25),(5,25),(2,22)], FIRE[2])
        line(2,16,2,21,FIRE[4])
        oval(7,13,16,14,INK); oval(8,14,14,12,FIRE[2])
        oval(14,16,8,10,FIRE[4]); r(15,21,6,1,FIRE[3]); r(16,24,4,1,FIRE[3])
        poly([(13,7),(16,5),(23,5),(25,9),(30,10),(31,15),(25,18),(16,17),(13,13)], INK)
        poly([(14,8),(17,6),(22,6),(24,10),(29,11),(30,14),(24,16),(16,15),(14,12)], FIRE[3])
        r(16,7,5,1,FIRE[4]); r(23,11,6,2,FIRE[4]); eye(21,8)
        r(29,12,1,1,INK); r(25,15,5,1,FIRE[0]); r(26,14,1,1,CREAM)
        for x,y in [(9,11),(12,7),(16,2)]:
            poly([(x,y+6),(x+1,y),(x+3,y+3),(x+4,y+6)],FIRE[2])
            r(x+1,y+2,1,3,GOLD)
        for x,y in [(9,16),(10,21),(12,19),(15,11)]:
            r(x,y,2,1,FIRE[0]); r(x,y-1,1,1,FIRE[4])
        r(8,22+step,4,6,INK,True); r(9,23+step,3,4,FIRE[3],True)
        r(19,25-step,5,4,INK,True); r(20,26-step,3,2,FIRE[3],True)
        r(8,28+step,5,1,CREAM,True); r(20,28-step,4,1,CREAM,True)
        if attack:
            r(29,14,3,2,GOLD); r(30,12,2,2,CREAM)
    elif ident == 'fire_melee':
        # Bat wings have rib membranes; ivory horns, gold collar and claws.
        poly([(8,15),(3,11),(1,13),(2,22),(5,21),(8,24)],INK)
        poly([(7,16),(3,13),(3,19),(6,18),(7,22)],FIRE[0])
        line(3,13,5,18,FIRE[2])
        poly([(23,15),(29,11),(31,14),(29,23),(26,21),(24,24)],INK)
        poly([(25,16),(29,13),(29,20),(26,18)],FIRE[0])
        line(29,14,27,18,FIRE[2])
        poly([(22,25),(27,26),(29,23),(29,20),(31,18),(31,22),(29,27),(24,28)],FIRE[1])
        oval(10,14,14,14,INK); oval(11,15,12,12,FIRE[2]); oval(14,19,7,7,FIRE[3])
        poly([(7,8),(10,6),(23,6),(27,9),(25,15),(21,18),(11,16)],INK)
        oval(9,7,16,10,FIRE[2]); r(11,8,10,1,FIRE[3])
        poly([(9,7),(7,1),(9,2),(11,7)],INK); line(8,2,10,6,CREAM)
        poly([(21,7),(25,1),(25,5),(23,8)],INK); line(24,2,23,6,CREAM)
        eye(11,10,GOLD); eye(20,10,GOLD)
        r(14,14,7,1,FIRE[0]); r(14,14,1,2,CREAM); r(20,14,1,2,CREAM)
        r(13,17,9,1,GOLD); r(17,18,2,2,GOLD)
        r(6,18+step,5,4,INK); r(7,19+step,4,2,FIRE[3]); r(6,21+step,3,1,CREAM)
        r(23,18-step,5,4,INK); r(24,19-step,3,2,FIRE[3]); r(26,21-step,2,1,CREAM)
        boots(11,19,FIRE[2])
        if attack: r(27,18,4,1,GOLD)
    elif ident == 'fire_tank':
        # Offset basalt slabs, chipped bevels and connected molten fissures.
        poly([(9,3),(14,1),(22,3),(24,7),(22,12),(10,13),(7,9)],INK)
        poly([(10,4),(14,2),(21,4),(22,8),(20,11),(10,11),(9,8)],'#625261')
        r(12,3,6,1,'#8b7072'); r(10,5,2,3,'#8b7072')
        r(11,7,4,2,GOLD); r(18,7,4,2,GOLD); r(12,7,2,1,CREAM)
        line(15,4,16,7,FIRE[2]); r(14,10,5,1,FIRE[3])
        poly([(9,12),(21,11),(25,14),(24,25),(19,28),(10,26),(7,21),(7,15)],INK)
        poly([(9,14),(20,13),(23,15),(22,24),(18,26),(10,24),(9,20)],'#625261')
        r(10,14,6,2,'#8b7072'); r(10,16,2,3,'#8b7072')
        poly([(15,15),(19,16),(20,20),(18,23),(14,23),(12,19)],FIRE[2])
        poly([(16,16),(18,18),(17,22),(15,21),(14,18)],GOLD); r(16,17,1,4,CREAM)
        line(9,19,13,20,FIRE[2]); line(19,23,22,22,FIRE[3])
        for x,stride in [(1,step),(24,-step)]:
            poly([(x+2,12+stride),(x+6,13+stride),(x+7,22+stride),(x+5,26+stride),(x,24+stride),(x,16+stride)],INK)
            r(x+1,15+stride,5,8,'#6e5b68'); r(x+1,15+stride,3,2,'#9c7d7c')
            line(x+1,21+stride,x+5,20+stride,FIRE[2]); r(x+3,21+stride,1,2,GOLD)
            r(x+1,23+stride,1,2,'#403b49')
        boots(9,19,'#625261'); r(10+step,27,2,1,FIRE[3],True); r(20-step,27,2,1,FIRE[3],True)
        if attack: r(27,24,4,2,GOLD)
    elif ident == 'fire_assassin':
        # Angular cloth folds, sash knot, wrapped boots, katana and bandana.
        boots(10,19,FIRE[0])
        poly([(10,15),(21,15),(25,21),(22,27),(10,27),(7,22)],INK)
        poly([(11,16),(21,16),(23,21),(21,25),(10,25),(9,20)],FIRE[1])
        r(10,17,3,5,FIRE[2]); line(14,17,20,23,FIRE[0]); r(19,18,2,3,FIRE[3])
        r(10,23,13,2,GOLD); r(17,23,3,3,WOOD[1]); r(18,23,1,1,CREAM)
        poly([(11,3),(20,2),(24,6),(24,13),(21,17),(11,17),(8,13),(8,7)],INK)
        poly([(11,4),(19,3),(22,6),(23,12),(20,15),(11,15),(9,12),(9,7)],FIRE[1])
        r(11,5,2,3,FIRE[2]); line(14,4,19,4,FIRE[3]); r(20,6,2,2,FIRE[2])
        r(10,9,13,4,SKIN); r(11,9,10,1,CREAM)
        r(12,10,3,2,INK); r(19,10,3,2,INK); r(12,10,1,1,CREAM); r(19,10,1,1,CREAM)
        r(10,13,13,3,FIRE[0]); line(11,13,19,14,FIRE[2]); r(12,15,6,1,FIRE[1])
        poly([(9,14),(4,14-step),(1,17-step),(5,17-step),(2,20-step),(8,18-step),(12,16)],FIRE[2])
        line(2,17-step,7,15-step,FIRE[3])
        # Back scabbard remains behind the sword hand.
        line(19,17,24,27,INK); line(20,17,25,27,WOOD[1])
        if attack:
            r(22,19,4,3,FIRE[2]); line(24,18,31,12,INK); line(24,17,30,12,STEEL)
            line(25,17,30,13,CREAM); r(22,20,3,2,WOOD[1]); r(24,18,2,1,GOLD)
        else:
            r(23,18,3,5,FIRE[2]); r(25,8,2,15,INK); r(25,8,1,13,STEEL)
            r(25,8,1,8,CREAM); r(23,22,6,1,GOLD); r(25,23,2,4,WOOD[1])
        for x in [10+step,19-step]:
            r(x,27,3,1,STEEL,True); r(x,29,4,1,FIRE[0],True)
        if revive:
            for x,y in [(5,8),(26,5),(3,24),(28,26)]:
                r(x,y,3,1,GOLD); r(x+1,y-1,1,3,CREAM)
    elif ident == 'water_mage':
        # Layered wizard hat, brocade robe, beard strands and crystal staff.
        poly([(11,18),(22,18),(24,24),(27,30),(7,30),(9,24)],INK)
        poly([(12,19),(21,19),(22,25),(25,29),(9,29),(11,24)],WATER[1])
        r(12,21,3,7,WATER[2]); r(19,22,2,7,WATER[0]); r(10,28,15,1,WATER[3])
        line(15,21,18,26,GOLD); r(15,25,4,1,GOLD); r(16,26,2,2,WATER[3])
        oval(10,10,14,11,INK); oval(11,11,12,9,SKIN); r(12,12,7,1,CREAM)
        eye(12,14,WATER[4]); eye(19,14,WATER[4])
        poly([(11,17),(15,19),(22,17),(20,23),(16,25),(12,22)],WATER[3])
        line(13,18,15,22,WATER[4]); line(20,18,18,23,WATER[4]); r(15,18,3,1,WATER[1])
        poly([(6,11),(10,8),(12,4),(14,1),(18,2),(19,5),(22,9),(27,11),(25,13),(7,13)],INK)
        poly([(11,9),(13,5),(15,2),(17,3),(18,6),(21,10)],WATER[2])
        line(14,4,13,8,WATER[3]); r(8,11,17,1,WATER[2]); r(11,9,11,1,GOLD)
        r(17,6,2,2,WATER[4]); r(18,5,1,4,WATER[4])
        r(5,22,5,4,INK); r(6,22,4,3,WATER[2]); r(22,21,5,3,SKIN)
        r(27,9,2,20,WOOD[0]); r(27,10,1,17,WOOD[3]); r(25,12,6,1,GOLD)
        poly([(27,3),(30,5),(31,8),(28,11),(25,8),(25,5)],WATER[0])
        poly([(27,4),(29,5),(30,8),(28,10),(26,8),(26,5)],WATER[3]); line(27,5,27,8,WATER[4])
        if attack: r(30,2,2,1,CREAM)
    elif ident == 'water_tank':
        # Faceted ice crystals have dark edges, reflections and cracks.
        poly([(11,2),(18,1),(23,5),(22,12),(17,14),(10,11),(8,6)],WATER[0])
        poly([(11,3),(18,2),(21,5),(21,10),(17,12),(11,10),(10,6)],WATER[3])
        poly([(11,3),(15,3),(14,9),(11,8)],WATER[4]); poly([(19,4),(21,5),(20,10),(17,11)],WATER[2])
        r(12,7,3,2,WATER[0]); r(18,7,3,2,WATER[0]); r(12,7,1,1,WATER[4])
        line(16,3,17,6,WATER[1]); r(15,11,4,1,WATER[1])
        poly([(8,12),(22,12),(25,17),(23,25),(18,28),(10,26),(6,21)],WATER[0])
        poly([(10,13),(21,13),(23,17),(21,24),(17,26),(11,24),(8,20)],WATER[3])
        poly([(10,14),(15,14),(14,23),(10,21)],WATER[4])
        poly([(17,15),(21,15),(22,18),(20,24),(16,23)],WATER[2])
        line(15,14,17,18,WATER[1]); line(17,18,15,21,WATER[1]); r(18,17,2,3,WATER[4])
        for x,stride in [(0,step),(24,-step)]:
            poly([(x+3,10+stride),(x+6,12+stride),(x+7,20+stride),(x+5,26+stride),(x,23+stride),(x,14+stride)],WATER[0])
            poly([(x+3,12+stride),(x+5,14+stride),(x+5,21+stride),(x+3,24+stride),(x+1,21+stride),(x+1,15+stride)],WATER[3])
            r(x+2,14+stride,2,5,WATER[4]); line(x+2,21+stride,x+4,22+stride,WATER[1])
        boots(9,19,WATER[2]); r(9+step,26,2,2,WATER[4],True); r(19-step,26,2,2,WATER[3],True)
        if attack: r(28,25,3,2,WATER[4])
    elif ident == 'water_melee':
        # Broad gelatin silhouette with a transparent core and glossy droplets.
        squash = (0,1,0,-1,0,1)[frame] if moving else 0
        oval(4-squash,11+squash,24+2*squash,19-squash,WATER[0])
        r(3-squash,24,26+2*squash,5,WATER[0])
        oval(5-squash,12+squash,22+2*squash,16-squash,WATER[2])
        oval(9,13+squash,15,12,WATER[3]); oval(12,17+squash,9,7,'#84c4d0')
        poly([(5,24),(10,26),(23,26),(27,23),(27,27),(24,29),(7,29),(4,27)],'#68acbe')
        r(9,14+squash,6,1,WATER[4]); r(7,16+squash,2,4,WATER[4]); r(8,16+squash,2,1,CREAM)
        eye(12,20+squash,WATER[4]); eye(21,20+squash,WATER[4])
        r(17,25,3,1,WATER[0]); r(17,24,1,1,WATER[4])
        r(6,26,2,1,WATER[3]); r(23,27,2,1,WATER[4]); r(18,14,2,1,WATER[4])
        if attack: r(29,22,2,3,WATER[3])
    elif ident == 'water_ranged':
        # Snow shading, woven scarf, twig fingers, brass hat buckle and coal.
        oval(7,15,19,15,WATER[0]); oval(8,16,17,13,WATER[3]); oval(9,16,14,11,WATER[4])
        r(20,25,3,2,WATER[3]); r(11,27,7,1,CREAM)
        for x,y in [(16,22),(16,26)]: r(x,y,2,2,INK); r(x,y,1,1,WATER[1])
        for x,stride in [(2,step),(24,-step)]:
            line(x,16+stride,x+5,21+stride,WOOD[0]); line(x,17+stride,x+5,21+stride,WOOD[2])
            line(x+1,17+stride,x+1,13+stride,WOOD[0]); line(x+2,18+stride,x+6,16+stride,WOOD[0])
        oval(9,6,16,13,WATER[0]); oval(10,7,14,11,WATER[3]); oval(10,7,12,9,WATER[4])
        r(12,10,2,2,INK); r(20,10,2,2,INK); r(12,10,1,1,WATER[2])
        poly([(17,12),(26,13),(20,15),(17,14)],FIRE[3]); r(18,12,4,1,GOLD)
        r(12,15,1,1,INK); r(14,16,1,1,INK); r(17,16,1,1,INK)
        r(8,17,18,3,WATER[1]); r(9,17,16,1,WATER[3]); r(10,20,4,6,WATER[1]); r(11,21,1,4,WATER[2]); r(10,26,4,1,WATER[3])
        r(11,2,12,6,INK); r(12,3,10,4,WATER[0]); r(12,3,2,2,WATER[1]); r(11,6,12,2,WATER[2])
        r(16,6,3,2,GOLD); r(17,6,1,1,CREAM); r(7,8,20,2,INK); r(9,8,15,1,WATER[1])
        if attack: oval(27,19,5,5,WATER[4])
    elif ident == 'earth_tank':
        # Root feet, twisting bark grain, mushrooms and clustered foliage.
        poly([(10,11),(21,11),(23,26),(28,28),(27,30),(20,29),(17,27),(12,29),(4,30),(5,27),(9,25)],WOOD[0])
        poly([(11,12),(20,12),(21,25),(25,28),(20,27),(17,25),(12,27),(7,28),(11,25)],WOOD[2])
        line(12,14,13,24,WOOD[3]); line(17,17,16,24,WOOD[1]); line(19,22,20,26,WOOD[1])
        r(14,24,1,3,WOOD[4]); r(20,27,4,1,WOOD[3])
        for x,stride in [(1,step),(22,-step)]:
            poly([(x+2,11+stride),(x+4,13+stride),(x+3,17+stride),(x+8,18+stride),(x+8,22+stride),(x+1,20+stride),(x,15+stride)],WOOD[0])
            line(x+2,14+stride,x+2,18+stride,WOOD[3]); line(x+2,18+stride,x+7,20+stride,WOOD[2])
        oval(9,0,14,9,EARTH[0]); oval(3,4,25,12,EARTH[0]); oval(0,8,31,7,EARTH[0])
        oval(10,1,12,8,EARTH[2]); oval(4,5,22,9,EARTH[1]); oval(1,8,27,6,EARTH[1])
        for x,y,w in [(9,3,6),(16,2,4),(5,6,5),(17,6,6),(2,10,5),(11,9,6),(23,9,5)]:
            r(x,y,w,2,EARTH[2]); r(x+1,y,w-2,1,EARTH[3])
        for x,y in [(7,5),(19,4),(13,7),(24,11)]: r(x,y,2,1,EARTH[4])
        eye(11,16); eye(18,16); r(14,21,5,1,WOOD[0]); r(15,22,3,1,WOOD[3])
        r(22,24,2,3,CREAM); r(20,23,5,2,FIRE[2]); r(21,23,1,1,CREAM)
        r(7,26,3,1,EARTH[2]); r(24,28,2,1,EARTH[2])
        if attack: r(27,20,4,2,WOOD[3])
    elif ident == 'earth_melee':
        # Small mammal with overlapping shell bands and a long ringed tail.
        line(1,23-step,8,24-step,WOOD[0]); line(2,23-step,8,23-step,WOOD[2])
        for x in [3,5]: r(x,22-step,1,2,WOOD[1])
        for x,stride in [(8,step),(17,-step),(23,step)]:
            r(x+stride,24,3,5,WOOD[0],True); r(x+stride,26,2,2,WOOD[2],True); r(x+stride,28,3,1,CREAM,True)
        oval(5,9,20,17,WOOD[0]); oval(6,10,18,14,WOOD[2]); oval(8,10,13,9,WOOD[3])
        for x in [10,14,18]:
            line(x,11,x-2,22,WOOD[0]); line(x+1,12,x-1,20,WOOD[4])
            r(x-1,16,2,1,WOOD[1]); r(x-2,20,2,1,WOOD[1])
        line(7,21,19,23,WOOD[1]); r(9,11,6,1,WOOD[4]); r(7,14,1,3,WOOD[4])
        poly([(21,16),(25,15),(28,19),(31,21),(31,24),(26,26),(21,24),(19,20)],WOOD[0])
        poly([(22,17),(25,17),(27,20),(30,22),(30,23),(26,24),(22,22)],WOOD[3])
        poly([(23,17),(22,11),(25,12),(26,17)],WOOD[0]); r(23,13,1,3,SKIN)
        eye(25,18,CREAM); r(30,22,1,2,INK); r(25,24,4,1,WOOD[1])
        if attack: r(22,26,3,1,GOLD)
    elif ident == 'earth_ranged':
        # Leaf hood, braided quiver, leather straps and a bent wood bow.
        boots(10,19,WOOD[1])
        r(5,12,4,13,WOOD[0]); r(6,13,2,10,WOOD[2]); r(6,20,2,1,GOLD)
        for x in [4,6,8]:
            line(x,5,x+1,14,WOOD[3]); r(x-1,5,3,2,CREAM)
        poly([(10,16),(22,16),(24,25),(21,27),(10,27),(8,22)],EARTH[0])
        poly([(11,17),(21,17),(22,24),(20,25),(11,25),(10,21)],EARTH[2])
        r(11,18,2,5,EARTH[3]); line(12,17,21,23,WOOD[1]); line(12,18,21,24,WOOD[3])
        r(10,23,13,2,WOOD[1]); r(15,23,3,2,GOLD); r(16,23,1,1,CREAM)
        oval(8,4,17,15,EARTH[0]); oval(9,5,15,13,EARTH[1]); oval(11,8,11,9,SKIN)
        r(11,9,9,1,CREAM); eye(12,11,CREAM); eye(19,11,CREAM); r(15,15,3,1,WOOD[1])
        poly([(7,10),(11,3),(18,2),(25,8),(20,7),(16,5),(11,8)],EARTH[2]); line(11,5,16,3,EARTH[3])
        r(20,3,1,5,WOOD[3]); poly([(20,2),(24,1),(23,5),(20,7)],EARTH[3]); r(21,2,1,3,EARTH[4])
        r(22,18,4,4,WOOD[0]); r(22,18,3,3,SKIN)
        line(27,9,30,14,WOOD[0]); line(30,14,30,23,WOOD[0]); line(30,23,27,28,WOOD[0])
        line(27,10,29,14,WOOD[3]); line(29,14,29,23,WOOD[3]); line(29,23,27,27,WOOD[3])
        line(26,10,26,27,CREAM); line(24,19,31,19,WOOD[4]); r(30,18,2,3,STEEL)
        if attack: line(23,18,31,17,CREAM)
    elif ident == 'earth_siege':
        # Braced trebuchet with plank grain, iron rivets, geared wheels and sling.
        r(3,25,26,3,INK); r(4,25,24,2,WOOD[2]); r(5,25,20,1,WOOD[3])
        for x in [5,23]:
            oval(x-2,23,8,8,INK); oval(x-1,24,6,6,WOOD[2]); oval(x,25,4,4,WOOD[1])
            r(x+1,24,1,6,WOOD[3]); r(x-1,27,6,1,WOOD[3]); r(x+1,27,1,1,STEEL)
        poly([(7,25),(11,12),(14,12),(10,25)],WOOD[0]); poly([(8,24),(12,13),(13,13),(9,24)],WOOD[3])
        poly([(18,13),(21,12),(26,25),(22,25)],WOOD[0]); line(21,14,24,24,WOOD[2])
        r(10,16,13,3,WOOD[0]); r(11,16,11,1,WOOD[3]); r(11,18,11,1,WOOD[1])
        r(10,20,14,5,WOOD[0]); r(11,20,12,4,WOOD[2]); r(12,21,10,1,WOOD[3]); r(11,23,12,1,WOOD[1])
        for x in [11,21]: r(x,16,1,1,STEEL); r(x,23,1,1,STEEL)
        pivot_y = 12
        top = (23,4) if attack else (16,3+step)
        line(12,23,top[0],top[1],WOOD[0]); line(13,23,top[0]+1,top[1],WOOD[0])
        line(13,22,top[0],top[1]+1,WOOD[3]); line(13,22,top[0]+1,top[1]+1,WOOD[2])
        r(13,pivot_y,4,3,INK); r(14,pivot_y,2,2,STEEL); r(14,pivot_y,1,1,CREAM)
        line(top[0],top[1],27,8,WOOD[4]); line(27,8,28,13,WOOD[4])
        oval(24,11,7,6,WOOD[0]); oval(25,12,5,3,WOOD[2]); r(26,11,3,2,EARTH[2]); r(27,11,1,1,EARTH[4])
        r(3,16,6,6,WOOD[0]); r(4,17,4,4,WOOD[1]); r(4,17,4,1,WOOD[3]); r(5,19,2,1,STEEL)
        r(16,20,4,4,EARTH[0]); r(17,20,2,3,EARTH[2]); r(17,21,2,1,CREAM)
    else:
        raise ValueError(ident)
    return p.svg()
