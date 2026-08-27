import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/core/services/preferences_service.dart';
import 'package:alex_browser/core/theme/app_theme.dart';
import 'package:alex_browser/settings/controllers/settings_controller.dart';
import 'package:alex_browser/ui/screens/browser_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PreferencesService wraps SharedPreferences, whose initialization is
  // asynchronous. It must finish before any provider that reads settings
  // (SettingsController, TabsController's homepage lookups, etc) runs, so
  // it is created here and injected via provider override rather than
  // built lazily inside a Riverpod provider.
  final PreferencesService preferences = await PreferencesService.init();

  runApp(
    ProviderScope(
      overrides: <Override>[
        preferencesServiceProvider.overrideWithValue(preferences),
      ],
      child: const AlexBrowserApp(),
    ),
  );
}

class AlexBrowserApp extends ConsumerWidget {
  const AlexBrowserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(
      settingsControllerProvider.select((SettingsState s) => s.themeMode),
    );

    return MaterialApp(
      title: 'Alex Browser',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const BrowserShell(),
    );
  }
}
