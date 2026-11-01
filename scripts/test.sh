#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/promptbar-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -swift-version 5 "$project_dir/Source/Localization.swift" "$project_dir/Source/Core.swift" "$project_dir/Source/CoreTests.swift" -o "$test_dir/core"
"$test_dir/core"
xcrun swiftc -swift-version 5 "$project_dir/Source/Localization.swift" "$project_dir/Source/Core.swift" "$project_dir/Source/Model.swift" "$project_dir/Source/StateTests.swift" -o "$test_dir/state"
"$test_dir/state"
