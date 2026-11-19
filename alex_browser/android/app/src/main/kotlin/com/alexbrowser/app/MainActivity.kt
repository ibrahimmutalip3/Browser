package com.alexbrowser.app

import io.flutter.embedding.android.FlutterActivity

/**
 * Alex Browser's single native Android entry point.
 *
 * All actual browser logic (tabs, navigation, history, bookmarks,
 * downloads, settings) lives in Dart under lib/ and is rendered through
 * the standard Flutter engine. This activity intentionally stays a thin
 * [FlutterActivity] subclass — the WebView engine itself is embedded via
 * the flutter_inappwebview plugin's own platform views, which register
 * themselves automatically through Flutter's plugin registrant and need
 * no custom wiring here.
 */
class MainActivity : FlutterActivity()
