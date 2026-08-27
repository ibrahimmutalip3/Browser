import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:alex_browser/browser/repositories/site_permissions_repository.dart';
import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/core/services/permission_service.dart';
import 'package:alex_browser/settings/controllers/settings_controller.dart';
import 'package:alex_browser/settings/models/search_engine.dart';
import 'package:alex_browser/tabs/controllers/tabs_controller.dart';

/// The full Settings screen: search engine, homepage, appearance,
/// content controls (JavaScript / cookies / pop-ups / Do Not Track),
/// website permissions, downloads, clear browsing data, and About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsState settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(settingsControllerProvider.notifier);
    final TabsController tabsController = ref.read(tabsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('General'),
          ListTile(
            leading: const Icon(Icons.search_rounded),
            title: const Text('Search engine'),
            subtitle: Text(settings.searchEngine.name),
            onTap: () => _pickSearchEngine(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded),
            title: const Text('Homepage'),
            subtitle: Text(settings.homepage),
            onTap: () => _editHomepage(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.restore_rounded),
            title: const Text('Restore tabs on start'),
            subtitle: const Text('Reopen your tabs from last session'),
            value: settings.restoreTabsOnStart,
            onChanged: controller.setRestoreTabsOnStart,
          ),
          const Divider(height: 1),
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            onTap: () => _pickTheme(context, ref),
          ),
          const Divider(height: 1),
          const _SectionHeader('Privacy & content'),
          SwitchListTile(
            secondary: const Icon(Icons.javascript_rounded),
            title: const Text('JavaScript'),
            subtitle: const Text('Allow sites to run JavaScript'),
            value: settings.javaScriptEnabled,
            onChanged: (bool value) async {
              await controller.setJavaScriptEnabled(value);
              await tabsController.applyJavaScriptEnabled(value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cookie_rounded),
            title: const Text('Cookies'),
            subtitle: const Text('Allow sites to save and read cookies'),
            value: settings.cookiesEnabled,
            onChanged: (bool value) async {
              await controller.setCookiesEnabled(value);
              await tabsController.applyCookiesEnabled(value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.block_rounded),
            title: const Text('Block pop-ups'),
            subtitle: const Text('Block pop-ups that aren\u2019t triggered by a tap'),
            value: settings.popupsBlocked,
            onChanged: controller.setPopupsBlocked,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_rounded),
            title: const Text('Do Not Track'),
            subtitle: const Text('Ask sites not to track you (not guaranteed to be honored)'),
            value: settings.doNotTrack,
            onChanged: (bool value) async {
              await controller.setDoNotTrack(value);
              await tabsController.applyDoNotTrack(value);
            },
          ),
          const Divider(height: 1),
          const _SectionHeader('Permissions'),
          ListTile(
            leading: const Icon(Icons.videocam_rounded),
            title: const Text('Camera'),
            subtitle: const Text('Manage camera access for websites'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSitePermissions(context, ref, WebPermissionType.camera),
          ),
          ListTile(
            leading: const Icon(Icons.mic_rounded),
            title: const Text('Microphone'),
            subtitle: const Text('Manage microphone access for websites'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSitePermissions(context, ref, WebPermissionType.microphone),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_rounded),
            title: const Text('Location'),
            subtitle: const Text('Manage location access for websites'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSitePermissions(context, ref, WebPermissionType.location),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: const Text('Notifications'),
            subtitle: const Text('Manage notification access for websites'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSitePermissions(context, ref, WebPermissionType.notifications),
          ),
          const Divider(height: 1),
          const _SectionHeader('Storage'),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Downloads'),
            subtitle: const Text('Clear download history'),
            onTap: () => _clearDownloads(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded),
            title: const Text('Clear browsing data'),
            subtitle: const Text('History, cookies, cache, site data'),
            onTap: () => _openClearBrowsingData(context, ref),
          ),
          const Divider(height: 1),
          const _SectionHeader('About'),
          const _AboutTile(),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  Future<void> _pickSearchEngine(BuildContext context, WidgetRef ref) async {
    final SearchEngine? selected = await showModalBottomSheet<SearchEngine>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SearchEngine.all
              .map(
                (SearchEngine engine) => ListTile(
                  title: Text(engine.name),
                  trailing: engine.id == ref.read(settingsControllerProvider).searchEngine.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(engine),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await ref.read(settingsControllerProvider.notifier).setSearchEngine(selected);
    }
  }

  Future<void> _editHomepage(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller =
        TextEditingController(text: ref.read(settingsControllerProvider).homepage);
    final String? newUrl = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Homepage'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://example.com'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newUrl != null && newUrl.isNotEmpty) {
      await ref.read(settingsControllerProvider.notifier).setHomepage(newUrl);
    }
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final ThemeMode? selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <ThemeMode>[ThemeMode.system, ThemeMode.light, ThemeMode.dark]
              .map(
                (ThemeMode mode) => ListTile(
                  title: Text(_themeLabel(mode)),
                  trailing: mode == ref.read(settingsControllerProvider).themeMode
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(mode),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await ref.read(settingsControllerProvider.notifier).setThemeMode(selected);
    }
  }

  Future<void> _openSitePermissions(BuildContext context, WidgetRef ref, WebPermissionType type) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SitePermissionsScreen(type: type)),
    );
  }

  Future<void> _clearDownloads(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear download history?'),
        content: const Text('This removes downloaded files\u2019 entries from the list. Files already saved to your device are not deleted.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(downloadsRepositoryProvider).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download history cleared')));
      }
    }
  }

  Future<void> _openClearBrowsingData(BuildContext context, WidgetRef ref) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClearBrowsingDataScreen()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AboutTile extends StatefulWidget {
  const _AboutTile();

  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // Best-effort only; leave blank if unavailable in this environment.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline_rounded),
      title: const Text('Alex Browser'),
      subtitle: Text(_version.isEmpty ? 'Version unavailable' : 'Version $_version'),
    );
  }
}

