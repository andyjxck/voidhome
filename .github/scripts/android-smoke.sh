#!/usr/bin/env bash
# Smoke test for the Void Home debug APK on an emulator: install, open, wait, check it is still running.
set -u
mkdir -p smoke
APK=$(ls apk/*.apk | head -1)
PKG=com.void.homeos
ACT=com.voidhome.app.MainActivity

adb wait-for-device
adb install -r "$APK" | tee smoke/install.txt
adb logcat -c
adb shell am start -W -n "$PKG/$ACT" | tee smoke/start.txt
sleep 25
adb exec-out screencap -p > smoke/screen-launch.png
PID=$(adb shell pidof "$PKG" | tr -d '\r')
adb logcat -d > smoke/logcat-full.txt
grep -n -A40 "FATAL EXCEPTION" smoke/logcat-full.txt > smoke/crash.txt || true
grep -E "VoidHome|$PKG|AndroidRuntime|FirebaseApp|Firestore" smoke/logcat-full.txt | tail -300 > smoke/logcat-app.txt || true

# Rotate to landscape and back, a cheap check that the screen survives recreation.
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
sleep 6
adb shell settings put system user_rotation 0
sleep 6
adb exec-out screencap -p > smoke/screen-after-rotate.png
PID2=$(adb shell pidof "$PKG" | tr -d '\r')
adb logcat -d | grep -n -A40 "FATAL EXCEPTION" >> smoke/crash.txt || true

{
  echo "pid after launch: ${PID:-none}"
  echo "pid after rotate: ${PID2:-none}"
  echo "crash lines: $(wc -l < smoke/crash.txt)"
} | tee smoke/result.txt

if [ -z "$PID" ] || [ -z "$PID2" ] || [ -s smoke/crash.txt ]; then
  echo "Smoke test failed"
  exit 1
fi
echo "Smoke test passed"
