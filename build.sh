#!/bin/zsh
set -euo pipefail
source_dir="${0:A:h}"
app_dir="$source_dir/.build/AssignmentDates.stage"
output_dir="${ASSIGNMENT_DATES_OUTPUT_DIR:-$source_dir/dist}"
mkdir -p "$output_dir"
deliverable="$output_dir/Assignment Dates.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
xcrun swiftc -parse-as-library -O -target arm64-apple-macos27.0 \
  "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/TokenStore.swift" "$source_dir/CanvasStore.swift" "$source_dir/MenuBarController.swift" "$source_dir/MenuBarSettings.swift" "$source_dir/FeedbackAPI.swift" "$source_dir/FeedbackFiles.swift" "$source_dir/FeedbackPersistence.swift" "$source_dir/FeedbackModels.swift" "$source_dir/FeedbackStore.swift" "$source_dir/FeedbackDesignFixture.swift" "$source_dir/FeedbackView.swift" "$source_dir/FeedbackReader.swift" "$source_dir/FeedbackPreview.swift" "$source_dir/FeedbackRubricView.swift" "$source_dir/FeedbackExport.swift" "$source_dir/FeedbackPDF.swift" "$source_dir/FeedbackReading.swift" "$source_dir/FeedbackCopyActions.swift" "$source_dir/AssignmentDates.swift" -o "$app_dir/Contents/MacOS/AssignmentDates" \
  -framework SwiftUI -framework SwiftData -framework PDFKit -framework QuickLook -framework AppKit -framework Security -framework LocalAuthentication -framework ServiceManagement
seed_file="$source_dir/Seed.example.json"
iconset="$source_dir/.build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_dir/Assets/AppIcon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$source_dir/Assets/AppIcon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
if [[ -f "$source_dir/Seed.json" ]]; then seed_file="$source_dir/Seed.json"; fi
cp "$seed_file" "$app_dir/Contents/Resources/Seed.json"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>au.monty.assignmentdates</string>
<key>CFBundleName</key><string>Assignment Dates</string>
<key>CFBundleDisplayName</key><string>Assignment Dates</string>
<key>CFBundleExecutable</key><string>AssignmentDates</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.5</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$app_dir"
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
ditto --norsrc --noextattr "$app_dir" "$deliverable"
ditto -c -k --norsrc --noextattr --keepParent "$deliverable" "$output_dir/Assignment Dates.zip"
printf 'Built %s\n' "$deliverable"
