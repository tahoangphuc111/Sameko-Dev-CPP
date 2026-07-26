# SamekoMac

Native macOS fork of Sameko IDE, built with SwiftUI. It intentionally lives beside
the Electron application during migration so the current Windows product remains
buildable.

## Requirements

- macOS 26 or later for the system Liquid Glass material
- Xcode 26 or later with the macOS SDK and SwiftUI macro plugins installed
- Command Line Tools (`xcode-select --install`) are not sufficient to build this
  SwiftUI application on their own.

## Run

Open this directory as a Swift package in Xcode, choose the `SamekoMac` scheme,
then run it. From a fully installed Xcode command line, this also works:

```sh
swift run
```

## Current migration slice

- Native `NavigationSplitView` workspace shell and file sidebar
- Source editor and output console
- Build and run a saved C++ file with the system `clang++`
- Native Liquid Glass only on interaction chrome, via SwiftUI `glassEffect`
- In-app switch for Regular, Clear, or disabled glass

## Still to migrate

The Electron-specific services need native replacements: bundled GCC toolchain,
Monaco features, debugger protocol UI, Competitive Companion server, formatter,
local history, and auto-updater.
