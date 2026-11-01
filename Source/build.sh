#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
app_dir="$project_dir/PromptBar.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/Source/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Source/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 -module-cache-path "${TMPDIR:-/tmp}/promptbar-module-cache" "$project_dir/Source/Localization.swift" "$project_dir/Source/Core.swift" "$project_dir/Source/Model.swift" "$project_dir/Source/Views.swift" "$project_dir/Source/App.swift" -o "$app_dir/Contents/MacOS/PromptBar" -framework Cocoa -framework SwiftUI -framework Security -framework Carbon -framework QuartzCore
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "Built: $app_dir"
