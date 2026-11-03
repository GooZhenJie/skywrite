# Contributing to Skywrite

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Reporting a bug or asking for a feature

Open an issue and pick **Bug report** or **Feature request**. For bugs, the steps to reproduce and your macOS version matter most.

## Building

You need macOS 26 or later. See [Building](README.md#building) in the README for the Xcode version, the commands, and how to sign with your own certificate so macOS keeps the Accessibility permission between builds.

## Before opening a pull request

1. Keep each pull request to one change, and describe what a user will notice.
2. Run the unit tests: `swift test --package-path Packages/SkywriteCore`.
3. If you changed clicking, dragging, typing or zooming, run the UI tests too (see the README; they take over the mouse for about a minute).
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
