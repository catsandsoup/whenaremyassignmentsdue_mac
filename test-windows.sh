#!/bin/zsh
set -euo pipefail
source_dir="${0:A:h}"
check_dir="$source_dir/.build/window-checks"
mkdir -p "$check_dir"
# Keep the production App/Scene definitions; replace only the process entry point.
sed '/^@main$/d' "$source_dir/AssignmentDates.swift" > "$check_dir/AssignmentDates.swift"
sources=()
for file in "$source_dir"/*.swift; do
  case "${file:t}" in
    *Checks.swift|AssignmentDates.swift) ;;
    *) sources+=("$file") ;;
  esac
done
xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 "${sources[@]}" "$check_dir/AssignmentDates.swift" "$source_dir/WindowChecks.swift" -o "$check_dir/window-checks" -framework SwiftUI -framework SwiftData -framework PDFKit -framework QuickLook -framework AppKit -framework Security -framework LocalAuthentication -framework ServiceManagement
if result="$("$check_dir/window-checks" --feedback-offline --feedback-data-dir "$check_dir/Feedback")"; then
  :
else
  print -r -- "$result"
  exit 1
fi
print -r -- "$result"
# SwiftUI terminating before the final assertion must fail the test too.
[[ "$result" == *"PASS: "* ]]
