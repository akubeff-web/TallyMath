#!/bin/bash
# Снимает скриншоты экранов в светлой и тёмной теме.
# Приложение само открывает нужный экран по launch-аргументам -previewScreen и -previewState.
set -euo pipefail
UDID="$1"
APP="$2"
BUNDLE="com.tallymath.app"
OUT="screenshots"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

# экран:состояние
SHOTS=(
  "home:normal" "training:input" "training:correct" "training:wrong"
  "lesson:topic" "lesson:level1" "lesson:level2" "lesson:level3" "fullSolution:normal"
  "result:normal" "result:perfect" "stats:normal" "statsTopic:normal"
  "solve:steps" "solve:error" "solve:algebra" "custom:normal"
  "course:normal" "topicCard:why" "draft:normal" "home:review" "bit:sheet"
)

for theme in light dark; do
  xcrun simctl ui "$UDID" appearance "$theme"
  for shot in "${SHOTS[@]}"; do
    screen="${shot%%:*}"
    state="${shot##*:}"
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" -previewScreen "$screen" -previewState "$state" -demoData YES >/dev/null
    sleep 4
    xcrun simctl io "$UDID" screenshot "$OUT/${theme}-${screen}-${state}.png" >/dev/null
    echo "снято: ${theme}-${screen}-${state}"
  done
done
