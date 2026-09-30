#!/usr/bin/env bash
# Builds Android APKs via Gradle directly. `flutter build apk` fails on Windows
# when the project path contains "&" (gradlew.bat cannot handle it), so we call
# the POSIX gradlew script instead. Requires JDK 17 (Android Studio's JBR).
#
# Usage: tool/build_android.sh [debug|release]
set -euo pipefail
MODE="${1:-release}"
cd "$(dirname "$0")/../android"
TASK="assemble$(tr '[:lower:]' '[:upper:]' <<< "${MODE:0:1}")${MODE:1}"
./gradlew "$TASK"
ls -la ../build/app/outputs/flutter-apk/
