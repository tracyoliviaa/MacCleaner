# MacCleaner

MacCleaner is a private SwiftUI macOS utility app for local disk, memory, CPU, duplicate, large-file, and privacy cleanup workflows.

## Build

Open `MacCleaner.xcodeproj` in Xcode, select the `MacCleaner` scheme, and press Run.

You can also build from this folder:

```bash
xcodebuild -scheme MacCleaner -configuration Debug build
```

## Important

This app is intended for personal local use only. It does not include telemetry, analytics, remote storage, licensing, or network features.

The memory purge action calls `/usr/bin/sudo /usr/sbin/purge`. For that feature to work, build without App Sandbox and expect macOS to request an administrator password.

Cleanup actions default to moving files to Trash, with confirmation prompts before destructive operations.
