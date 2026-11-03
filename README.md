# Skywrite

Write notes straight on your Mac's screen. Each note is borderless text that stays on top of other windows.

Skywrite is in early development. This first step covers notes on screen; the menu bar icon, settings, All Notes and Recent come next.

## Using it

- Press the right Option key twice, or press ⌃⌥N. The pointer turns into a crosshair: click where the note should start, or drag a box to set its size. Press esc to cancel.
- Type. Press esc or click anywhere else to lock the note. It stays on top.
- A locked note: drag it to move it, click it to edit, click twice quickly to close it. Closing hides the note but keeps its file. ⌃⌥Z reopens the last closed note, and so does ⌘Z while Skywrite is the active app.
- While editing, drag the corners to change the width and height, or drag a dashed edge to change one side. Right-click and choose Fit Size to Text to go back.
- Scroll or pinch over a note to zoom it. Right-click and choose Reset Zoom to go back.

Notes are Markdown files in `~/Documents/Skywrite`. Their positions, sizes and zoom are kept in `~/Library/Application Support/io.github.goozhenjie.skywrite/notes.json`, so they come back where you left them after a restart.

## Permissions

Skywrite asks for Accessibility access so it can notice the Option key pressed twice while you are in another app. ⌃⌥N works without it.

## Building

Requires macOS 26. Built and tested with Xcode 27.2.

```bash
xcodebuild -project Skywrite.xcodeproj -scheme Skywrite -configuration Debug build
swift test --package-path Packages/SkywriteCore
```

UI tests in `SkywriteUITests/` click, type and scroll on your real screen, so leave the Mac alone while they run (about a minute). They need Automation Mode, which asks for an administrator password unless you turn the prompt off once:

```bash
sudo automationmodetool enable-automationmode-without-authentication
xcodebuild -project Skywrite.xcodeproj -scheme Skywrite test
```

The tests launch Skywrite with `--ui-testing`, which keeps notes in a temporary folder and skips the global shortcuts, so your own notes are not touched.

Builds are ad-hoc signed by default, so macOS asks for Accessibility access again after every rebuild. To keep the permission, sign with your own development certificate: create `Signing.local.xcconfig` next to `Signing.xcconfig` (it is ignored by git) with

```
DEVELOPMENT_TEAM = <your team ID>
CODE_SIGN_IDENTITY = Apple Development
```

and add `-allowProvisioningUpdates` to the first `xcodebuild` run.

The app target lives in `Skywrite/`. Logic that does not need AppKit (double-tap detection, resize and zoom math, note files) lives in the `SkywriteCore` package under `Packages/` and has its own tests.

## Contributing

Bug reports, ideas and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Skywrite is released under the [MIT License](LICENSE).
