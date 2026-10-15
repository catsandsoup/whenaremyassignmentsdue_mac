#!/bin/zsh
set -euo pipefail
source_dir="${0:A:h}"
mkdir -p "$source_dir/.build"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/ModelChecks.swift" -o "$source_dir/.build/model-checks"
"$source_dir/.build/model-checks" "$source_dir/Fixtures/Deadlines.json"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/APIChecks.swift" -o "$source_dir/.build/api-checks"
"$source_dir/.build/api-checks"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/TokenStore.swift" "$source_dir/CanvasStore.swift" "$source_dir/StoreChecks.swift" -framework AppKit -framework Security -o "$source_dir/.build/store-checks"
"$source_dir/.build/store-checks" "$source_dir/Fixtures/Deadlines.json"

xcrun swiftc "$source_dir/Models.swift" "$source_dir/FeedbackModels.swift" "$source_dir/FeedbackDesignFixture.swift" "$source_dir/FeedbackChecks.swift" -o "$source_dir/.build/feedback-checks"
"$source_dir/.build/feedback-checks"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/FeedbackModels.swift" "$source_dir/FeedbackAPI.swift" "$source_dir/FeedbackAPIChecks.swift" -o "$source_dir/.build/feedback-api-checks"
"$source_dir/.build/feedback-api-checks"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/FeedbackModels.swift" "$source_dir/FeedbackAPI.swift" "$source_dir/FeedbackDesignFixture.swift" "$source_dir/FeedbackPersistence.swift" "$source_dir/FeedbackPersistenceChecks.swift" -o "$source_dir/.build/feedback-persistence-checks" -framework SwiftData
"$source_dir/.build/feedback-persistence-checks"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/FeedbackModels.swift" "$source_dir/FeedbackAPI.swift" "$source_dir/FeedbackFiles.swift" "$source_dir/FeedbackFileChecks.swift" -o "$source_dir/.build/feedback-file-checks" -framework AppKit -framework PDFKit
"$source_dir/.build/feedback-file-checks"
xcrun swiftc "$source_dir/Models.swift" "$source_dir/APIClient.swift" "$source_dir/TokenStore.swift" "$source_dir/FeedbackModels.swift" "$source_dir/FeedbackAPI.swift" "$source_dir/FeedbackFiles.swift" "$source_dir/FeedbackPersistence.swift" "$source_dir/FeedbackDesignFixture.swift" "$source_dir/FeedbackStore.swift" "$source_dir/FeedbackStoreChecks.swift" -o "$source_dir/.build/feedback-store-checks" -framework AppKit -framework SwiftData -framework PDFKit -framework Security
"$source_dir/.build/feedback-store-checks"
xcrun swiftc "$source_dir/TokenStore.swift" "$source_dir/TokenStoreChecks.swift" -o "$source_dir/.build/token-store-checks" -framework Security -framework LocalAuthentication
"$source_dir/.build/token-store-checks"
