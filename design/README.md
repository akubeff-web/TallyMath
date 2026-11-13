# Дизайн-превью (этап 0)

- `bit-states.svg` / `.png` — персонаж Bit в 6 состояниях, светлая и тёмная тема.
- `screens.svg` / `.png` — макеты: главная, тренировка (ввод), тренировка (разбор ошибки).
- `src/generate.py` — генерирует оба SVG (`python3 design/src/generate.py`).
- `src/render.js` — рендерит SVG в PNG через Chromium/Playwright (`node design/src/render.js`).

Шрифт в превью — Inter вместо SF Pro (SF есть только на устройствах Apple).