/// Lists every origin with a remembered decision for a single permission
/// type (e.g. all sites allowed/blocked to use the Camera), with the
/// ability to revoke individual entries or clear all.
class SitePermissionsScreen extends ConsumerStatefulWidget {
  const SitePermissionsScreen({super.key, required this.type});
  final WebPermissionType type;

  @override
  ConsumerState<SitePermissionsScreen> createState() => _SitePermissionsScreenState();
}

class _SitePermissionsScreenState extends ConsumerState<SitePermissionsScreen> {
  List<SitePermissionEntry> _entries = <SitePermissionEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<SitePermissionEntry> all =
        await ref.read(sitePermissionsRepositoryProvider).getAll();
    final List<SitePermissionEntry> filtered =
        all.where((SitePermissionEntry e) => e.type == widget.type).toList();
    if (!mounted) return;
    setState(() {
      _entries = filtered;
      _loading = false;
    });
  }

  Future<void> _revoke(SitePermissionEntry entry) async {
    await ref.read(sitePermissionsRepositoryProvider).clearForOrigin(entry.origin);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(PermissionService.instance.label(widget.type))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No sites have been granted or blocked yet'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SitePermissionEntry entry = _entries[index];
                    return ListTile(
                      title: Text(entry.origin),
                      subtitle: Text(entry.granted ? 'Allowed' : 'Blocked'),
                      leading: Icon(
                        entry.granted ? Icons.check_circle_rounded : Icons.block_rounded,
                        color: entry.granted ? Colors.green : Theme.of(context).colorScheme.error,
                      ),
                      trailing: TextButton(
                        onPressed: () => _revoke(entry),
                        child: const Text('Forget'),
                      ),
                    );
                  },
                ),
    );
  }
}

/// "Clear browsing data" flow: pick which categories to erase and a time
/// range, then execute across both the persisted stores and every
/// currently open engine.
class ClearBrowsingDataScreen extends ConsumerStatefulWidget {
  const ClearBrowsingDataScreen({super.key});

  @override
  ConsumerState<ClearBrowsingDataScreen> createState() => _ClearBrowsingDataScreenState();
}

class _ClearBrowsingDataScreenState extends ConsumerState<ClearBrowsingDataScreen> {
  bool _history = true;
  bool _cookies = true;
  bool _cache = true;
  bool _localStorage = true;
  bool _clearing = false;

  Future<void> _clear() async {
    setState(() => _clearing = true);
    await ref.read(tabsControllerProvider.notifier).clearBrowsingData(
          clearHistory: _history,
          clearCookies: _cookies,
          clearCache: _cache,
          clearLocalStorage: _localStorage,
        );
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Browsing data cleared')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clear browsing data')),
      body: ListView(
        children: <Widget>[
          CheckboxListTile(
            title: const Text('Browsing history'),
            value: _history,
            onChanged: (bool? v) => setState(() => _history = v ?? false),
          ),
          CheckboxListTile(
            title: const Text('Cookies'),
            subtitle: const Text('Signs you out of most sites'),
            value: _cookies,
            onChanged: (bool? v) => setState(() => _cookies = v ?? false),
          ),
          CheckboxListTile(
            title: const Text('Cached images and files'),
            value: _cache,
            onChanged: (bool? v) => setState(() => _cache = v ?? false),
          ),
          CheckboxListTile(
            title: const Text('Site data (localStorage, IndexedDB)'),
            value: _localStorage,
            onChanged: (bool? v) => setState(() => _localStorage = v ?? false),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: _clearing ? null : _clear,
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: _clearing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Clear data'),
            ),
          ),
        ],
      ),
    );
  }
}
