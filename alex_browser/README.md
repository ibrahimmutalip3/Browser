# Alex Browser

A full-featured mobile web browser built with Flutter. Android is powered
by the system WebView (a genuine Chromium/Blink engine kept up to date via
Google Play system updates); iOS uses WKWebView (WebKit) — the only
rendering engine Apple permits third-party apps to embed on that platform
(App Store Review Guideline 2.5.6).

## Repository structure

```
/
├── .github/
│   └── workflows/
│       ├── android.yml   # builds a release APK on every push
│       └── ios.yml       # builds an unsigned IPA on every push
│
└── alex_browser/         # the Flutter project itself
    ├── android/
    ├── ios/
    ├── lib/
    ├── assets/
    ├── test/
    └── pubspec.yaml
```

## Building

This project is built exclusively through GitHub Actions — no local Flutter
installation is required.

### Android

Push to `main` (or run the workflow manually from the Actions tab). The
**Android** workflow produces `app-release.apk`, uploaded as the
`alex-browser-android-release-apk` artifact. It is signed with Flutter's
debug keystore by default, so it installs directly on any device with
"install from unknown sources" enabled — no Play Store needed. See
`alex_browser/android/key.properties.example` if you want to sign it with
your own release keystore instead.

### iOS

The **iOS** workflow builds `Runner.app` with `flutter build ios --release
--no-codesign` and repackages it as `AlexBrowser.ipa`, uploaded as the
`alex-browser-ios-unsigned-ipa` artifact. This IPA is **unsigned** — no
Apple Developer certificate, provisioning profile, or signing secret is
used or required anywhere in this repository. After downloading it, sign
it yourself (e.g. with ESign) before installing it on a device.

## Features

- Tabs (normal + private/incognito), with session restore
- Full address bar with smart URL/search detection (Google, Bing, or
  DuckDuckGo, switchable in Settings)
- History with search, per-item delete, and clear-by-range
- Bookmarks with folders and search
- Download manager with live progress/speed, cancel, retry, and open
- Site permissions (camera, microphone, location, notifications) with
  per-origin remember/forget, backed by real OS-level permission prompts
- JavaScript dialogs (alert/confirm/prompt), new-window/popup handling,
  and WebRTC support
- Cookie, cache, and site-data controls, plus a full "Clear browsing data"
  flow
- Light/Dark/System theming, with a distinct private-mode visual style
- Native error pages for offline, DNS, timeout, connection-refused, and
  SSL/certificate failures
- External URL scheme handoff (`tel:`, `mailto:`, `sms:`, `geo:`,
  `intent:`, and more) to the OS
