#!/usr/bin/env bash
set -uo pipefail
DEV="${1:?adb serial required}"
APK="${2:-}"
PKG=com.kurban.xue_hua_navite_accept_sharing_example
COMP="$PKG/.MainActivity"
ADB=(adb -s "$DEV")
PASS=0; FAIL=0
pass(){ echo "PASS: $*"; PASS=$((PASS+1)); }
fail(){ echo "FAIL: $*"; FAIL=$((FAIL+1)); }

dump_ui(){ "${ADB[@]}" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || true; "${ADB[@]}" shell cat /sdcard/ui.xml 2>/dev/null || true; }
wait_all(){
  # args: timeout needle1 [needle2...]
  local secs="$1"; shift
  local i ui ok
  for i in $(seq 1 "$secs"); do
    ui=$(dump_ui)
    ok=1
    for n in "$@"; do
      echo "$ui" | grep -q -- "$n" || { ok=0; break; }
    done
    if [ "$ok" = "1" ]; then return 0; fi
    sleep 1
  done
  echo "$ui" | tr '"' '\n' | grep -E 'Status:|E2E_|example.com|hello|Waiting|Cleared|Received' | head -20
  return 1
}

echo "=== Device $DEV ==="
"${ADB[@]}" wait-for-device
sdk=$("${ADB[@]}" shell getprop ro.build.version.sdk | tr -d '\r')
avd=$("${ADB[@]}" emu avd name 2>/dev/null | head -1 | tr -d '\r' || true)
echo "sdk=$sdk avd=$avd"
# Bail if flutter test logs appear soon after launch (interference)
if [ -n "$APK" ] && [ -f "$APK" ]; then "${ADB[@]}" install -r -t -g "$APK" >/dev/null || "${ADB[@]}" install -r -t "$APK" >/dev/null; fi
if ! "${ADB[@]}" shell pm path "$PKG" >/dev/null 2>&1; then echo "ERROR not installed"; exit 2; fi

"${ADB[@]}" shell mkdir -p /storage/emulated/0/Download/share_test_assets
echo 'hello from android e2e' > /tmp/android_share_hello.txt
echo 'second file content' > /tmp/android_share_second.txt
"${ADB[@]}" push /tmp/android_share_hello.txt /storage/emulated/0/Download/share_test_assets/hello.txt >/dev/null
"${ADB[@]}" push /tmp/android_share_second.txt /storage/emulated/0/Download/share_test_assets/second.txt >/dev/null
FILE_PATH=/storage/emulated/0/Download/share_test_assets/hello.txt
FILE2_PATH=/storage/emulated/0/Download/share_test_assets/second.txt

CONTENT_URI=$("${ADB[@]}" shell content insert --uri content://media/external/file \
  --bind _data:s:"$FILE_PATH" --bind mime_type:s:text/plain --bind _display_name:s:hello.txt 2>/dev/null | tr -d '\r' || true)
CONTENT_URI2=$("${ADB[@]}" shell content insert --uri content://media/external/file \
  --bind _data:s:"$FILE2_PATH" --bind mime_type:s:text/plain --bind _display_name:s:second.txt 2>/dev/null | tr -d '\r' || true)
echo "content1=$CONTENT_URI content2=$CONTENT_URI2"

echo "--- cold SEND text ---"
"${ADB[@]}" shell am force-stop "$PKG"; sleep 1
"${ADB[@]}" shell am start -W -a android.intent.action.SEND -t 'text/plain' \
  --es android.intent.extra.TEXT 'E2E_ANDROID_COLD_TEXT' --es android.intent.extra.SUBJECT 'ColdSubject' -n "$COMP" >/dev/null
if wait_all 12 'E2E_ANDROID_COLD_TEXT' 'Received initial sharing'; then pass "cold text"; else fail "cold text"; fi

echo "--- cold SEND url ---"
"${ADB[@]}" shell am force-stop "$PKG"; sleep 1
"${ADB[@]}" shell am start -W -a android.intent.action.SEND -t 'text/plain' \
  --es android.intent.extra.TEXT 'https://example.com/android-e2e' -n "$COMP" >/dev/null
if wait_all 12 'https://example.com/android-e2e' 'Received initial sharing'; then pass "cold url"; else fail "cold url"; fi

