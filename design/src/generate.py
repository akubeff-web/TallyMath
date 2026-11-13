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
        return stroke(f"M{cx-17} {cy} Q{cx} {cy+8} {cx+17} {cy}", t)
    if mode == "happy":
        return stroke(f"M{cx-17} {cy+7} Q{cx} {cy-15} {cx+17} {cy+7}", t)
    px, py = cx + dx, cy + dy
    return (f'<circle cx="{cx}" cy="{cy}" r="22" fill="{t["eye"]}" stroke="{t["eye_ring"]}" stroke-width="3"/>'
            f'<circle cx="{px}" cy="{py}" r="10.5" fill="{t["pupil"]}"/>'
            f'<circle cx="{px+3.5}" cy="{py-3.5}" r="3" fill="#FFFFFF"/>')


def arm(d, hx, hy, t, r=13):
    return stroke(d, t) + f'<circle cx="{hx}" cy="{hy}" r="{r}" fill="{t["ink"]}"/>'


def plus(x, y, t, s=14):
    return stroke(f"M{x-s} {y} L{x+s} {y} M{x} {y-s} L{x} {y+s}", t, 4.5)


def bit(state, theme, x, y, scale=1.0):
    """Bit в одном из состояний. (x, y) — центр тела.

    Координаты сняты с образца (лист из 6 состояний), чтобы облик не «поплыл».
    """
    t = THEMES[theme]
    # Пузырь мысли, лампочка и корона: в светлой теме контур, в тёмной — светлая заливка, как в образце.
    pop = "#FFFFFF" if theme == "light" else "#EEEEEE"
    pop_ink = t["ink"] if theme == "light" else "#151515"
    back, front = [], []
    # Руки рисуем под телом, чтобы плечо пряталось за контур.
    arm_l_down = arm("M-104 5 C-135 22 -147 55 -147 92", -147, 92, t)
    arm_r_down = arm("M104 5 C135 22 147 55 147 92", 147, 92, t)
    smile = stroke("M-26 36 Q0 52 27 36", t)
    open_mouth = f'<path d="M-29 30 L29 30 Q27 60 0 60 Q-27 60 -29 30 Z" fill="{t["ink"]}"/>'

    if state in ("idle", "idle_blink"):
        back += [arm_l_down, arm_r_down]
        mode = "closed" if state == "idle_blink" else "open"
        front += [stroke("M-58 -66 L-20 -66 M18 -66 L58 -66", t),
                  eye(-38, -24, t, mode, 2, -2), eye(38, -24, t, mode, 2, -2), smile]
    elif state == "waiting":  # «Думает» в образце
        back += [arm_l_down]
        hand = (stroke("M106 52 L66 70", t) + f'<circle cx="64" cy="70" r="17" fill="{t["ink"]}"/>')
        bubble = (f'<circle cx="135" cy="-118" r="6" fill="{t["ink"]}"/>'
                  f'<circle cx="162" cy="-147" r="9" fill="{t["ink"]}"/>'
                  f'<ellipse cx="211" cy="-186" rx="50" ry="30" fill="{pop}" stroke="{t["ink"]}" stroke-width="3"/>'
                  f'<text x="211" y="-171" font-family="{FONT}" font-size="40" font-weight="700" '
                  f'fill="{pop_ink}" text-anchor="middle">?</text>')
        front += [stroke("M-58 -72 Q-38 -90 -18 -74", t), stroke("M17 -64 L59 -70", t),
                  eye(-38, -26, t, "open", 5, -6), eye(38, -24, t, "open", 5, -6),
                  stroke("M-20 49 L25 39", t), hand, bubble]
    elif state == "correct":
        back += [arm("M-104 -17 C-140 -45 -153 -85 -153 -126", -153, -126, t),
                 arm("M104 -17 C140 -45 153 -85 153 -126", 153, -126, t)]
        front += [eye(-36, -18, t, "happy"), eye(39, -18, t, "happy"), open_mouth,
                  plus(-76, -176, t), plus(83, -193, t)]
    elif state == "wrong":
        back += [arm_l_down, arm("M106 -13 C140 -45 142 -95 88 -130", 88, -130, t)]
        front += [stroke("M-58 -59 L-18 -75", t), stroke("M18 -75 L58 -59", t),
                  eye(-37, -23, t, "open", -6, 4), eye(38, -23, t, "open", -6, 4),
                  stroke("M-25 47 C-17 37 -9 37 0 45 C9 53 17 53 25 43", t),
                  f'<text x="-147" y="-122" font-family="{FONT}" font-size="54" font-weight="700" '
                  f'fill="{t["ink"]}" text-anchor="middle">?</text>']
    elif state == "hint":
        back += [arm_l_down]
        # Рука-указка поверх тела: кисть на середине, линия идёт дальше к карточке подсказки.
        pointer = (stroke("M106 22 L229 -15", t) + f'<circle cx="184" cy="-1" r="13" fill="{t["ink"]}"/>')
        bfill = pop if theme == "dark" else "none"
        bulb = (f'<circle cx="-136" cy="-160" r="21" fill="{bfill}" stroke="{t["ink"]}" stroke-width="3.5"/>'
                + stroke("M-147 -131 L-125 -131 M-145 -123 L-127 -123", t, 3.5)
                + stroke("M-136 -197 L-136 -208 M-166 -181 L-176 -187 M-106 -181 L-96 -187", t, 3.5))
        front += [stroke("M-58 -64 L-18 -64", t), stroke("M19 -76 Q39 -92 59 -76", t),
                  eye(-38, -25, t, "open", 8, 0), eye(39, -25, t, "open", 8, 0),
                  stroke("M-20 37 Q4 52 29 34", t), pointer, bulb]
    elif state == "streak":
        back += [arm("M-104 -18 C-140 -40 -164 -80 -164 -126", -164, -126, t),
                 arm("M104 -18 C140 -40 165 -80 165 -126", 165, -126, t)]
        crown = (f'<path d="M-31 -110 L-31 -144 L-15 -128 L0 -153 L15 -128 L32 -144 L32 -110 Z" '
                 f'fill="{pop if theme == "dark" else t["ink"]}" stroke-linejoin="round"/>')
        front += [stroke("M-59 -74 Q-40 -88 -21 -74 M19 -74 Q38 -88 59 -74", t),
                  eye(-37, -26, t, "open", 0, -2), eye(38, -26, t, "open", 0, -2), open_mouth,
                  crown, plus(-88, -186, t), plus(94, -200, t, 13), plus(71, -148, t, 10)]

    body = (f'<path d="{BODY}" fill="url(#body-{theme})" stroke="{t["outline"]}" stroke-width="3"/>'
            + stroke("M-88 -46 C-88 -60 -82 -70 -70 -73", t, 3.5, f'stroke-opacity="0.85"'))
    return (f'<g transform="translate({x} {y}) scale({scale})">'
            + "".join(back) + body + "".join(front) + "</g>")


