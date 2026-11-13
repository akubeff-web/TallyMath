"""Выбирает симулятор для тестов и скриншотов. Печатает UDID.

Хотим iPhone 13 Pro Max (как у владельца). Если его нет среди готовых симуляторов,
создаём из типа устройства с самой свежей iOS ≥ 26. Если и это не вышло — обычный iPhone.
"""
import json
import re
import subprocess
import sys

WANTED = "iPhone 13 Pro Max"
WANTED_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro-Max"


def simctl(*args):
    return subprocess.run(["xcrun", "simctl", *args], capture_output=True, text=True)


def ios_version(runtime_id):
    m = re.search(r"iOS-(\d+)-(\d+)", runtime_id)
    return (int(m.group(1)), int(m.group(2))) if m else None


devices = json.loads(simctl("list", "devices", "available", "-j").stdout)["devices"]

# 1. Готовый iPhone 13 Pro Max с iOS ≥ 26.
best = None
for runtime, items in devices.items():
    v = ios_version(runtime)
    if not v or v[0] < 26:
        continue
    for d in items:
        if d["name"] == WANTED and (best is None or v > best[0]):
            best = (v, d["udid"])
if best:
    print(best[1])
    print(f"Симулятор: {WANTED} iOS {best[0]}", file=sys.stderr)
    sys.exit(0)

# 2. Создаём его на самой свежей iOS ≥ 26, если Xcode знает такой тип устройства.
runtimes = json.loads(simctl("list", "runtimes", "available", "-j").stdout)["runtimes"]
ios = sorted(
    [r for r in runtimes if r.get("platform") == "iOS" and ios_version(r["identifier"]) and ios_version(r["identifier"])[0] >= 26],
    key=lambda r: ios_version(r["identifier"]),
    reverse=True,
)
for r in ios:
    supported = [t.get("identifier") for t in r.get("supportedDeviceTypes", [])]
    if supported and WANTED_TYPE not in supported:
        continue
    res = simctl("create", WANTED, WANTED_TYPE, r["identifier"])
    if res.returncode == 0 and res.stdout.strip():
        print(res.stdout.strip())
        print(f"Симулятор: создан {WANTED} {r['name']}", file=sys.stderr)
        sys.exit(0)

# 3. Запасной вариант: обычный iPhone (не Pro, не Plus, не SE).
fallback = None
for runtime, items in devices.items():
    v = ios_version(runtime)
    if not v or v[0] < 26:
        continue
    for d in items:
        if not d["name"].startswith("iPhone"):
            continue
        plain = not any(w in d["name"] for w in ("Pro", "Plus", "SE", "Air", "Duo", "Fold"))
        score = (v, plain, d["name"])
        if fallback is None or score > fallback[0]:
            fallback = (score, d["udid"], d["name"])
if fallback is None:
    sys.exit("нет симулятора iPhone с iOS 26+")
print(fallback[1])
print(f"Симулятор: {WANTED} недоступен, взят {fallback[2]}", file=sys.stderr)
