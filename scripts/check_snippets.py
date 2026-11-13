"""Проверяет, что все Swift-сниппеты из блока «Зачем это нужно» компилируются.

Каждый сниппет кладётся в отдельный файл и проверяется `swiftc -typecheck`.
"""
import json
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
path = root / "TallyMath" / "Resources" / "why.json"
if not path.exists():
    print("why.json пока нет — проверять нечего")
    sys.exit(0)

entries = json.loads(path.read_text(encoding="utf-8"))
failed = 0
checked = 0
with tempfile.TemporaryDirectory() as tmp:
    for entry in entries:
        code = (entry.get("swift") or "").strip()
        if not code:
            continue
        f = pathlib.Path(tmp) / f"{entry['topic'].replace('.', '_')}.swift"
        f.write_text(code + "\n", encoding="utf-8")
        r = subprocess.run(["swiftc", "-typecheck", str(f)], capture_output=True, text=True)
        checked += 1
        if r.returncode != 0:
            failed += 1
            print(f"✗ {entry['topic']}:\n{r.stderr}")
print(f"проверено сниппетов: {checked}, с ошибками: {failed}")
sys.exit(1 if failed else 0)
