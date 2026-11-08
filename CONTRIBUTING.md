# Contributing to Skywrite

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Reporting a bug or asking for a feature

Open an issue and pick **Bug report** or **Feature request**. For bugs, the steps to reproduce and your macOS version matter most.

## Building

Requires macOS 26. Built and tested with Xcode 27.2. Swift Package Manager downloads Sparkle on the first build.

```bash
xcodebuild -project Skywrite.xcodeproj -scheme Skywrite -configuration Debug build
swift test --package-path Packages/SkywriteCore
```

The app is in `Skywrite/`. `Packages/SkywriteCore/` contains the note storage, input detection and geometry logic that runs without AppKit, along with its unit tests.

### UI tests

UI tests control the real mouse and keyboard. Allow about a minute without using the Mac while they run.

```bash
xcodebuild -project Skywrite.xcodeproj -scheme Skywrite test
```

Automation Mode may prompt for an administrator password. To disable that prompt for subsequent runs:

```bash
sudo automationmodetool enable-automationmode-without-authentication
```

Tests launch the app with `--ui-testing`, using temporary note storage and disabling global shortcuts.

### Code signing

Builds use ad-hoc signing by default. If you use the double-press shortcut, you may need to grant Accessibility access again after each rebuild.

To preserve that permission, sign with your own certificate. Create `Signing.local.xcconfig` next to `Signing.xcconfig` (the local file is ignored by Git):

```xcconfig
DEVELOPMENT_TEAM = <your team ID>
CODE_SIGN_IDENTITY = Apple Development
```

Add `-allowProvisioningUpdates` to the first `xcodebuild` run. The install script also accepts a certificate name from your keychain:

```bash
scripts/install-from-source.sh "<certificate name>"
```

## Before opening a pull request

1. Keep each pull request to one change, and describe what a user will notice.
2. Run the unit tests: `swift test --package-path Packages/SkywriteCore`.
3. If you changed clicking, dragging, typing or zooming, run the UI tests too (see [UI tests](#ui-tests); they take over the mouse for about a minute).
4. Run SwiftLint: `swiftlint lint --strict`. Install it with `brew install swiftlint`.
5. Put any new text the user sees in `Skywrite/Localizable.xcstrings`.

Every pull request is built, unit-tested and linted on GitHub automatically. UI tests are not run there, so mention in the pull request whether you ran them.

## Where things live

| Folder | What is in it |
|---|---|
| `Skywrite/` | The app: windows, menus, input handling |
| `Packages/SkywriteCore/` | Logic without AppKit (double-tap detection, resize and zoom math, note files) and its unit tests |
| `SkywriteUITests/` | UI tests that drive the real app |

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/), for example `fix: keep zoomed notes inside the screen`.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
