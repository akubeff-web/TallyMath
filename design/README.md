# Дизайн-превью (этап 0)

- `bit-states.svg` / `.png` — персонаж Bit в 6 состояниях, светлая и тёмная тема.
- `screens.svg` / `.png` — макеты: главная, тренировка (ввод), тренировка (разбор ошибки).
- `src/generate.py` — генерирует оба SVG (`python3 design/src/generate.py`).
- `src/render.js` — рендерит SVG в PNG через Chromium/Playwright (`node design/src/render.js`).

Шрифт в превью — Inter вместо SF Pro (SF есть только на устройствах Apple).

## Иконка

- `icon/AppIcon-1024.png` — иконка приложения 1024×1024, без альфа-канала (так требует iOS). Сделана из присланного образца: уменьшена с 1254 до 1024.
- `icon/icon-sizes-preview.png` — как иконка выглядит в маске iOS на размерах 180, 120 и 87 px, на светлом и тёмном фоне.

Когда появится приложение, этот файл ляжет в `Assets.xcassets/AppIcon.appiconset/`.
