# CI/CD

The GitHub Actions workflow uses the hosted `macos-26` runner. It includes
macOS 26 and Xcode 26, which are required to compile the native SwiftUI
Liquid Glass API used by this project.

Each push or pull request that changes `macos-swiftui/` runs:

1. `swift build -c release`
2. Uploads the unsigned executable as a workflow artifact.

The uploaded artifact is for CI verification only; macOS distribution requires
an app bundle plus signing and notarization. Add these repository secrets before
enabling a release workflow:

- `APPLE_DEVELOPER_ID_APPLICATION`
- `APPLE_DEVELOPER_ID_INSTALLER` (only for a signed installer)
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD` (for notarization)
- Base64-encoded signing certificate and its password

The release workflow should archive an Xcode `.app` target, codesign it with a
Developer ID certificate, submit it to `notarytool`, staple the ticket, and only
then attach the DMG/ZIP to a GitHub Release.
