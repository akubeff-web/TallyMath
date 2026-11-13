"""Генерирует превью дизайна TallyMath: лист персонажа Bit и макеты экранов.

Запуск: python3 design/src/generate.py  (SVG пишутся в design/)
PNG рендерятся отдельно: node design/src/render.js
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent
FONT = "'SF Pro Rounded','SF Pro Display',-apple-system,Inter,sans-serif"

THEMES = {
    "light": dict(
        bg="#FFFFFF", ink="#151515", sub="#6E6E73", faint="#A1A1A6",
        body_top="#FBFBFA", body_bot="#E3E3E0", outline="#1E1E1E",
        eye="#FFFFFF", eye_ring="#1E1E1E", pupil="#121212",
        card="#FFFFFF", card_op=0.78, card_stroke="#000000", card_stroke_op=0.06,
        glass_fill="#FFFFFF", glass_op=0.52, edge_op=(0.95, 0.25, 0.7),
        blobs=["#CFCFCF", "#E6E6E6", "#BDBDBD", "#DADADA"], base="#FFFFFF",
        prom_fill="#141414", prom_text="#FFFFFF", frame="#D4D4D4", sheet="#FFFFFF",
        shadow_op=0.10,
    ),
    "dark": dict(
        bg="#000000", ink="#F2F2F2", sub="#98989F", faint="#5A5A5F",
        body_top="#5C5C5C", body_bot="#262626", outline="#D8D8D8",
        eye="#F5F5F5", eye_ring="#D8D8D8", pupil="#121212",
        card="#1C1C1E", card_op=0.82, card_stroke="#FFFFFF", card_stroke_op=0.08,
        glass_fill="#FFFFFF", glass_op=0.09, edge_op=(0.55, 0.08, 0.3),
        blobs=["#3A3A3A", "#262626", "#4A4A4A", "#2E2E2E"], base="#000000",
        prom_fill="#F2F2F2", prom_text="#000000", frame="#2C2C2E", sheet="#000000",
        shadow_op=0.0,
    ),
}


# ---------- Bit ----------

def squircle(a, n=4.6, steps=160):
    """Суперэллипс: так выглядит «непрерывное» скругление iOS, а не обычный rx."""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        x = a * math.copysign(abs(c) ** (2 / n), c)
        y = a * math.copysign(abs(s) ** (2 / n), s)
        pts.append(f"{x:.2f},{y:.2f}")
    return "M" + " L".join(pts) + " Z"


BODY = squircle(105)


def defs_bit(theme):
    t = THEMES[theme]
    return (f'<linearGradient id="body-{theme}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{t["body_top"]}"/>'
            f'<stop offset="1" stop-color="{t["body_bot"]}"/></linearGradient>')


def stroke(d, t, w=4.5, extra=""):
    return (f'<path d="{d}" fill="none" stroke="{t["ink"]}" stroke-width="{w}" '
            f'stroke-linecap="round" stroke-linejoin="round" {extra}/>')


def eye(cx, cy, t, mode="open", dx=0, dy=0):
    if mode == "closed":
        return stroke(f"M{cx-16} {cy} Q{cx} {cy+7} {cx+16} {cy}", t)
    if mode == "happy":
        return stroke(f"M{cx-17} {cy+6} Q{cx} {cy-16} {cx+17} {cy+6}", t)
    px, py = cx + dx, cy + dy
    return (f'<circle cx="{cx}" cy="{cy}" r="20" fill="{t["eye"]}" stroke="{t["eye_ring"]}" stroke-width="3"/>'
            f'<circle cx="{px}" cy="{py}" r="9.5" fill="{t["pupil"]}"/>'
            f'<circle cx="{px+3}" cy="{py-3.5}" r="2.6" fill="#FFFFFF"/>')


def arm(d, hx, hy, t, r=12):
    return stroke(d, t) + f'<circle cx="{hx}" cy="{hy}" r="{r}" fill="{t["ink"]}"/>'


def plus(x, y, t, s=14):
    return stroke(f"M{x-s} {y} L{x+s} {y} M{x} {y-s} L{x} {y+s}", t, 4.5)


def bit(state, theme, x, y, scale=1.0):
    """Bit в одном из состояний. (x, y) — центр тела."""
    t = THEMES[theme]
    back, front = [], []
    # Руки рисуем под телом, чтобы плечо пряталось за контур.
    arm_l_down = arm("M-100 10 C-140 25 -150 60 -150 92", -150, 92, t)
    arm_r_down = arm("M100 10 C140 25 150 60 150 92", 150, 92, t)
    arm_l_up = arm("M-100 -8 C-140 -35 -152 -80 -152 -122", -152, -122, t)
    arm_r_up = arm("M100 -8 C140 -35 152 -80 152 -122", 152, -122, t)
    smile = stroke("M-26 38 Q0 56 26 38", t)
    open_mouth = f'<path d="M-29 30 L29 30 Q26 66 0 66 Q-26 66 -29 30 Z" fill="{t["ink"]}"/>'
    flat_brows = stroke("M-56 -62 L-24 -62 M24 -62 L56 -62", t)

    if state in ("idle", "idle_blink"):
        back += [arm_l_down, arm_r_down]
        mode = "closed" if state == "idle_blink" else "open"
        front += [flat_brows, eye(-38, -22, t, mode, 2, -2), eye(38, -22, t, mode, 2, -2), smile]
    elif state == "correct":
        back += [arm_l_up, arm_r_up]
        front += [eye(-38, -20, t, "happy"), eye(38, -20, t, "happy"), open_mouth,
                  plus(-82, -170, t), plus(96, -190, t, 11)]
    elif state == "wrong":
        back += [arm_l_down,
                 arm("M98 -20 C150 -50 150 -110 108 -128", 108, -128, t)]
        front += [stroke("M-56 -60 L-24 -63", t), stroke("M22 -68 Q40 -80 58 -66", t),
                  eye(-38, -20, t, "open", -5, 4), eye(38, -20, t, "open", -5, 4),
                  stroke("M-22 42 C-14 32 -6 32 0 40 C6 48 14 48 22 38", t),
                  f'<text x="-140" y="-112" font-family="{FONT}" font-size="54" font-weight="700" '
                  f'fill="{t["ink"]}" text-anchor="middle">?</text>']
    elif state == "hint":
        back += [arm_l_down, arm("M100 18 C130 14 150 4 172 -6", 172, -6, t)]
        card = (f'<rect x="190" y="-52" width="86" height="96" rx="20" fill="{t["bg"]}" '
                f'stroke="{t["ink"]}" stroke-width="3"/>'
                + stroke("M206 -28 L258 -28", t, 4) + stroke("M206 -8 L246 -8", t, 4)
                + stroke("M206 12 L254 12", t, 4))
        bulb = (f'<circle cx="-132" cy="-150" r="20" fill="none" stroke="{t["ink"]}" stroke-width="3.5"/>'
                + stroke("M-142 -122 L-122 -122 M-140 -114 L-124 -114", t, 3.5)
                + stroke("M-132 -186 L-132 -196 M-160 -170 L-169 -176 M-104 -170 L-95 -176", t, 3.5))
        front += [stroke("M-56 -62 L-26 -62", t), stroke("M22 -68 Q40 -82 58 -68", t),
                  eye(-38, -22, t, "open", 6, 0), eye(38, -22, t, "open", 6, 0),
                  stroke("M-24 38 Q2 54 26 36", t), card, bulb]
    elif state == "streak":
        back += [arm("M-100 -8 C-150 -30 -175 -80 -178 -120", -178, -120, t),
                 arm("M100 -8 C150 -30 175 -80 178 -120", 178, -120, t)]
        badge = (f'<rect x="-56" y="-176" width="112" height="40" rx="20" fill="{t["ink"]}"/>'
                 f'<text x="0" y="-149" font-family="{FONT}" font-size="20" font-weight="700" '
                 f'fill="{t["bg"]}" text-anchor="middle">Серия 5</text>')
        ticks = (stroke("M-204 -132 L-218 -142 M-206 -110 L-222 -110", t, 3.5)
                 + stroke("M204 -132 L218 -142 M206 -110 L222 -110", t, 3.5))
        front += [stroke("M-56 -58 Q-40 -72 -22 -60 M22 -60 Q40 -72 56 -58", t),
                  eye(-38, -20, t, "open", 0, -1), eye(38, -20, t, "open", 0, -1), open_mouth,
                  badge, ticks, plus(-110, -190, t, 11), plus(118, -196, t, 9)]
    elif state == "waiting":
        back += [arm_l_down]
        # Рука у подбородка должна быть поверх тела, иначе её не видно.
        chin = arm("M102 12 C138 34 128 76 82 72", 82, 72, t, 13)
        bubble = (f'<circle cx="92" cy="-128" r="6" fill="{t["ink"]}"/>'
                  f'<circle cx="114" cy="-152" r="9" fill="{t["ink"]}"/>'
                  f'<ellipse cx="166" cy="-190" rx="50" ry="30" fill="{t["bg"]}" stroke="{t["ink"]}" stroke-width="3"/>'
                  + "".join(f'<circle cx="{166+dx}" cy="-190" r="5.5" fill="{t["ink"]}"/>' for dx in (-18, 0, 18)))
        front += [stroke("M22 -70 Q40 -82 58 -70", t), stroke("M-56 -62 L-24 -62", t),
                  eye(-38, -22, t, "open", 5, -6), eye(38, -22, t, "open", 5, -6),
                  stroke("M-18 42 L20 36", t), bubble, chin]

    body = (f'<path d="{BODY}" fill="url(#body-{theme})" stroke="{t["outline"]}" stroke-width="3"/>'
            + stroke("M-88 -44 C-88 -64 -82 -76 -66 -80", t, 3.5, f'stroke-opacity="0.85"'))
    return (f'<g transform="translate({x} {y}) scale({scale})">'
            + "".join(back) + body + "".join(front) + "</g>")


def bit_sheet():
    W, CW, CH, HEAD = 1440, 480, 470, 120
    states = [
        ("idle", "Спокойный", "idle · моргает, покачивается"),
        ("correct", "Верно", "correct · «Верно.»"),
        ("wrong", "Ошибка", "wrong · «Почти. Смотри шаги ниже.»"),
        ("hint", "Подсказка", "hint · показывает на карточку"),
        ("streak", "Серия", "streak · «Серия: 5»"),
        ("waiting", "Ждёт", "waiting · ждёт ответ"),
    ]
    sec_h = HEAD + 2 * CH
    H = sec_h * 2
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
             "<defs>" + defs_bit("light") + defs_bit("dark") + "</defs>"]
    for si, theme in enumerate(("light", "dark")):
        t = THEMES[theme]
        oy = si * sec_h
        parts.append(f'<rect x="0" y="{oy}" width="{W}" height="{sec_h}" fill="{t["sheet"]}"/>')
        title = "Bit · светлая тема" if theme == "light" else "Bit · тёмная тема"
        parts.append(f'<text x="60" y="{oy+74}" font-family="{FONT}" font-size="30" font-weight="700" fill="{t["ink"]}">{title}</text>')
        for i, (st, name, sub) in enumerate(states):
            cx = (i % 3) * CW + CW / 2
            cy = oy + HEAD + (i // 3) * CH + 250
            shift = {"hint": -45, "waiting": -30}.get(st, 0)
            parts.append(bit(st, theme, cx + shift, cy, 0.9))
            if st == "idle":
                # Кадр моргания рядом, чтобы было видно анимацию.
                parts.append(bit("idle_blink", theme, cx + 150, cy - 150, 0.28))
                parts.append(f'<text x="{cx+150}" y="{cy-96}" font-family="{FONT}" font-size="14" fill="{t["sub"]}" text-anchor="middle">кадр моргания</text>')
            parts.append(f'<text x="{cx}" y="{cy+165}" font-family="{FONT}" font-size="26" font-weight="600" fill="{t["ink"]}" text-anchor="middle">{name}</text>')
            parts.append(f'<text x="{cx}" y="{cy+195}" font-family="{FONT}" font-size="16" fill="{t["sub"]}" text-anchor="middle">{sub}</text>')
    parts.append("</svg>")
    (OUT / "bit-states.svg").write_text("\n".join(parts), encoding="utf-8")


# ---------- Экраны ----------

PW, PH = 393, 852


class Screen:
    """Один экран iPhone. Стекло рисуется как размытая копия фона под формой + блик по краю."""

    def __init__(self, theme, sid):
        self.t = THEMES[theme]
        self.theme = theme
        self.sid = sid
        self.defs = []
        self.items = []
        self.n = 0

    def uid(self, p):
        self.n += 1
        return f"{self.sid}-{p}{self.n}"

    def text(self, x, y, s, size=17, weight=400, color=None, anchor="start", op=1):
        c = color or self.t["ink"]
        self.items.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
                          f'fill="{c}" fill-opacity="{op}" text-anchor="{anchor}">{s}</text>')

    def raw(self, s):
        self.items.append(s)

    def background(self):
        t = self.t
        b = t["blobs"]
        blobs = (f'<rect width="{PW}" height="{PH}" fill="{t["base"]}"/>'
                 f'<circle cx="40" cy="170" r="170" fill="{b[0]}"/>'
                 f'<circle cx="360" cy="360" r="150" fill="{b[1]}"/>'
                 f'<ellipse cx="300" cy="760" rx="210" ry="150" fill="{b[2]}"/>'
                 f'<circle cx="60" cy="620" r="120" fill="{b[3]}"/>'
                 f'<ellipse cx="190" cy="470" rx="200" ry="130" fill="{b[1]}"/>')
        self.defs.append(f'<filter id="{self.sid}-soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="55"/></filter>'
                         f'<filter id="{self.sid}-glassblur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="75"/></filter>'
                         f'<g id="{self.sid}-bg">{blobs}</g>')
        self.items.append(f'<rect width="{PW}" height="{PH}" fill="{t["base"]}"/>'
                          f'<use href="#{self.sid}-bg" filter="url(#{self.sid}-soft)"/>'
                          # Лёгкий шум убирает полосы на плавных тёмных градиентах.
                          f'<rect width="{PW}" height="{PH}" filter="url(#{self.sid}-noise)" opacity="0.05"/>')
        self.defs.append(f'<filter id="{self.sid}-noise"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch"/>'
                         f'<feColorMatrix type="saturate" values="0"/></filter>')

    def rr(self, x, y, w, h, r):
        # Непрерывное скругление аппроксимируем кубическими кривыми с удлинённым плечом.
        r = min(r, w / 2, h / 2)
        k = r * 1.28
        k = min(k, w / 2, h / 2)
        c = r * 0.36
        return (f"M{x+k} {y} L{x+w-k} {y} C{x+w-c} {y} {x+w} {y+c} {x+w} {y+k} "
                f"L{x+w} {y+h-k} C{x+w} {y+h-c} {x+w-c} {y+h} {x+w-k} {y+h} "
                f"L{x+k} {y+h} C{x+c} {y+h} {x} {y+h-c} {x} {y+h-k} "
                f"L{x} {y+k} C{x} {y+c} {x+c} {y} {x+k} {y} Z")

    def capsule(self, x, y, w, h):
        r = h / 2
        return (f"M{x+r} {y} L{x+w-r} {y} A{r} {r} 0 0 1 {x+w-r} {y+h} "
                f"L{x+r} {y+h} A{r} {r} 0 0 1 {x+r} {y} Z")

    def glass(self, d, prominent=False):
        t = self.t
        cid, gid = self.uid("clip"), self.uid("edge")
        self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>'
                         f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
                         f'<stop offset="0" stop-color="#FFFFFF" stop-opacity="{t["edge_op"][0]}"/>'
                         f'<stop offset="0.5" stop-color="#FFFFFF" stop-opacity="{t["edge_op"][1]}"/>'
                         f'<stop offset="1" stop-color="#FFFFFF" stop-opacity="{t["edge_op"][2]}"/></linearGradient>')
        if t["shadow_op"]:
            self.items.append(f'<path d="{d}" fill="#000" fill-opacity="{t["shadow_op"]}" filter="url(#{self.sid}-shadow)"/>')
        if prominent:
            self.items.append(f'<path d="{d}" fill="{t["prom_fill"]}"/>')
            self.items.append(f'<path d="{d}" fill="url(#{self.sid}-sheen)"/>')
        else:
            self.items.append(f'<g clip-path="url(#{cid})"><use href="#{self.sid}-bg" filter="url(#{self.sid}-glassblur)"/>'
                              f'<rect width="{PW}" height="{PH}" fill="{t["glass_fill"]}" fill-opacity="{t["glass_op"]}"/></g>')
        self.items.append(f'<path d="{d}" fill="none" stroke="url(#{gid})" stroke-width="1.2"/>')

    def card(self, d):
        t = self.t
        self.items.append(f'<path d="{d}" fill="{t["card"]}" fill-opacity="{t["card_op"]}" '
                          f'stroke="{t["card_stroke"]}" stroke-opacity="{t["card_stroke_op"]}"/>')

    def icon(self, name, cx, cy, s=1.0, color=None, w=2.2):
        c = color or self.t["ink"]
        st = f'fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"'
        g = {
            "chevron.left": f'<path d="M4 -9 L-5 0 L4 9" {st}/>',
            "xmark": f'<path d="M-7 -7 L7 7 M7 -7 L-7 7" {st}/>',
            "chart": f'<path d="M-8 8 L-8 0 M0 8 L0 -8 M8 8 L8 -3" {st} stroke-width="{w+1}"/>',
            "gear": f'<circle r="8" {st}/><circle r="3" {st}/>',
            "grid": f'<rect x="-9" y="-9" width="7.5" height="7.5" rx="2" {st}/><rect x="1.5" y="-9" width="7.5" height="7.5" rx="2" {st}/>'
                    f'<rect x="-9" y="1.5" width="7.5" height="7.5" rx="2" {st}/><rect x="1.5" y="1.5" width="7.5" height="7.5" rx="2" {st}/>',
            "delete": f'<path d="M-4 -9 L10 -9 L10 9 L-4 9 L-12 0 Z" {st}/><path d="M-1 -4 L6 4 M6 -4 L-1 4" {st}/>',
            "updown": f'<path d="M-5 8 L-5 -8 M-9 -4 L-5 -8 L-1 -4 M5 -8 L5 8 M1 4 L5 8 L9 4" {st}/>',
            "check": f'<path d="M-7 0 L-2 6 L8 -6" {st}/>',
            "xcircle": f'<circle r="11" {st}/><path d="M-4.5 -4.5 L4.5 4.5 M4.5 -4.5 L-4.5 4.5" {st}/>',
            "play": f'<path d="M-4 -7 L7 0 L-4 7 Z" fill="{c}"/>',
            "arrow.right": f'<path d="M-7 0 L7 0 M2 -5 L7 0 L2 5" {st}/>',
            "bulb": f'<path d="M-6 3 C-11 -1 -9 -10 0 -10 C9 -10 11 -1 6 3 L5 6 L-5 6 Z" {st}/><path d="M-4 10 L4 10" {st}/>',
        }[name]
        self.items.append(f'<g transform="translate({cx} {cy}) scale({s})">{g}</g>')

    def status_bar(self):
        c = self.t["ink"]
        self.text(52, 37, "9:41", 17, 600)
        for i, h in enumerate((4, 6.5, 9, 11.5)):
            self.raw(f'<rect x="{298+i*5}" y="{32-h}" width="3.2" height="{h}" rx="1" fill="{c}"/>')
        self.raw(f'<path d="M323 25 Q330.5 19 338 25 M326 28 Q330.5 24.5 335 28" fill="none" stroke="{c}" stroke-width="2" stroke-linecap="round"/>'
                 f'<circle cx="330.5" cy="31" r="1.6" fill="{c}"/>'
                 f'<rect x="344" y="21.5" width="25" height="12" rx="3.8" fill="none" stroke="{c}" stroke-opacity="0.4"/>'
                 f'<rect x="346" y="23.5" width="19" height="8" rx="2.2" fill="{c}"/>'
                 f'<path d="M370.5 25.5 L370.5 29.5" stroke="{c}" stroke-opacity="0.4" stroke-width="1.6" stroke-linecap="round"/>')

    def home_indicator(self):
        self.raw(f'<rect x="{PW/2-67}" y="{PH-13}" width="134" height="5" rx="2.5" fill="{self.t["ink"]}"/>')

    def frac(self, cx, top, num, den, size=44, color=None, weight=700):
        c = color or self.t["ink"]
        self.text(cx, top + size * 0.82, num, size, weight, c, "middle")
        ly = top + size + 6
        w = max(len(num), len(den)) * size * 0.62 + 10
        self.raw(f'<path d="M{cx-w/2} {ly} L{cx+w/2} {ly}" stroke="{c}" stroke-width="{size/14:.1f}" stroke-linecap="round"/>')
        self.text(cx, ly + 6 + size * 0.82, den, size, weight, c, "middle")

    def render(self):
        t = self.t
        self.defs.append(f'<filter id="{self.sid}-shadow" x="-30%" y="-30%" width="160%" height="180%"><feGaussianBlur stdDeviation="10"/><feOffset dy="6"/></filter>'
                         f'<linearGradient id="{self.sid}-sheen" x1="0" y1="0" x2="0" y2="1">'
                         f'<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>'
                         f'<clipPath id="{self.sid}-phone"><path d="{self.rr(0, 0, PW, PH, 55)}"/></clipPath>')
        return ("<defs>" + "".join(self.defs) + "</defs>"
                + f'<g clip-path="url(#{self.sid}-phone)">' + "".join(self.items) + "</g>"
                + f'<path d="{self.rr(0, 0, PW, PH, 55)}" fill="none" stroke="{t["frame"]}" stroke-width="2"/>')


def home(theme):
    s = Screen(theme, f"home-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    # Toolbar: системная стеклянная кнопка настроек.
    s.glass(s.capsule(329, 58, 44, 44))
    s.icon("gear", 351, 80)
    s.text(20, 142, "Tally", 34, 700)

    # Bit и его реплика (контент, без стекла).
    s.raw(bit("idle", theme, 64, 222, 0.3))
    s.card(s.rr(120, 178, 253, 82, 22))
    s.text(138, 210, "Слабое место: разный низ.", 16, 600)
    s.text(138, 238, "Начнём с него?", 15, 400, t["sub"])

    s.text(20, 300, "РЕЖИМ", 13, 600, t["sub"])
    s.glass(s.capsule(20, 312, 353, 52))
    sel = s.capsule(25, 317, 108, 42)
    s.raw(f'<path d="{sel}" fill="{t["prom_fill"]}"/>')
    s.text(79, 344, "Умножение", 15, 600, t["prom_text"], "middle")
    s.text(195, 344, "Дроби", 15, 500, anchor="middle")
    s.text(307, 344, "Вперемешку", 15, 500, anchor="middle")

    s.text(20, 398, "СТОЛБИКИ", 13, 600, t["sub"])
    s.text(373, 398, "Все", 15, 500, t["ink"], "end")
    chosen = {2, 3, 6, 7, 8}
    cw = (353 - 30) / 4
    for i, n in enumerate(range(2, 10)):
        x = 20 + (i % 4) * (cw + 10)
        y = 410 + (i // 4) * 62
        d = s.rr(x, y, cw, 52, 18)
        on = n in chosen
        s.glass(d, prominent=on)
        s.text(x + cw / 2, y + 35, str(n), 24, 600, t["prom_text"] if on else t["ink"], "middle")

    s.text(20, 566, "СЕГОДНЯ", 13, 600, t["sub"])
    tw = (353 - 20) / 3
    for i, (v, cap) in enumerate((("128", "решено"), ("86%", "точность"), ("5", "серия"))):
        x = 20 + i * (tw + 10)
        s.card(s.rr(x, 578, tw, 84, 22))
        s.text(x + 16, 620, v, 30, 700)
        s.text(x + 16, 645, cap, 14, 400, t["sub"])

    s.glass(s.capsule(20, 684, 353, 58), prominent=True)
    s.text(206, 719, "Начать · 10 примеров", 18, 600, t["prom_text"], "middle")

    # Tab bar iOS 26: плавающая стеклянная капсула.
    s.glass(s.capsule(56, 762, 281, 62))
    s.raw(f'<path d="{s.capsule(62, 768, 136, 50)}" fill="{t["ink"]}" fill-opacity="0.09"/>')
    s.icon("grid", 130, 784, 0.95)
    s.text(130, 810, "Тренировка", 11, 600, anchor="middle")
    s.icon("chart", 266, 784, 0.95, t["sub"])
    s.text(266, 810, "Статистика", 11, 500, t["sub"], "middle")
    s.home_indicator()
    return s


def answer_fields(s, x0, y0, whole, num, den, active):
    """Поля ответа: целая часть, числитель, знаменатель. Активное — толще рамка и заливка."""
    t = s.t
    fields = {"whole": (x0, y0 + 36, 66, 84, whole), "num": (x0 + 82, y0, 74, 66, num),
              "den": (x0 + 82, y0 + 90, 74, 66, den)}
    for key, (x, y, w, h, v) in fields.items():
        d = s.rr(x, y, w, h, 18)
        if key == active:
            s.raw(f'<path d="{d}" fill="{t["card"]}" fill-opacity="0.95" stroke="{t["ink"]}" stroke-width="2.5"/>')
        else:
            s.raw(f'<path d="{d}" fill="{t["card"]}" fill-opacity="{t["card_op"]*0.7}" stroke="{t["ink"]}" stroke-opacity="0.18" stroke-width="1.2"/>')
        if v:
            s.text(x + w / 2, y + h / 2 + 14, v, 40, 700, anchor="middle")
        if key == active:
            cx = x + w / 2 + (14 if v else 0)
            s.raw(f'<rect x="{cx-1.2}" y="{y+16}" width="2.4" height="{h-32}" rx="1.2" fill="{t["ink"]}"/>')
    s.raw(f'<path d="M{x0+86} {y0+78} L{x0+152} {y0+78}" stroke="{t["ink"]}" stroke-width="3" stroke-linecap="round"/>')
    s.text(x0 + 33, y0 + 142, "целая", 12, 500, t["sub"], "middle")


def training_top(s, label, done):
    t = s.t
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("xmark", 42, 80)
    s.text(196.5, 86, f"{done + 1} из 10", 17, 600, anchor="middle")
    s.glass(s.capsule(303, 58, 70, 44))
    s.text(338, 86, "Серия 4", 13, 600, anchor="middle")
    seg = (353 - 9 * 5) / 10
    for i in range(10):
        x = 20 + i * (seg + 5)
        if i < done:
            s.raw(f'<rect x="{x}" y="116" width="{seg}" height="5" rx="2.5" fill="{t["ink"]}"/>')
        else:
            s.raw(f'<rect x="{x}" y="116" width="{seg}" height="5" rx="2.5" fill="{t["ink"]}" fill-opacity="{0.45 if i == done else 0.12}"/>')
    s.text(196.5, 158, label, 15, 500, t["sub"], "middle")


def problem(s, y):
    s.frac(104, y, "1", "3")
    s.text(158, y + 62, "+", 40, 500, anchor="middle")
    s.frac(212, y, "1", "6")
    s.text(270, y + 62, "=", 40, 500, anchor="middle")
    s.text(320, y + 64, "?", 44, 700, s.t["faint"], "middle")


def training(theme):
    s = Screen(theme, f"train-{theme}")
    t = s.t
    s.background()
    training_top(s, "Сложение с разным низом", 2)
    problem(s, 182)

    s.raw(bit("waiting", theme, 70, 410, 0.27))
    answer_fields(s, 168, 316, "", "3", "", "den")

    # Своя клавиатура: группа стеклянных клавиш в одном контейнере.
    kw, kh, g = (353 - 20) / 3, 50, 8
    keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "updown", "0", "delete"]
    for i, k in enumerate(keys):
        x = 20 + (i % 3) * (kw + 10)
        y = 520 + (i // 3) * (kh + g)
        s.glass(s.rr(x, y, kw, kh, 18))
        if k.isdigit():
            s.text(x + kw / 2, y + 34, k, 26, 500, anchor="middle")
        else:
            s.icon(k, x + kw / 2, y + kh / 2, 1.05)
    s.glass(s.capsule(20, 758, 222, 56), prominent=True)
    s.icon("check", 74, 786, 1.0, t["prom_text"], 2.6)
    s.text(140, 792, "Проверить", 18, 600, t["prom_text"], "middle")
    s.glass(s.capsule(252, 758, 121, 56))
    s.text(312, 792, "Дальше", 18, 600, t["sub"], "middle", 0.6)
    s.home_indicator()
    return s


def review(theme):
    s = Screen(theme, f"review-{theme}")
    t = s.t
    s.background()
    training_top(s, "Сложение с разным низом", 2)

    # Строка примера с ответом пользователя.
    s.frac(60, 178, "1", "3", 30)
    s.text(96, 222, "+", 28, 500, anchor="middle")
    s.frac(132, 178, "1", "6", 30)
    s.text(170, 222, "=", 28, 500, anchor="middle")
    s.frac(212, 178, "2", "9", 30, t["sub"])
    s.raw(f'<path d="M190 236 L234 196" stroke="{t["ink"]}" stroke-width="2.5" stroke-linecap="round"/>')
    # Реакция без цвета: значок и инверсия заливки.
    s.raw(f'<path d="{s.capsule(258, 196, 115, 40)}" fill="{t["prom_fill"]}"/>')
    s.icon("xmark", 280, 216, 0.75, t["prom_text"], 2.8)
    s.text(326, 222, "Неверно", 15, 600, t["prom_text"], "middle")

    s.raw(bit("hint", theme, 58, 318, 0.26))
    s.card(s.rr(116, 286, 257, 60, 20))
    s.text(134, 312, "Низ не складываем.", 16, 600)
    s.text(134, 333, "Смотри шаги ниже.", 14, 400, t["sub"])

    s.card(s.rr(20, 362, 353, 330, 26))
    steps = [
        ("Делаем низы одинаковыми.", "6 делится на 3: умножаем 3 на 2."),
        ("Умножаем и верх, и низ на 2.", "1/3 = 2/6"),
        ("Складываем верхи, низ оставляем.", "2/6 + 1/6 = 3/6"),
        ("Сокращаем: делим верх и низ на 3.", "3/6 = 1/2"),
    ]
    for i, (a, b) in enumerate(steps):
        y = 392 + i * 66
        s.raw(f'<circle cx="50" cy="{y+4}" r="13" fill="{t["ink"]}"/>')
        s.text(50, y + 9.5, str(i + 1), 14, 700, t["bg"], "middle")
        s.text(76, y + 9, a, 15.5, 600)
        s.text(76, y + 33, b, 15.5, 500, t["sub"])
    s.raw(f'<path d="M40 650 L353 650" stroke="{t["ink"]}" stroke-opacity="0.1"/>')
    s.text(40, 676, "Ответ", 15, 500, t["sub"])
    s.text(353, 678, "1/2", 22, 700, anchor="end")

    s.glass(s.capsule(20, 716, 353, 56), prominent=True)
    s.text(188, 750, "Дальше", 18, 600, t["prom_text"], "middle")
    s.icon("arrow.right", 240, 744, 1.0, t["prom_text"], 2.4)
    s.glass(s.capsule(120, 782, 153, 40))
    s.text(196.5, 808, "Похожий пример", 14, 600, anchor="middle")
    s.home_indicator()
    return s


def screens_sheet():
    M, GAP, HEAD = 70, 60, 130
    W = M * 2 + PW * 3 + GAP * 2
    sec_h = HEAD + PH + 90
    H = sec_h * 2
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
             "<defs>" + defs_bit("light") + defs_bit("dark") + "</defs>"]
    labels = ["Главная", "Тренировка: ввод", "Тренировка: разбор ошибки"]
    for si, theme in enumerate(("light", "dark")):
        t = THEMES[theme]
        oy = si * sec_h
        parts.append(f'<rect x="0" y="{oy}" width="{W}" height="{sec_h}" fill="{t["sheet"]}"/>')
        title = "Экраны · светлая тема" if theme == "light" else "Экраны · тёмная тема"
        parts.append(f'<text x="{M}" y="{oy+72}" font-family="{FONT}" font-size="30" font-weight="700" fill="{t["ink"]}">{title}</text>')
        for i, fn in enumerate((home, training, review)):
            x = M + i * (PW + GAP)
            parts.append(f'<text x="{x}" y="{oy+112}" font-family="{FONT}" font-size="17" font-weight="500" fill="{t["sub"]}">{labels[i]}</text>')
            parts.append(f'<g transform="translate({x} {oy+HEAD})">{fn(theme).render()}</g>')
    parts.append("</svg>")
    (OUT / "screens.svg").write_text("\n".join(parts), encoding="utf-8")


if __name__ == "__main__":
    bit_sheet()
    screens_sheet()
    print("ok")