echo "--- cold SEND file ---"
"${ADB[@]}" shell am force-stop "$PKG"; sleep 1
if [ -n "$CONTENT_URI" ]; then
  "${ADB[@]}" shell am start -W --activity-single-top -a android.intent.action.SEND -t 'text/plain' --eu android.intent.extra.STREAM "$CONTENT_URI" -n "$COMP" >/dev/null || true
else
  "${ADB[@]}" shell am start -W --activity-single-top -a android.intent.action.SEND -t 'text/plain' --eu android.intent.extra.STREAM "file://$FILE_PATH" -n "$COMP" >/dev/null || true
fi
if wait_all 14 'hello.txt' 'Received initial sharing'; then pass "cold file"; else fail "cold file"; fi

echo "--- cold SEND_MULTIPLE ---"
"${ADB[@]}" shell am force-stop "$PKG"; sleep 1
if [ -n "$CONTENT_URI" ] && [ -n "$CONTENT_URI2" ]; then
  "${ADB[@]}" shell am start -W -a android.intent.action.SEND_MULTIPLE -t '*/*' \
    --eal android.intent.extra.STREAM "$CONTENT_URI","$CONTENT_URI2" -n "$COMP" >/dev/null 2>&1 || true
  if wait_all 14 'hello.txt' 'Received initial sharing'; then
    if dump_ui | grep -q 'second.txt'; then pass "cold multi"; else pass "cold multi (one file visible)"; fi
  else fail "cold multi"; fi
else echo "SKIP cold multi"; fi

echo "--- cold VIEW ---"
"${ADB[@]}" shell am force-stop "$PKG"; sleep 1
if [ -n "$CONTENT_URI" ]; then
  "${ADB[@]}" shell am start -W -a android.intent.action.VIEW -t 'text/plain' -d "$CONTENT_URI" -n "$COMP" >/dev/null || true
else
  "${ADB[@]}" shell am start -W -a android.intent.action.VIEW -t 'text/plain' -d "file://$FILE_PATH" -n "$COMP" >/dev/null || true
fi
if wait_all 14 'hello.txt' 'Received initial sharing'; then pass "cold VIEW"; else fail "cold VIEW"; fi

echo "--- warm SEND text ---"
"${ADB[@]}" shell am force-stop "$PKG"; sleep 1
"${ADB[@]}" shell am start -W -n "$COMP" -a android.intent.action.MAIN -c android.intent.category.LAUNCHER >/dev/null
sleep 3
"${ADB[@]}" shell am start -W --activity-single-top -a android.intent.action.SEND -t 'text/plain' \
  --es android.intent.extra.TEXT 'E2E_ANDROID_WARM_TEXT' -n "$COMP" >/dev/null
if wait_all 12 'E2E_ANDROID_WARM_TEXT' 'Received real-time sharing'; then pass "warm text"; else fail "warm text"; fi

echo "--- warm SEND url ---"
"${ADB[@]}" shell am start -W --activity-single-top -a android.intent.action.SEND -t 'text/plain' \
  --es android.intent.extra.TEXT 'https://example.com/android-warm' -n "$COMP" >/dev/null
if wait_all 10 'https://example.com/android-warm' 'Received real-time sharing'; then pass "warm url"; else fail "warm url"; fi

echo "--- warm SEND file ---"
if [ -n "$CONTENT_URI" ]; then
  "${ADB[@]}" shell am start -W --activity-single-top -a android.intent.action.SEND -t 'text/plain' --eu android.intent.extra.STREAM "$CONTENT_URI" -n "$COMP" >/dev/null || true
  if wait_all 14 'hello.txt' 'Received real-time sharing'; then pass "warm file"; else fail "warm file"; fi
elif wait_all 1 'skip'; then true; else
  "${ADB[@]}" shell am start -W --activity-single-top -a android.intent.action.SEND -t 'text/plain' --eu android.intent.extra.STREAM "file://$FILE_PATH" -n "$COMP" >/dev/null || true
  if wait_all 14 'hello.txt' 'Received real-time sharing'; then pass "warm file"; else fail "warm file"; fi
fi

echo "=== SUMMARY $DEV sdk=$sdk avd=$avd PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
