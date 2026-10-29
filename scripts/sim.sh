#!/bin/zsh
# Build and install Optique on the always-on iPhone 16 simulator, or run unit tests on a
# separate simulator. Never shuts a simulator down.
#
#   scripts/sim.sh run     build, install and relaunch the app on the main simulator
#   scripts/sim.sh test    run unit tests on the "iPhone 16 (tests)" simulator (not the main one)
set -e

MAIN=0635F48D-77EB-4C4F-9962-9BA543C8D0A5   # iPhone 16: stays booted, app stays installed
TESTS=32BAC73C-9D6B-4D6C-A53A-63E9254DA047  # iPhone 16 (tests): xcodebuild may boot/stop it freely
BUNDLE=com.flow.optique
ROOT="${0:A:h:h}"
PROJECT="$ROOT/Optique/Optique.xcodeproj"
DD="${TMPDIR:-/tmp}/optique-dd"

case "$1" in
  run)
    # Make sure the main simulator is on (booting an already booted device is a no-op).
    xcrun simctl boot $MAIN 2>/dev/null || true
    xcodebuild build -project "$PROJECT" -scheme Optique -destination "id=$MAIN" -derivedDataPath "$DD" -quiet
    xcrun simctl install $MAIN "$DD/Build/Products/Debug-iphonesimulator/Optique.app"
    xcrun simctl launch $MAIN $BUNDLE
    ;;
  test)
    xcodebuild test -project "$PROJECT" -scheme Optique -destination "id=$TESTS" \
      -only-testing:OptiqueTests -derivedDataPath "$DD-tests" -quiet
    ;;
  *)
    echo "usage: scripts/sim.sh run|test" >&2
    exit 1
    ;;
esac
