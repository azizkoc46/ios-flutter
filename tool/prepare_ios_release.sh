#!/bin/bash
set -euo pipefail

EXPECTED_BUNDLE_ID="com.pp.pazarckportal.pazarckportal"
BUILD_NAME="${BUILD_NAME:-1.0.2}"
BUILD_NUMBER="${BUILD_NUMBER:-30}"

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter bulunamadi. Flutter SDK PATH ayarini kontrol edin."
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods bulunamadi. Mac'te once: sudo gem install cocoapods"
  exit 1
fi

CURRENT_BUNDLE_ID="$(
  xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F ' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}'
)"

if [[ "$CURRENT_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Bundle ID eslesmiyor."
  echo "Mevcut : $CURRENT_BUNDLE_ID"
  echo "Gerekli: $EXPECTED_BUNDLE_ID"
  echo "Xcode > Runner target > Signing & Capabilities > Bundle Identifier alanini duzeltin."
  exit 1
fi

flutter clean
flutter pub get

pushd ios >/dev/null
pod install --repo-update
popd >/dev/null

flutter build ipa \
  --release \
  --build-name "$BUILD_NAME" \
  --build-number "$BUILD_NUMBER"

echo "IPA hazir: build/ios/ipa/"
echo "Xcode Organizer veya Transporter ile App Store Connect'e yukleyebilirsiniz."
