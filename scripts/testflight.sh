#!/bin/zsh
# Archive Optique and upload it to TestFlight with an App Store Connect API key.
#
#   ASC_KEY_PATH=~/keys/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX ASC_ISSUER_ID=xxxxxxxx-... scripts/testflight.sh
#
# The build number is the current UTC time (yyMMddHHmm) so every upload is newer than the last.
set -e
: "${ASC_KEY_PATH:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}"
ROOT="${0:A:h:h}"
OUT="${TMPDIR:-/tmp}/optique-testflight"
BUILD=$(date -u +%y%m%d%H%M)
rm -rf "$OUT" && mkdir -p "$OUT"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>BJ66V252MG</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

xcodebuild archive -project "$ROOT/Optique/Optique.xcodeproj" -scheme Optique -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Optique.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD" PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID:-com.flow.optique}" "${AUTH[@]}" -quiet
xcodebuild -exportArchive -archivePath "$OUT/Optique.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" "${AUTH[@]}"
echo "Uploaded build $BUILD"