def bit_sheet():
    W, CW, CH, HEAD = 1440, 480, 470, 120
    # Порядок и названия как в образце; в скобках — состояние в коде.
    states = [
        ("idle", "Обычный", "idle · моргает, покачивается"),
        ("waiting", "Думает", "waiting · ждёт ответ"),
        ("correct", "Верно", "correct · «Верно.»"),
        ("wrong", "Ошибка", "wrong · «Почти. Смотри шаги ниже.»"),
        ("hint", "Подсказка", "hint · показывает на подсказку"),
        ("streak", "Серия", "streak · «Серия: 5»"),
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
            shift = {"hint": -40, "waiting": -40}.get(st, 0)
            parts.append(bit(st, theme, cx + shift, cy, 0.9))
            if st == "idle":
                # Кадр моргания рядом, чтобы было видно анимацию.
                parts.append(bit("idle_blink", theme, cx + 160, cy - 150, 0.28))
                parts.append(f'<text x="{cx+160}" y="{cy-96}" font-family="{FONT}" font-size="14" fill="{t["sub"]}" text-anchor="middle">кадр моргания</text>')
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
            "pencil": f'<path d="M-8 8 L-7 3 L5 -9 L9 -5 L-3 7 Z M2 -6 L6 -2" {st}/>',
            "plus": f'<path d="M-7 0 L7 0 M0 -7 L0 7" {st}/>',
            "link": f'<path d="M-5 5 L6 -6 M-1 -6 L6 -6 L6 1" {st}/>',
            "book": f'<path d="M0 -6 C-4 -9 -8 -9 -10 -8 L-10 8 C-8 7 -4 7 0 9 C4 7 8 7 10 8 L10 -8 C8 -9 4 -9 0 -6 Z M0 -6 L0 9" {st}/>',
            "undo": f'<path d="M-7 -2 L-2 -7 M-7 -2 L-2 3 M-7 -2 L3 -2 C7 -2 9 1 9 4 C9 7 7 9 3 9" {st}/>',
            "redo": f'<path d="M7 -2 L2 -7 M7 -2 L2 3 M7 -2 L-3 -2 C-7 -2 -9 1 -9 4 C-9 7 -7 9 -3 9" {st}/>',
            "trash": f'<path d="M-8 -6 L8 -6 M-3 -6 L-3 -9 L3 -9 L3 -6 M-6 -6 L-5 9 L5 9 L6 -6" {st}/>',
            "eye": f'<path d="M-10 0 C-6 -7 6 -7 10 0 C6 7 -6 7 -10 0 Z" {st}/><circle r="3" fill="{c}"/>',
            "chevron.down": f'<path d="M-7 -3 L0 4 L7 -3" {st}/>',
            "chevron.up": f'<path d="M-7 3 L0 -4 L7 3" {st}/>',
            "question": f'<circle r="11" {st} stroke-dasharray="3 3"/><path d="M-3.5 -3 C-3.5 -7 3.5 -7 3.5 -3 C3.5 0 0 0 0 3" {st}/><circle cy="7" r="1.4" fill="{c}"/>',
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
    # Toolbar: «Свой пример» и настройки.
    s.glass(s.capsule(190, 58, 129, 44))
    s.icon("plus", 210, 80, 0.85)
    s.text(264, 85, "Свой пример", 14, 600, anchor="middle")
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
    s.raw(f'<path d="{s.capsule(140, 317, 110, 42)}" fill="{t["prom_fill"]}"/>')
    s.text(79, 344, "Умножение", 15, 500, anchor="middle")
    s.text(195, 344, "Дроби", 15, 600, t["prom_text"], "middle")
    s.text(307, 344, "Вперемешку", 15, 500, anchor="middle")

    s.text(20, 396, "ТЕМЫ", 13, 600, t["sub"])
    s.text(373, 396, "128 решено · 86% · серия 5", 13, 500, t["sub"], "end")
    s.card(s.rr(20, 408, 353, 262, 26))
    topics = [("Одинаковый низ", "92%", True, False), ("Разный низ", "54%", True, True),
              ("Вычитание", "81%", True, False), ("Сокращение", "77%", False, False),
              ("Целая часть", "—", False, False)]
    for i, (name, acc, on, weak) in enumerate(topics):
        y = 408 + i * 52
        if i:
            s.raw(f'<path d="M64 {y} L353 {y}" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
        # Тема включена в тренировку: заполненный кружок с галочкой.
        if on:
            s.raw(f'<circle cx="42" cy="{y+26}" r="11" fill="{t["ink"]}"/>')
            s.icon("check", 42, y + 26, 0.62, t["bg"], 3)
        else:
            s.raw(f'<circle cx="42" cy="{y+26}" r="10.5" fill="none" stroke="{t["ink"]}" stroke-opacity="0.35" stroke-width="1.6"/>')
        s.text(64, y + 24, name, 16, 600)
        s.text(64, y + 42, f"точность {acc}", 12.5, 400, t["sub"])
        if weak:
            # Слабая тема: пунктирная рамка вместо цвета.
            s.raw(f'<path d="{s.capsule(196, y+12, 62, 22)}" fill="none" stroke="{t["ink"]}" stroke-width="1.4" stroke-dasharray="3 3"/>')
            s.text(227, y + 27, "слабое", 12, 600, anchor="middle")
        s.glass(s.capsule(287, y + 10, 72, 32))
        s.text(323, y + 31, "Урок", 14, 600, anchor="middle")

    s.glass(s.capsule(20, 688, 353, 58), prominent=True)
    s.text(196.5, 723, "Начать · 10 примеров", 18, 600, t["prom_text"], "middle")

    tab_bar(s, 0)
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


def training_top(s, label, done, howto=False):
    t = s.t
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("xmark", 42, 80)
    s.text(196.5, 86, f"{done + 1} из 10", 17, 600, anchor="middle")
    if howto:
        # Объяснение доступно до ответа, а не только после ошибки.
        s.glass(s.capsule(263, 58, 110, 44))
        s.icon("bulb", 285, 80, 0.85)
        s.text(332, 85, "Объясни", 14, 600, anchor="middle")
    else:
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
    training_top(s, "Сложение с разным низом", 2, howto=True)
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
    s.text(134, 333, "Уровень 1 · смотри шаги ниже.", 14, 400, t["sub"])

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

    understood_buttons(s, 716)
    s.text(196.5, 800, "«Не понял» — объясню подробнее, со стрелками", 13, 400, t["sub"], "middle")
    s.home_indicator()
    return s



def understood_buttons(s, y):
    t = s.t
    s.glass(s.capsule(20, y, 160, 56))
    s.text(100, y + 34, "Не понял", 18, 600, anchor="middle")
    s.glass(s.capsule(190, y, 183, 56), prominent=True)
    s.icon("check", 238, y + 28, 1.0, t["prom_text"], 2.6)
    s.text(292, y + 34, "Понял", 18, 600, t["prom_text"], "middle")


def frac2(s, cx, top, num, den, size, ncol, dcol, weight=700):
    """Дробь, где верх и низ можно подсветить по-разному."""
    s.text(cx, top + size * 0.82, num, size, weight, ncol, "middle")
    ly = top + size + 6
    w = max(len(num), len(den)) * size * 0.62 + 10
    s.raw(f'<path d="M{cx-w/2} {ly} L{cx+w/2} {ly}" stroke="{s.t["ink"]}" stroke-width="{size/14:.1f}" stroke-linecap="round"/>')
    s.text(cx, ly + 6 + size * 0.82, den, size, weight, dcol, "middle")
    return dict(num_y=top + size * 0.46, line_y=ly, den_y=ly + 6 + size * 0.46)


def arrow(s, x1, x2, y, label):
    """Горизонтальная стрелка с меткой действия посередине (например «× 2»)."""
    t = s.t
    s.raw(f'<path d="M{x1} {y} L{x2} {y} M{x2-8} {y-6} L{x2} {y} L{x2-8} {y+6}" fill="none" '
          f'stroke="{t["ink"]}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    mx = (x1 + x2) / 2
    s.raw(f'<path d="{s.capsule(mx-26, y-13, 52, 26)}" fill="{t["prom_fill"]}"/>')
    s.text(mx, y + 6, label, 15, 700, t["prom_text"], "middle")


def detail_switch(s, active):
    """Уровни подробности объяснения: можно переключать вручную."""
    t = s.t
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(196.5, 86, "Как решать", 17, 600, anchor="middle")
    s.glass(s.capsule(20, 114, 353, 40))
    labels = ["Кратко", "Подробно", "Сам"]
    w = (353 - 8) / 3
    for i, lab in enumerate(labels):
        x = 24 + i * w
        if i == active:
            s.raw(f'<path d="{s.capsule(x, 118, w, 32)}" fill="{t["prom_fill"]}"/>')
        s.text(x + w / 2, 139, lab, 14, 600, t["prom_text"] if i == active else t["ink"], "middle")


def numbered(s, x, y, n):
    t = s.t
    s.raw(f'<circle cx="{x}" cy="{y}" r="13" fill="{t["ink"]}"/>')
    s.text(x, y + 5.5, str(n), 14, 700, t["bg"], "middle")


def keypad(s, y0, kh=44, g=7):
    kw = (353 - 20) / 3
    keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "updown", "0", "delete"]
    for i, k in enumerate(keys):
        x = 20 + (i % 3) * (kw + 10)
        y = y0 + (i // 3) * (kh + g)
        s.glass(s.rr(x, y, kw, kh, 16))
        if k.isdigit():
            s.text(x + kw / 2, y + kh / 2 + 9, k, 24, 500, anchor="middle")
        else:
            s.icon(k, x + kw / 2, y + kh / 2, 1.0)


def frac_w(num, den, size):
    return max(len(num), len(den)) * size * 0.62 + 10


def chain(s, x0, top, items, size=24, invert_last=True):
    """Цепочка решения одной строкой. items: ("f", верх, низ) или ("o", знак).
    Возвращает центры дробей по индексам, чтобы к ним можно было подвести стрелки."""
    t = s.t
    x, centers = x0, {}
    for i, it in enumerate(items):
        if it[0] == "f":
            w = frac_w(it[1], it[2], size)
            cx = x + w / 2
            last = invert_last and i == len(items) - 1
            if last:
                s.raw(f'<path d="{s.rr(x-4, top-6, w+8, size*2+22, 12)}" fill="{t["prom_fill"]}"/>')
            c = t["prom_text"] if last else t["ink"]
            frac2(s, cx, top, it[1], it[2], size, c, c)
            centers[i] = cx
            x += w + 5
        else:
            ow = max(20, size * 0.75)
            s.text(x + ow / 2, top + size + 14, it[1], size * 0.9, 500, t["ink"], "middle")
            x += ow + 5
    return centers


def arc(s, x1, x2, y, label, up=True, h=16):
    """Дуга-стрелка между дробями цепочки с меткой действия («× 2»)."""
    t = s.t
    k = -1 if up else 1
    mx = (x1 + x2) / 2
    cy = y + k * 2 * h
    # Наконечник по касательной в конце квадратичной кривой.
    dx, dy = x2 - mx, y - cy
    n = (dx * dx + dy * dy) ** 0.5
    ux, uy = dx / n, dy / n
    import math
    pts = []
    for ang in (0.5, -0.5):
        ca, sa = math.cos(ang), math.sin(ang)
        pts.append((x2 - 8 * (ux * ca - uy * sa), y - 8 * (ux * sa + uy * ca)))
    s.raw(f'<path d="M{x1} {y} Q{mx} {cy} {x2} {y} M{pts[0][0]:.1f} {pts[0][1]:.1f} L{x2} {y} L{pts[1][0]:.1f} {pts[1][1]:.1f}" '
          f'fill="none" stroke="{t["ink"]}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>')
    by = y + k * h
    s.raw(f'<path d="{s.capsule(mx-20, by-11, 40, 22)}" fill="{t["prom_fill"]}"/>')
    s.text(mx, by + 4.5, label, 12.5, 700, t["prom_text"], "middle")


def fade_bottom(s, y=700):
    t = s.t
    gid = s.uid("fade")
    s.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
                  f'<stop offset="0" stop-color="{t["base"]}" stop-opacity="0"/>'
                  f'<stop offset="0.45" stop-color="{t["base"]}" stop-opacity="0.85"/>'
                  f'<stop offset="1" stop-color="{t["base"]}" stop-opacity="1"/></linearGradient>')
    s.raw(f'<rect x="0" y="{y}" width="{PW}" height="{PH-y}" fill="url(#{gid})"/>')


def correct(theme):
    s = Screen(theme, f"correct-{theme}")
    t = s.t
    s.background()
    training_top(s, "Сложение с разным низом", 2)
    chain(s, 104, 180, [("f", "1", "3"), ("o", "+"), ("f", "1", "6"), ("o", "="), ("f", "1", "2")], 36)
    # Верный ответ: инверсия и значок, без цвета.
    s.raw(f'<path d="{s.capsule(140, 292, 113, 40)}" fill="{t["prom_fill"]}"/>')
    s.icon("check", 164, 312, 0.85, t["prom_text"], 2.8)
    s.text(206, 318, "Верно", 16, 600, t["prom_text"], "middle")

    s.raw(bit("correct", theme, 120, 452, 0.42))
    s.card(s.rr(212, 410, 161, 64, 22))
    s.text(230, 438, "Верно.", 18, 700)
    s.text(230, 460, "Серия: 5", 14, 500, t["sub"])

    s.glass(s.capsule(20, 556, 353, 52))
    s.icon("bulb", 50, 582, 0.9)
    s.text(70, 588, "Как решать правильно", 16, 600)
    s.icon("chevron.left", 352, 582, 0.7)  # перевёрнут ниже
    s.items[-1] = s.items[-1].replace("scale(0.7)", "scale(-0.7 0.7)")
    s.glass(s.capsule(20, 620, 171, 52))
    s.text(105.5, 652, "Похожий пример", 15, 600, anchor="middle")
    s.glass(s.capsule(202, 620, 171, 52))
    s.text(287.5, 652, "Полное решение", 15, 600, anchor="middle")

    s.glass(s.capsule(20, 760, 353, 56), prominent=True)
    s.text(188, 794, "Дальше", 18, 600, t["prom_text"], "middle")
    s.icon("arrow.right", 240, 788, 1.0, t["prom_text"], 2.4)
    s.home_indicator()
    return s


def lesson_topic(theme):
    s = Screen(theme, f"topic-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(196.5, 86, "Урок", 17, 600, anchor="middle")
    s.glass(s.capsule(266, 58, 107, 44))
    s.text(319.5, 85, "Ещё пример", 14, 600, anchor="middle")

    s.text(20, 146, "Сложение с разным низом", 22, 700)
    s.text(20, 168, "Дроби · правило и два примера", 14, 400, t["sub"])

    s.card(s.rr(20, 184, 353, 132, 26))
    s.text(40, 208, "ПРАВИЛО", 12, 600, t["sub"])
    for i, line in enumerate(["Низы разные — сначала сделай их",
                              "одинаковыми: умножь верх и низ",
                              "дроби на одно число. Потом сложи",
                              "верхи, низ оставь, сократи."]):
        s.text(40, 234 + i * 22, line, 15.5, 600)
    s.raw(bit("idle", theme, 350, 150, 0.15))

    s.card(s.rr(20, 328, 353, 168, 26))
    s.text(40, 352, "Пример 1 · 6 делится на 3", 13, 600, t["sub"])
    items = [("f", "1", "3"), ("o", "+"), ("f", "1", "6"), ("o", "="), ("f", "2", "6"), ("o", "+"),
             ("f", "1", "6"), ("o", "="), ("f", "3", "6"), ("o", "="), ("f", "1", "2")]
    c = chain(s, 44, 396, items)
    arc(s, c[0], c[4], 390, "× 2")
    s.text(40, 482, "6 : 3 = 2, умножаем 1/3 на 2. В конце ÷ 3.", 13.5, 500, t["sub"])

    s.card(s.rr(20, 508, 353, 196, 26))
    s.text(40, 532, "Пример 2 · общий случай", 13, 600, t["sub"])
    items = [("f", "1", "4"), ("o", "+"), ("f", "1", "6"), ("o", "="), ("f", "3", "12"), ("o", "+"),
             ("f", "2", "12"), ("o", "="), ("f", "5", "12")]
    c = chain(s, 52, 576, items)
    arc(s, c[0], c[4], 570, "× 3")
    arc(s, c[2], c[6], 640, "× 2", up=False)
    s.text(40, 690, "Общий низ 12: делится и на 4, и на 6.", 13.5, 500, t["sub"])

    understood_buttons(s, 760)
    s.home_indicator()
    return s


def level2(theme):
    s = Screen(theme, f"lvl2-{theme}")
    t = s.t
    s.background()
    detail_switch(s, 1)

    s.raw(bit("hint", theme, 50, 196, 0.2))
    s.card(s.rr(104, 170, 269, 52, 20))
    s.text(120, 202, "Множитель берём из низов.", 15.5, 600)

    s.text(20, 252, "Шаг 2 из 4", 15, 600)
    for i in range(4):
        s.raw(f'<rect x="{293 + i * 21}" y="244" width="16" height="6" rx="3" fill="{t["ink"]}" fill-opacity="{1 if i <= 1 else 0.15}"/>')

    s.card(s.rr(20, 264, 353, 394, 26))
    s.text(40, 296, "Умножаем и верх, и низ на 2", 17, 700)
    a = frac2(s, 100, 316, "1", "3", 56, t["ink"], t["ink"])
    frac2(s, 292, 316, "2", "6", 56, t["ink"], t["ink"])
    # Рамка: какое число во что превратилось.
    for y in (a["num_y"], a["den_y"]):
        s.raw(f'<path d="{s.rr(262, y-32, 60, 62, 14)}" fill="none" stroke="{t["ink"]}" stroke-width="2.4"/>')
    arrow(s, 134, 254, a["num_y"], "× 2")
    arrow(s, 134, 254, a["den_y"], "× 2")

    s.raw(f'<path d="{s.rr(40, 456, 313, 62, 18)}" fill="{t["prom_fill"]}"/>')
    s.text(58, 480, "Откуда 2", 13, 500, t["prom_text"], op=0.7)
    s.text(58, 505, "6 ÷ 3 = 2, значит × 2", 20, 700, t["prom_text"])

    s.icon("xcircle", 52, 545, 0.8)
    s.text(72, 550, "Почему не × 3?", 15, 600)
    s.text(72, 571, "Низ стал бы 9, а нужен 6.", 14, 500, t["sub"])
    s.icon("check", 52, 605, 0.9, w=2.6)
    s.text(72, 610, "Проверка", 15, 600)
    s.text(72, 631, "2/6 ÷ 2 = 1/3 — та же дробь.", 14, 500, t["sub"])

    s.glass(s.capsule(20, 672, 120, 42))
    s.icon("chevron.left", 44, 693, 0.7)
    s.text(90, 698, "Шаг 1", 15, 600, anchor="middle")
    s.glass(s.capsule(253, 672, 120, 42))
    s.text(301, 698, "Шаг 3", 15, 600, anchor="middle")
    s.icon("chevron.left", 350, 693, 0.7)
    s.items[-1] = s.items[-1].replace("scale(0.7)", "scale(-0.7 0.7)")

    understood_buttons(s, 760)
    s.home_indicator()
    return s


def level3(theme):
    s = Screen(theme, f"lvl3-{theme}")
    t = s.t
    s.background()
    detail_switch(s, 2)

    s.text(20, 186, "Попроще: 1/2 + 1/4", 15, 600)
    s.text(373, 186, "Шаг 2 из 4", 13, 500, t["sub"], "end")

    s.card(s.rr(20, 200, 353, 236, 26))
    a = frac2(s, 100, 222, "1", "2", 44, t["ink"], t["ink"])
    # Множитель уже введён на шаге 1 — показан в метке стрелки.
    arrow(s, 132, 254, a["num_y"], "× 2")
    arrow(s, 132, 254, a["den_y"], "× 2")
    ly = a["line_y"]
    s.raw(f'<path d="{s.rr(262, 216, 58, 52, 14)}" fill="{t["card"]}" fill-opacity="0.95" stroke="{t["ink"]}" stroke-width="2.5"/>')
    s.raw(f'<rect x="289.8" y="228" width="2.4" height="28" rx="1.2" fill="{t["ink"]}"/>')
    s.raw(f'<path d="M266 {ly} L316 {ly}" stroke="{t["ink"]}" stroke-width="3.1" stroke-linecap="round"/>')
    s.text(291, ly + 6 + 36, "4", 44, 700, anchor="middle")
    s.text(196.5, 380, "Низ уже 4. Верх тоже умножь на 2.", 16, 600, anchor="middle")
    s.text(196.5, 406, "1 × 2 = ?", 16, 500, t["sub"], "middle")

    s.raw(bit("hint", theme, 50, 476, 0.2))
    s.card(s.rr(104, 450, 150, 56, 20))
    s.text(120, 474, "Твой ход.", 15.5, 600)
    s.text(120, 494, "Введи новый верх.", 13.5, 400, t["sub"])
    s.glass(s.capsule(264, 456, 109, 44))
    s.icon("bulb", 282, 478, 0.85)
    s.text(336, 483, "Подсказка", 13, 600, anchor="middle")

    keypad(s, 526)
    s.glass(s.capsule(20, 764, 353, 52), prominent=True)
    s.icon("check", 124, 790, 1.0, t["prom_text"], 2.6)
    s.text(206, 796, "Проверить шаг", 17, 600, t["prom_text"], "middle")
    s.home_indicator()
    return s


def full_solution(theme):
    s = Screen(theme, f"full-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.raw(f'<rect width="{PW}" height="{PH}" fill="#000" fill-opacity="{0.18 if theme == "light" else 0.4}"/>')
    sheet_d = (f"M0 {150} Q0 110 40 110 L{PW-40} 110 Q{PW} 110 {PW} 150 L{PW} {PH} L0 {PH} Z")
    s.glass(sheet_d)
    s.card(sheet_d)
    s.raw(f'<rect x="{PW/2-18}" y="118" width="36" height="5" rx="2.5" fill="{t["ink"]}" fill-opacity="0.25"/>')
    s.raw(bit("hint", theme, 44, 160, 0.16))
    s.text(94, 166, "Полное решение", 19, 700)
    s.glass(s.capsule(329, 138, 44, 44))
    s.icon("xmark", 351, 160, 0.9)

    rows = [
        ("", [("f", "1", "3"), ("o", "+"), ("f", "1", "6")], "Низы разные: 3 и 6", "Общий низ — 6."),
        ("× 2", [("f", "2", "6"), ("o", "+"), ("f", "1", "6")], "1/3 → 2/6", "6 ÷ 3 = 2, верх и низ × 2"),
        ("+", [("f", "3", "6")], "Сложили верхи", "2 + 1 = 3, низ 6 тот же"),
        ("÷ 3", [("f", "1", "2")], "Сократили", "3 ÷ 3 = 1, 6 ÷ 3 = 2."),
    ]
    for i, (op, items, a, b) in enumerate(rows):
        top = 204 + i * 118
        if i:
            s.text(40, top + 40, "=", 26, 500, anchor="middle")
            # Вертикальная стрелка от предыдущей строки с действием.
            y1, y2 = top - 40, top - 4
            s.raw(f'<path d="M84 {y1} L84 {y2} M78 {y2-7} L84 {y2} L90 {y2-7}" fill="none" stroke="{t["ink"]}" '
                  f'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')
            s.raw(f'<path d="{s.capsule(100, (y1+y2)/2-11, 44, 22)}" fill="{t["prom_fill"]}"/>')
            s.text(122, (y1 + y2) / 2 + 4.5, op, 12.5, 700, t["prom_text"], "middle")
        chain(s, 66, top, items, 30, invert_last=(i == 3))
        s.text(214, top + 32, a, 15, 600)
        s.text(214, top + 54, b, 13.5, 500, t["sub"])

    s.raw(f'<path d="M40 676 L353 676" stroke="{t["ink"]}" stroke-opacity="0.1"/>')
    s.icon("check", 50, 702, 0.9, w=2.6)
    s.text(70, 707, "Проверка: 1/2 = 3/6 = 2/6 + 1/6", 14, 500, t["sub"])
    understood_buttons(s, 760)
    s.home_indicator()
    return s


def learning_sheet():
    sheet([lesson_topic, level2, level3, full_solution],
          ["Урок темы: правило и 2 примера", "Уровень 2: по шагу, стрелки и «почему»",
           "Уровень 3: попроще, вводишь сам", "Полное решение со стрелками"],
          "Обучение", "screens-learning.svg")


def tab_bar(s, active):
    """Плавающий стеклянный таб-бар iOS 26: Тренировка, Курс, Статистика."""
    t = s.t
    s.glass(s.capsule(36, 762, 321, 62))
    tabs = [("grid", "Тренировка"), ("book", "Курс"), ("chart", "Статистика")]
    for i, (ic, lab) in enumerate(tabs):
        cx = 92 + i * 104.5
        if i == active:
            s.raw(f'<path d="{s.capsule(cx-48, 768, 96, 50)}" fill="{t["ink"]}" fill-opacity="0.09"/>')
        c = t["ink"] if i == active else t["sub"]
        s.icon(ic, cx, 784, 0.95, c)
        s.text(cx, 810, lab, 11, 600 if i == active else 500, c, "middle")


def error_rate(a, b):
    """Доля ошибок по факту таблицы: тестовые данные для макета."""
    hard = {(7, 8): .62, (6, 9): .55, (8, 6): .48, (7, 6): .41, (9, 7): .44, (8, 7): .5, (6, 7): .35, (9, 8): .3}
    k = (max(a, b), min(a, b)) if (max(a, b), min(a, b)) in hard else (a, b)
    if (a, b) in hard:
        return hard[(a, b)]
    if (b, a) in hard:
        return hard[(b, a)] * 0.9
    return ((a * 7 + b * 13) % 10) / 100 + (0.08 if a + b > 13 else 0)


def stats_tab(theme):
    s = Screen(theme, f"stats-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.text(20, 142, "Статистика", 34, 700)

    s.glass(s.capsule(20, 160, 353, 38))
    w = (353 - 8) / 3
    for i, lab in enumerate(["Неделя", "Месяц", "Всё время"]):
        x = 24 + i * w
        if i == 0:
            s.raw(f'<path d="{s.capsule(x, 164, w, 30)}" fill="{t["prom_fill"]}"/>')
        s.text(x + w / 2, 184, lab, 14, 600, t["prom_text"] if i == 0 else t["ink"], "middle")

    tw = (353 - 20) / 3
    for i, (v, cap) in enumerate((("128", "решено"), ("86%", "точность"), ("12", "лучшая серия"))):
        x = 20 + i * (tw + 10)
        s.card(s.rr(x, 210, tw, 76, 22))
        s.text(x + 14, 248, v, 28, 700)
        s.text(x + 14, 272, cap, 13, 400, t["sub"])

    # Тепловая карта: один оттенок, темнее — больше ошибок.
    s.card(s.rr(20, 298, 353, 316, 26))
    s.text(40, 324, "Таблица умножения", 16, 600)
    s.text(40, 343, ("темнее" if theme == "light" else "светлее") + " — больше ошибок", 12.5, 500, t["sub"])
    cell, gap = 24, 3
    gx, gy = 104, 370
    for i, n in enumerate(range(2, 10)):
        s.text(gx + i * (cell + gap) + cell / 2, gy - 6, str(n), 12, 600, t["sub"], "middle")
        s.text(gx - 12, gy + i * (cell + gap) + cell / 2 + 4, str(n), 12, 600, t["sub"], "middle")
    for r, a in enumerate(range(2, 10)):
        for c, b in enumerate(range(2, 10)):
            e = error_rate(a, b)
            x, y = gx + c * (cell + gap), gy + r * (cell + gap)
            op = 0.06 + min(e, 0.65) / 0.65 * 0.94
            s.raw(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="7" fill="{t["ink"]}" fill-opacity="{op:.2f}"/>')
            if e >= 0.4:
                s.text(x + cell / 2, y + cell / 2 + 3.5, str(a * b), 10, 700, t["bg"], "middle")
    # Подпись самого слабого факта — прямо на данных, без легенды.
    s.text(40, 600, "Слабее всего: 7 × 8, 6 × 9, 8 × 7", 13.5, 600)

    s.card(s.rr(20, 626, 353, 220, 26))
    s.text(40, 652, "Дроби по темам", 16, 600)
    rows = [("Разный низ", .54, True), ("Сокращение", .77, False), ("Вычитание", .81, False),
            ("Одинаковый низ", .92, False)]
    for i, (name, acc, weak) in enumerate(rows):
        y = 668 + i * 44
        s.text(40, y + 16, name, 15, 600)
        if weak:
            s.raw(f'<path d="{s.capsule(140, y+2, 54, 20)}" fill="none" stroke="{t["ink"]}" stroke-width="1.3" stroke-dasharray="3 3"/>')
            s.text(167, y + 16, "слабое", 11, 600, anchor="middle")
        s.raw(f'<rect x="210" y="{y+8}" width="104" height="6" rx="3" fill="{t["ink"]}" fill-opacity="0.1"/>')
        s.raw(f'<rect x="210" y="{y+8}" width="{104*acc:.0f}" height="6" rx="3" fill="{t["ink"]}"/>')
        s.text(353, y + 16, f"{int(acc*100)}%", 14, 700, anchor="end")
        s.text(40, y + 34, "«не понял» ×3" if weak else "", 12, 500, t["sub"])

    fade_bottom(s, 712)
    tab_bar(s, 2)
    s.home_indicator()
    return s


def stats_topic(theme):
    s = Screen(theme, f"stopic-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(196.5, 86, "Разный низ", 17, 600, anchor="middle")

    s.text(20, 168, "54%", 56, 700)
    s.text(150, 142, "точность", 15, 500, t["sub"])
    s.text(150, 164, "37 примеров за неделю", 15, 500, t["sub"])

    s.card(s.rr(20, 190, 353, 150, 26))
    s.text(40, 216, "Последние 10 сессий", 15, 600)
    vals = [40, 35, 50, 45, 30, 55, 60, 50, 65, 70]
    x0, x1, y0, y1 = 48, 345, 318, 236
    for g in (0, 50, 100):
        gy = y0 - (y0 - y1) * g / 100
        s.raw(f'<path d="M{x0} {gy:.1f} L{x1} {gy:.1f}" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
        s.text(x1 + 6, gy + 4, f"{g}", 10, 500, t["faint"])
    pts = [(x0 + (x1 - x0) * i / 9, y0 - (y0 - y1) * v / 100) for i, v in enumerate(vals)]
    s.raw('<path d="M' + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + f'" fill="none" stroke="{t["ink"]}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>')
    lx, ly = pts[-1]
    s.raw(f'<circle cx="{lx}" cy="{ly}" r="6" fill="{t["ink"]}" stroke="{t["card"]}" stroke-width="2"/>')
    s.text(lx - 10, ly - 10, "70%", 12, 700, anchor="end")

    s.raw(bit("hint", theme, 50, 380, 0.2))
    s.card(s.rr(104, 354, 269, 56, 20))
    s.text(120, 378, "Чаще всего складываешь низы.", 14.5, 600)
    s.text(120, 398, "Повтори урок, потом 10 примеров.", 13, 400, t["sub"])

    s.card(s.rr(20, 424, 353, 238, 26))
    s.text(40, 450, "Частые ошибки", 16, 600)
    errs = [("Сложил верхи и низы", "1/3 + 1/6 = 2/9", 6),
            ("Низ не делится на оба", "1/4 + 1/6 → взял низ 10", 3),
            ("Не сократил", "3/6 вместо 1/2", 2)]
    for i, (a, b, n) in enumerate(errs):
        y = 470 + i * 62
        if i:
            s.raw(f'<path d="M40 {y-6} L353 {y-6}" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
        s.text(40, y + 18, a, 15, 600)
        s.text(40, y + 40, b, 14, 500, t["sub"])
        s.raw(f'<path d="{s.capsule(318, y+8, 36, 24)}" fill="{t["prom_fill"] if i == 0 else "none"}" stroke="{t["ink"]}" stroke-width="1.3"/>')
        s.text(336, y + 25, f"×{n}", 13, 700, t["prom_text"] if i == 0 else t["ink"], "middle")

    s.raw(f'<path d="{s.rr(20, 674, 353, 44, 16)}" fill="none" stroke="{t["ink"]}" stroke-opacity="0.5" stroke-width="1.3" stroke-dasharray="4 4"/>')
    s.text(196.5, 701, "«Не понял» ×3 — тема выпадает чаще", 13.5, 500, t["sub"], "middle")

    s.glass(s.capsule(20, 760, 166, 56))
    s.text(103, 794, "Тренировать", 17, 600, anchor="middle")
    s.glass(s.capsule(196, 760, 177, 56), prominent=True)
    s.text(284.5, 794, "Повторить урок", 17, 600, t["prom_text"], "middle")
    s.home_indicator()
    return s


def session_result(theme):
    s = Screen(theme, f"result-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.text(196.5, 86, "Итоги", 17, 600, anchor="middle")

    s.raw(bit("correct", theme, 196.5, 230, 0.48))
    s.text(196.5, 340, "8 из 10", 44, 700, anchor="middle")
    s.text(196.5, 366, "4 мин · серия 5 · точность 80%", 15, 500, t["sub"], "middle")

    # Ряд из 10 примеров: верные залиты, ошибки — контур с крестиком.
    res = [1, 1, 0, 1, 1, 1, 0, 1, 1, 1]
    for i, ok in enumerate(res):
        x = 32 + i * 33.5
        d = s.rr(x, 388, 28, 28, 9)
        if ok:
            s.raw(f'<path d="{d}" fill="{t["ink"]}"/>')
            s.icon("check", x + 14, 402, 0.55, t["bg"], 3)
        else:
            s.raw(f'<path d="{d}" fill="none" stroke="{t["ink"]}" stroke-width="1.6"/>')
            s.icon("xmark", x + 14, 402, 0.55, t["ink"], 2.6)

    s.card(s.rr(20, 436, 353, 196, 26))
    s.text(40, 462, "Ошибки", 16, 600)
    for i, (topic, prob, wrong, right) in enumerate([
            ("Разный низ", "1/4 + 1/2", "2/6", "3/4"),
            ("Таблица", "7 × 8", "54", "56")]):
        y = 478 + i * 72
        if i:
            s.raw(f'<path d="M40 {y-6} L353 {y-6}" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
        s.text(40, y + 16, topic, 13, 500, t["sub"])
        s.text(40, y + 44, f"{prob} =", 20, 700)
        wx = 40 + len(prob) * 11.5 + 30
        s.text(wx, y + 44, wrong, 20, 600, t["sub"])
        s.raw(f'<path d="M{wx-2} {y+38} L{wx + len(wrong)*12 + 2} {y+38}" stroke="{t["ink"]}" stroke-width="2"/>')
        s.text(wx + len(wrong) * 12 + 14, y + 44, right, 20, 700)
        s.glass(s.capsule(273, y + 20, 86, 34))
        s.text(316, y + 42, "Разобрать", 13, 600, anchor="middle")

    s.raw(bit("hint", theme, 50, 676, 0.18))
    s.card(s.rr(98, 650, 275, 52, 20))
    s.text(114, 672, "Слабое место: разный низ.", 14.5, 600)
    s.text(114, 691, "Следующие 10 — чаще по нему.", 13, 400, t["sub"])

    s.glass(s.capsule(20, 760, 150, 56))
    s.text(95, 794, "На главную", 16, 600, anchor="middle")
    s.glass(s.capsule(180, 760, 193, 56), prominent=True)
    s.text(276.5, 794, "Ещё 10 примеров", 17, 600, t["prom_text"], "middle")
    s.home_indicator()
    return s


def stats_sheet():
    sheet([stats_tab, stats_topic, session_result],
          ["Вкладка «Статистика»", "Тема: тренд и частые ошибки", "Итоги сессии (10 примеров)"],
          "Статистика", "screens-stats.svg")


MONO = "'SF Mono',Menlo,'DejaVu Sans Mono',monospace"


def math_row(s, x0, yc, items, size=22, color=None):
    """Строка записи: дроби «столбиком», знаки и текст. yc — уровень черты дроби.

    Элементы: ("f", верх, низ, {опции}) | ("o", знак) | ("t", текст).
    Опции дроби: ann — пометка множителя («×2»), active — "num"/"den" для поля с курсором.
    """
    t = s.t
    c = color or t["ink"]
    top = yc - size - 6
    x = x0
    for it in items:
        kind = it[0]
        if kind == "f":
            num, den = it[1], it[2]
            opt = it[3] if len(it) > 3 else {}
            w = max(len(num), len(den), 1) * size * 0.62 + 10
            cx = x + w / 2
            if num:
                s.text(cx, top + size * 0.82, num, size, 700, c, "middle")
            s.raw(f'<path d="M{x+2} {yc} L{x+w-2} {yc}" stroke="{c}" stroke-width="{size/13:.1f}" stroke-linecap="round"/>')
            if den:
                s.text(cx, yc + 6 + size * 0.82, den, size, 700, c, "middle")
            act = opt.get("active")
            if act:
                by = top - 2 if act == "num" else yc + 4
                s.raw(f'<path d="{s.rr(x-2, by, w+4, size+6, 7)}" fill="none" stroke="{c}" stroke-width="2"/>')
                s.raw(f'<rect x="{cx + (6 if (num if act == "num" else den) else 0) - 1}" y="{by+5}" width="2" height="{size-4}" rx="1" fill="{c}"/>')
            if opt.get("ann"):
                # Дополнительный множитель над дробью, как пишут в тетради.
                ax = x + w + 2
                s.text(ax, top + 4, opt["ann"], 12.5, 700, c)
                s.raw(f'<path d="M{ax-2} {top+8} L{ax+26} {top+8}" stroke="{c}" stroke-width="1.2"/>')
                w += 24
            x += w + 6
        elif kind == "o":
            ow = size * 0.85
            s.text(x + ow / 2, yc + size * 0.33, it[1], size * 0.95, 500, c, "middle")
            x += ow + 6
        else:
            s.text(x, yc + size * 0.33, it[1], size, 600, c)
            x += len(it[1]) * size * 0.56 + 6
    return x


def status(s, cx, cy, kind):
    """Статус строки без цвета: заливка, контур, пунктир и значок."""
    t = s.t
    if kind == "ok":
        s.raw(f'<circle cx="{cx}" cy="{cy}" r="12" fill="{t["ink"]}"/>')
        s.icon("check", cx, cy, 0.62, t["bg"], 3)
    elif kind == "reduce":
        s.raw(f'<circle cx="{cx}" cy="{cy}" r="11.5" fill="none" stroke="{t["ink"]}" stroke-width="2"/>')
        s.icon("check", cx, cy, 0.62, t["ink"], 3)
    elif kind == "wrong":
        s.raw(f'<circle cx="{cx}" cy="{cy}" r="12" fill="{t["prom_text"]}"/>')
        s.icon("xmark", cx, cy, 0.6, t["prom_fill"], 3)
    elif kind == "unknown":
        s.icon("question", cx, cy, 1.0, t["ink"], 2)


def notebook_card(s, y0, y1):
    """Карточка-тетрадь: лёгкая клетка, чтобы запись читалась как на бумаге."""
    t = s.t
    pid = s.uid("grid")
    s.defs.append(f'<pattern id="{pid}" width="16" height="16" patternUnits="userSpaceOnUse">'
                  f'<path d="M16 0 L0 0 L0 16" fill="none" stroke="{t["ink"]}" stroke-opacity="0.07" stroke-width="1"/></pattern>')
    d = s.rr(20, y0, 353, y1 - y0, 26)
    s.card(d)
    s.raw(f'<path d="{d}" fill="url(#{pid})"/>')


def solve_top(s, mode):
    t = s.t
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(176, 86, "Решаю сам", 17, 600, anchor="middle")
    s.glass(s.capsule(263, 58, 110, 44))
    s.icon("pencil", 285, 80, 0.85)
    s.text(332, 85, "Черновик", 14, 600, anchor="middle")
    s.glass(s.capsule(20, 112, 353, 38))
    for i, lab in enumerate(["По шагам", "Быстрый"]):
        x = 24 + i * 172.5
        if i == mode:
            s.raw(f'<path d="{s.capsule(x, 116, 172.5, 30)}" fill="{t["prom_fill"]}"/>')
        s.text(x + 86, 136, lab, 14, 600, t["prom_text"] if i == mode else t["ink"], "middle")


def key_strip(s, y, keys):
    """Верхняя полоса особых клавиш; ширины подобраны под подписи."""
    total = 353 - 4 * (len(keys) - 1)
    ws = [len(k) for k in keys]
    k_unit = total / sum(max(w, 2) + 2 for w in ws)
    x = 20
    for k in keys:
        w = (max(len(k), 2) + 2) * k_unit
        s.glass(s.capsule(x, y, w, 34))
        s.text(x + w / 2, y + 22, k, 14, 600, anchor="middle")
        x += w + 4


def frac_key_icon(s, cx, cy, mixed=False):
    t = s.t
    if mixed:
        s.raw(f'<rect x="{cx-13}" y="{cy-8}" width="9" height="16" rx="2.5" fill="none" stroke="{t["ink"]}" stroke-width="1.8"/>')
        cx += 5
    s.raw(f'<rect x="{cx-5}" y="{cy-12}" width="10" height="9" rx="2.5" fill="none" stroke="{t["ink"]}" stroke-width="1.8"/>'
          f'<path d="M{cx-7} {cy} L{cx+7} {cy}" stroke="{t["ink"]}" stroke-width="2" stroke-linecap="round"/>'
          f'<rect x="{cx-5}" y="{cy+3}" width="10" height="9" rx="2.5" fill="none" stroke="{t["ink"]}" stroke-width="1.8"/>')


def keys5(s, y0, rows):
    """Сетка 5×4 стеклянных клавиш. Особые клавиши: frac, mixed, delete."""
    kw, kh, g = (353 - 32) / 5, 44, 7
    for r, row in enumerate(rows):
        for c, k in enumerate(row):
            x, y = 20 + c * (kw + 8), y0 + r * (kh + g)
            s.glass(s.rr(x, y, kw, kh, 15))
            cx, cy = x + kw / 2, y + kh / 2
            if k == "frac":
                frac_key_icon(s, cx, cy)
            elif k == "mixed":
                frac_key_icon(s, cx, cy, True)
            elif k == "delete":
                s.icon("delete", cx, cy, 0.95)
            else:
                s.text(cx, cy + 8, k, 22 if len(k) < 3 else 15, 500, anchor="middle")


def check_buttons(s):
    t = s.t
    s.glass(s.capsule(20, 766, 160, 52))
    s.text(100, 798, "Проверить шаг", 15, 600, anchor="middle")
    s.glass(s.capsule(190, 766, 183, 52), prominent=True)
    s.icon("check", 210, 792, 0.9, t["prom_text"], 2.6)
    s.text(294, 798, "Проверить всё", 16, 600, t["prom_text"], "middle")


KB56 = [["7", "8", "9", "frac", "delete"], ["4", "5", "6", "+", "−"],
        ["1", "2", "3", "×", ":"], [",", "0", "=", "(", ")"]]


def solve_steps(theme):
    s = Screen(theme, f"solve-{theme}")
    t = s.t
    s.background()
    solve_top(s, 0)
    notebook_card(s, 162, 505)
    s.text(40, 186, "Пример · 6 класс · дроби", 13, 600, t["sub"])
    s.raw(bit("idle", theme, 342, 192, 0.14))
    math_row(s, 70, 228, [("f", "1", "3", {"ann": "×2"}), ("o", "+"), ("f", "1", "6")])
    status(s, 46, 294, "ok")
    math_row(s, 70, 294, [("o", "="), ("f", "2", "6"), ("o", "+"), ("f", "1", "6")])
    status(s, 46, 360, "ok")
    math_row(s, 70, 360, [("o", "="), ("f", "3", "6")])
    # Активная строка: дробь-шаблон, курсор в знаменателе.
    s.raw(f'<circle cx="46" cy="426" r="5" fill="{t["ink"]}" fill-opacity="0.35"/>')
    math_row(s, 70, 426, [("o", "="), ("f", "1", "", {"active": "den"})])
    s.glass(s.capsule(40, 462, 92, 32))
    s.icon("plus", 60, 478, 0.7)
    s.text(96, 483, "шаг", 14, 600, anchor="middle")
    s.text(353, 483, "строка 3 из 3", 12.5, 500, t["sub"], "end")

    key_strip(s, 517, ["смеш.", "aⁿ", "%", "a : b", "|x|", "×n"])
    keys5(s, 559, KB56)
    check_buttons(s)
    s.home_indicator()
    return s


def solve_error(theme):
    s = Screen(theme, f"solveerr-{theme}")
    t = s.t
    s.background()
    solve_top(s, 0)
    notebook_card(s, 162, 340)
    s.text(40, 186, "Пример · 6 класс · дроби", 13, 600, t["sub"])
    math_row(s, 70, 228, [("f", "1", "3"), ("o", "+"), ("f", "1", "6")])
    # Первая ошибочная строка: инверсия всей строки и крестик.
    s.raw(f'<path d="{s.rr(30, 256, 333, 70, 18)}" fill="{t["prom_fill"]}"/>')
    status(s, 52, 291, "wrong")
    math_row(s, 76, 291, [("o", "="), ("f", "2", "3"), ("o", "+"), ("f", "1", "6")], color=t["prom_text"])
    s.text(343, 296, "строка 1", 12.5, 600, t["prom_text"], "end", 0.7)

    # Bit указывает на ошибку, но не показывает решение.
    s.raw(bit("hint", theme, 52, 386, 0.22))
    s.card(s.rr(110, 356, 263, 62, 20))
    s.text(126, 382, "Умножил только верх.", 16, 700)
    s.text(126, 404, "Исправь строку 1.", 13.5, 500, t["sub"])
    s.raw(f'<path d="M110 372 C90 360 70 345 60 330" fill="none" stroke="{t["ink"]}" stroke-width="1.6" stroke-dasharray="4 4"/>'
          f'<path d="M55 337 L60 330 L67 334" fill="none" stroke="{t["ink"]}" stroke-width="1.6" stroke-linecap="round"/>')
    s.glass(s.capsule(20, 432, 150, 44))
    s.icon("bulb", 44, 454, 0.85)
    s.text(106, 459, "Подсказка", 15, 600, anchor="middle")
    s.glass(s.capsule(180, 432, 193, 44))
    s.icon("eye", 204, 454, 0.85)
    s.text(288, 459, "Показать решение", 15, 600, anchor="middle")
    s.text(196.5, 500, "Решение скрыто, пока не попросишь", 12.5, 500, t["sub"], "middle")

    key_strip(s, 517, ["смеш.", "aⁿ", "%", "a : b", "|x|", "×n"])
    keys5(s, 559, KB56)
    check_buttons(s)
    s.home_indicator()
    return s


def solve_algebra(theme):
    s = Screen(theme, f"solvealg-{theme}")
    t = s.t
    s.background()
    solve_top(s, 1)
    notebook_card(s, 162, 470)
    s.text(40, 186, "Пример · 8 класс · квадратные уравнения", 13, 600, t["sub"])
    s.text(70, 222, "x² − 5x + 6 = 0", 22, 700)
    rows = [("ok", "D = 25 − 24 = 1", None),
            ("unknown", "по Виета: подбираю 2 и 3", "не удалось проверить этот шаг"),
            ("ok", "x₁ = 2 или x₂ = 3", "ответ верный, порядок любой")]
    for i, (st, txt, note) in enumerate(rows):
        y = 262 + i * 58
        status(s, 46, y - 7, st)
        s.text(70, y, txt, 21 if st != "unknown" else 17, 600 if st != "unknown" else 500)
        if note:
            s.text(70, y + 22, note, 12.5, 500, t["sub"])
    s.raw(f'<path d="{s.capsule(283, 360, 70, 24)}" fill="{t["prom_fill"]}"/>')
    s.text(318, 377, "Ответ", 12.5, 700, t["prom_text"], "middle")
    s.glass(s.capsule(40, 422, 92, 32))
    s.icon("plus", 60, 438, 0.7)
    s.text(96, 443, "шаг", 14, 600, anchor="middle")

    s.text(20, 498, "Набор 7–8 класс", 13, 600, t["sub"])
    key_strip(s, 510, ["или", "x₁", "a⁻ⁿ", "нет решений", "любое число"])
    keys5(s, 552, [["x", "y", "x²", "aⁿ", "√"], ["(", ")", "[", "]", ";"],
                    ["<", ">", "≤", "≥", "∪"], ["123", "frac", "{", "±", "delete"]])
    # Клавиша системы уравнений — фигурная скобка с двумя строками; подпись поясняет.
    check_buttons(s)
    s.home_indicator()
    return s


def custom_example(theme):
    s = Screen(theme, f"custom-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(196.5, 86, "Свой пример", 17, 600, anchor="middle")

    notebook_card(s, 116, 236)
    s.text(40, 140, "Пример из домашки", 13, 600, t["sub"])
    end = math_row(s, 70, 194, [("f", "3", "4"), ("o", "−"), ("f", "2", "3"), ("o", "=")], 28)
    s.text(end + 2, 205, "?", 28, 700, t["faint"])
    s.glass(s.capsule(283, 128, 76, 30))
    s.text(321, 148, "Изменить", 12.5, 600, anchor="middle")

    s.card(s.rr(20, 248, 353, 182, 26))
    s.text(40, 274, "Нашёл тему", 13, 600, t["sub"])
    s.text(40, 300, "6 класс · Вычитание дробей", 17, 700)
    s.text(40, 322, "с разным низом", 17, 700)
    s.raw(f'<path d="M40 342 L353 342" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
    s.text(40, 370, "Ответ", 15, 500, t["sub"])
    s.glass(s.capsule(209, 349, 144, 34))
    s.icon("eye", 231, 366, 0.8)
    s.text(292, 371, "Показать", 14, 600, anchor="middle")
    s.text(40, 408, "Решение: 4 шага · общий низ 12", 14, 500, t["sub"])

    s.raw(bit("hint", theme, 52, 476, 0.2))
    s.card(s.rr(106, 448, 267, 58, 20))
    s.text(122, 472, "По этой теме есть урок.", 15, 600)
    s.text(122, 492, "Повторить перед решением?", 13.5, 500, t["sub"])
    s.glass(s.capsule(20, 520, 353, 44))
    s.icon("book", 128, 542, 0.85)
    s.text(212, 547, "Повторить урок", 15, 600, anchor="middle")

    s.raw(f'<path d="{s.rr(20, 580, 353, 64, 18)}" fill="none" stroke="{t["ink"]}" stroke-opacity="0.45" stroke-width="1.3" stroke-dasharray="4 4"/>')
    s.icon("question", 46, 612, 0.9)
    s.text(68, 607, "Если пример не поддерживается,", 13.5, 600)
    s.text(68, 626, "скажу прямо и назову причину.", 13.5, 500, t["sub"])

    s.glass(s.capsule(20, 702, 353, 52))
    s.text(196.5, 734, "Полное решение", 16, 600, anchor="middle")
    s.glass(s.capsule(20, 764, 353, 54), prominent=True)
    s.icon("pencil", 114, 791, 0.95, t["prom_text"])
    s.text(206, 797, "Решить самому", 17, 600, t["prom_text"], "middle")
    s.home_indicator()
    return s


def course_tab(theme):
    s = Screen(theme, f"course-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.glass(s.capsule(234, 58, 139, 44))
    s.icon("plus", 254, 80, 0.85)
    s.text(313, 85, "Свой пример", 14, 600, anchor="middle")
    s.text(20, 142, "Курс", 34, 700)
    s.glass(s.capsule(20, 160, 353, 38))
    w = (353 - 8) / 5
    for i, lab in enumerate(["Все", "5", "6", "7", "8"]):
        x = 24 + i * w
        if i == 0:
            s.raw(f'<path d="{s.capsule(x, 164, w, 30)}" fill="{t["prom_fill"]}"/>')
        s.text(x + w / 2, 184, lab, 14, 600, t["prom_text"] if i == 0 else t["ink"], "middle")

    sections = [("5 КЛАСС", [("Натуральные числа", .9), ("Обыкновенные дроби", .7), ("Десятичные дроби", .6)]),
                ("6 КЛАСС", [("НОД и НОК", .5), ("Проценты", .72), ("Отрицательные числа", .3)]),
                ("7 КЛАСС", [("Линейные уравнения", .2), ("Сокращённое умножение", .0)])]
    y = 226
    for name, rows in sections:
        s.text(20, y, name, 13, 600, t["sub"])
        s.card(s.rr(20, y + 10, 353, 48 * len(rows), 22))
        for i, (topic, prog) in enumerate(rows):
            ry = y + 10 + i * 48
            if i:
                s.raw(f'<path d="M40 {ry} L353 {ry}" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
            s.text(40, ry + 30, topic, 15.5, 600)
            # Освоение темы — короткая полоса, без цвета.
            s.raw(f'<rect x="300" y="{ry+21}" width="40" height="6" rx="3" fill="{t["ink"]}" fill-opacity="0.1"/>')
            if prog:
                s.raw(f'<rect x="300" y="{ry+21}" width="{40*prog:.0f}" height="6" rx="3" fill="{t["ink"]}"/>')
            s.icon("chevron.left", 355, ry + 24, 0.55, t["faint"])
            s.items[-1] = s.items[-1].replace("scale(0.55)", "scale(-0.55 0.55)")
        y += 10 + 48 * len(rows) + 32
    fade_bottom(s, 690)
    tab_bar(s, 1)
    s.home_indicator()
    return s


def topic_card(theme):
    s = Screen(theme, f"tcard-{theme}")
    t = s.t
    s.background()
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(20, 146, "Проценты", 30, 700)
    s.text(20, 168, "6 класс · точность 72%", 14, 500, t["sub"])
    s.raw(bit("idle", theme, 340, 138, 0.16))

    s.glass(s.capsule(20, 182, 92, 40), prominent=True)
    s.text(66, 207, "Урок", 15, 600, t["prom_text"], "middle")
    s.glass(s.capsule(120, 182, 120, 40))
    s.text(180, 207, "Тренировать", 14, 600, anchor="middle")
    s.glass(s.capsule(248, 182, 125, 40))
    s.text(310.5, 207, "Решить самому", 14, 600, anchor="middle")

    s.card(s.rr(20, 234, 353, 534, 26))
    s.text(40, 262, "Зачем это нужно", 17, 700)
    s.icon("chevron.up", 350, 256, 0.75)
    s.raw(f'<path d="{s.capsule(40, 278, 76, 28)}" fill="{t["prom_fill"]}"/>')
    s.text(78, 297, "Нужно", 14, 700, t["prom_text"], "middle")
    s.text(128, 290, "Скидки, прогресс, доли экрана.", 13.5, 600)
    s.text(128, 308, "База для статистики в 8 классе.", 13.5, 500, t["sub"])
    s.text(40, 334, "Оценка: в найденных обсуждениях проценты —", 12.5, 500, t["sub"])
    s.text(40, 351, "одна из немногих тем, что встречается в вебе.", 12.5, 500, t["sub"])

    s.text(40, 380, "В ПРОГРАММИРОВАНИИ", 12, 600, t["sub"])
    s.raw(f'<path d="{s.rr(40, 390, 313, 58, 14)}" fill="{t["ink"]}" fill-opacity="0.06"/>')
    for i, line in enumerate(["let price = 1200", "let sale = price * 15 / 100  // 180"]):
        s.raw(f'<text x="54" y="{414 + i * 20}" font-family="{MONO}" font-size="12.5" fill="{t["ink"]}">{line}</text>')

    s.text(40, 478, "ЧТО ГОВОРЯТ ЛЮДИ", 12, 600, t["sub"])
    srcs = [("Хабр Q&amp;A · проверено 13.11.2026",
             ["За пять лет в вебе математика нужна была", "в основном для скидок и суммы корзины."]),
            ("Хабр Q&amp;A · проверено 13.11.2026",
             ["Мнения расходятся: одним хватает арифметики,", "другие — про сложные проценты и статистику."]),
            ("inventwithpython.com · проверено 13.11.2026",
             ["Хватает арифметики; процент — умножение", "на десятичную дробь: 54% от 279 = 0,54 × 279."])]
    for i, (site, lines) in enumerate(srcs):
        y = 494 + i * 76
        if i:
            s.raw(f'<path d="M40 {y-6} L353 {y-6}" stroke="{t["ink"]}" stroke-opacity="0.08"/>')
        s.text(40, y + 14, site, 12.5, 700)
        s.icon("link", 346, y + 9, 0.7)
        for j, line in enumerate(lines):
            s.text(40, y + 34 + j * 18, line, 13, 500, t["sub"])
    s.text(196.5, 748, "Мнения людей субъективны, это не истина.", 11.5, 500, t["sub"], "middle")
    s.home_indicator()
    return s


def scratchpad(theme):
    s = Screen(theme, f"draft-{theme}")
    t = s.t
    # Черновик — холст PencilKit на весь экран, клетка для удобства.
    s.raw(f'<rect width="{PW}" height="{PH}" fill="{t["base"]}"/>')
    pid = s.uid("grid")
    s.defs.append(f'<pattern id="{pid}" width="20" height="20" patternUnits="userSpaceOnUse">'
                  f'<path d="M20 0 L0 0 L0 20" fill="none" stroke="{t["ink"]}" stroke-opacity="0.08"/></pattern>'
                  f'<filter id="{s.sid}-hand"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="4"/>'
                  f'<feDisplacementMap in="SourceGraphic" scale="5"/></filter>')
    s.raw(f'<rect width="{PW}" height="{PH}" fill="url(#{pid})"/>')
    s.status_bar()
    s.glass(s.capsule(20, 58, 44, 44))
    s.icon("chevron.left", 41, 80)
    s.text(196.5, 80, "Черновик", 17, 600, anchor="middle")
    s.text(196.5, 98, "не проверяется", 12, 500, t["sub"], "middle")
    s.glass(s.capsule(255, 58, 118, 44))
    s.icon("undo", 280, 80, 0.85)
    s.icon("redo", 314, 80, 0.85)
    s.icon("trash", 350, 80, 0.85)

    # Наброски «от руки»: обычная запись, искажённая фильтром.
    start = len(s.items)
    math_row(s, 60, 220, [("f", "1", "3"), ("o", "+"), ("f", "1", "6"), ("o", "=")], 34)
    s.raw(f'<path d="M78 268 C110 330 200 330 232 270" fill="none" stroke="{t["ink"]}" stroke-width="2.4" stroke-linecap="round"/>'
          f'<path d="M222 274 L232 270 L234 281" fill="none" stroke="{t["ink"]}" stroke-width="2.4" stroke-linecap="round"/>')
    s.text(140, 345, "6 : 3 = 2", 26, 500)
    math_row(s, 60, 440, [("f", "2", "6"), ("o", "+"), ("f", "1", "6"), ("o", "="), ("f", "3", "6")], 34)
    s.raw(f'<ellipse cx="220" cy="438" rx="32" ry="52" fill="none" stroke="{t["ink"]}" stroke-width="2.2"/>')
    s.text(222, 540, "÷ 3 →  1/2", 28, 500)
    s.raw(f'<path d="M210 556 Q280 566 352 552" fill="none" stroke="{t["ink"]}" stroke-width="2"/>')
    hand = "".join(s.items[start:])
    del s.items[start:]
    s.raw(f'<g filter="url(#{s.sid}-hand)" font-style="italic">{hand}</g>')

    # Палитра инструментов PencilKit (в iOS 26 — стеклянная).
    s.glass(s.capsule(30, 732, 333, 70))
    tools = [("pen", True), ("pencil", False), ("marker", False), ("eraser", False), ("lasso", False)]
    for i, (name, sel) in enumerate(tools):
        x = 62 + i * 46
        lift = -8 if sel else 0
        body = s.rr(x - 10, 748 + lift, 20, 50, 6)
        s.raw(f'<path d="{body}" fill="{t["card"]}" stroke="{t["ink"]}" stroke-opacity="0.35"/>')
        if name == "eraser":
            s.raw(f'<rect x="{x-10}" y="{748+lift}" width="20" height="12" rx="6" fill="{t["ink"]}" fill-opacity="0.25"/>')
        elif name == "lasso":
            s.raw(f'<ellipse cx="{x}" cy="{758+lift}" rx="7" ry="5" fill="none" stroke="{t["ink"]}" stroke-width="1.5" stroke-dasharray="2 2"/>')
        else:
            tip = {"pen": 4, "pencil": 6, "marker": 9}[name]
            s.raw(f'<path d="M{x-10} {760+lift} L{x-tip/2} {744+lift} L{x+tip/2} {744+lift} L{x+10} {760+lift} Z" fill="{t["ink"]}"/>')
    s.raw(f'<circle cx="312" cy="767" r="13" fill="{t["ink"]}" stroke="{t["card"]}" stroke-width="3"/>')
    s.raw(f'<circle cx="312" cy="767" r="16" fill="none" stroke="{t["ink"]}" stroke-opacity="0.4"/>')
    s.icon("plus", 344, 767, 0.75)
    s.home_indicator()
    return s


def solve_sheet():
    sheet([solve_steps, solve_error, solve_algebra, custom_example],
          ["«Решаю сам»: по шагам, клавиатура 5–6", "Ошибочный шаг: Bit указывает, решение скрыто",
           "Клавиатура 7–8: x, степень, корень, промежутки", "«Свой пример»: тема найдена, ответ скрыт"],
          "Решаю сам", "screens-solve.svg")


def course_sheet():
    sheet([course_tab, topic_card, scratchpad],
          ["Вкладка «Курс»: все темы 5–8", "Карточка темы: «Зачем это нужно»", "Черновик (PencilKit)"],
          "Курс", "screens-course.svg")


def sheet(fns, labels, name, filename):
    M, GAP, HEAD = 70, 60, 130
    W = M * 2 + PW * len(fns) + GAP * (len(fns) - 1)
    sec_h = HEAD + PH + 90
    H = sec_h * 2
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
             "<defs>" + defs_bit("light") + defs_bit("dark") + "</defs>"]
    for si, theme in enumerate(("light", "dark")):
        t = THEMES[theme]
        oy = si * sec_h
        parts.append(f'<rect x="0" y="{oy}" width="{W}" height="{sec_h}" fill="{t["sheet"]}"/>')
        title = f"{name} · {'светлая' if theme == 'light' else 'тёмная'} тема"
        parts.append(f'<text x="{M}" y="{oy+72}" font-family="{FONT}" font-size="30" font-weight="700" fill="{t["ink"]}">{title}</text>')
        for i, fn in enumerate(fns):
            x = M + i * (PW + GAP)
            parts.append(f'<text x="{x}" y="{oy+112}" font-family="{FONT}" font-size="17" font-weight="500" fill="{t["sub"]}">{labels[i]}</text>')
            parts.append(f'<g transform="translate({x} {oy+HEAD})">{fn(theme).render()}</g>')
    parts.append("</svg>")
    (OUT / filename).write_text("\n".join(parts), encoding="utf-8")


def screens_sheet():
    sheet([home, training, correct, review],
          ["Главная: темы и уроки", "Тренировка: кнопка «Объясни»", "Верно: похожий пример, полное решение",
           "Ошибка: уровень 1, «Понял» / «Не понял»"],
          "Экраны", "screens.svg")


if __name__ == "__main__":
    bit_sheet()
    screens_sheet()
    learning_sheet()
    stats_sheet()
    solve_sheet()
    course_sheet()
    print("ok")
