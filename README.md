# ![](AirCopy/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png) AirCopy

AirCopy is an OSX status bar app that lets you transfer clipboard contents between devices within the same local network.

![](docs/screenshot_01.png)

### Requirements

**To run**: Mac OS X 10.9 and above

**To build**: Xcode 7.2, Swift 2.1

### Features

- preview current clipboard contents (as of now, text and images only)
- discover devices on the local network that are also running AirCopy
- send current clipboard to the selected device using secure transport (SSL)
- receive clipboards from other devices
- apply or delete received content

### Coming soon

- support for previewing more content types
- localization
- rewriting the whole thing with RxSwift for a change
- iOS support
- notifications on incoming content
- maybe an AppStore submission for the lazy devs
