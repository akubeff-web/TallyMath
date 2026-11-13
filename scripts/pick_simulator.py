"""Выбирает доступный симулятор iPhone с самой свежей iOS 26.x. Печатает UDID.

Вход — `xcrun simctl list devices available -j` на stdin.
"""
import json
import re
import sys

data = json.load(sys.stdin)
best = None
for runtime, devices in data["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m or int(m.group(1)) < 26:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if not d.get("isAvailable", True) or not d["name"].startswith("iPhone"):
            continue
        # Обычный iPhone (не Pro Max / не SE) лучше всего похож на макеты 393×852.
        score = (version, "Pro" not in d["name"] and "Plus" not in d["name"] and "SE" not in d["name"], d["name"])
        if best is None or score > best[0]:
            best = (score, d["udid"], d["name"])
if best is None:
    sys.exit("нет симулятора iPhone с iOS 26")
print(best[1])
print(f"Симулятор: {best[2]} {best[0][0]}", file=sys.stderr)
