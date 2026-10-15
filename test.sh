#!/bin/zsh
set -euo pipefail
source_dir="${0:A:h}"
mkdir -p "$source_dir/.build"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/ModelChecks.swift" -o "$source_dir/.build/model-checks"
"$source_dir/.build/model-checks" "$source_dir/Fixtures/Deadlines.json"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/APIChecks.swift" -o "$source_dir/.build/api-checks"
"$source_dir/.build/api-checks"
