import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/browser/engine/browser_engine.dart';
import 'package:alex_browser/browser/models/js_dialog_request.dart';
import 'package:alex_browser/browser/models/page_load_state.dart';
import 'package:alex_browser/browser/services/error_page.dart';
import 'package:alex_browser/browser/services/js_dialog_view.dart';
import 'package:alex_browser/browser/services/permission_prompt_view.dart';
import 'package:alex_browser/core/theme/app_theme.dart';
import 'package:alex_browser/settings/controllers/settings_controller.dart';
import 'package:alex_browser/tabs/controllers/tabs_controller.dart';
import 'package:alex_browser/tabs/models/browser_tab.dart';
import 'package:alex_browser/tabs/views/address_bar.dart';
import 'package:alex_browser/ui/screens/bookmarks_screen.dart';
import 'package:alex_browser/ui/screens/downloads_screen.dart';
import 'package:alex_browser/ui/screens/history_screen.dart';
import 'package:alex_browser/ui/screens/settings_screen.dart';
import 'package:alex_browser/ui/screens/tab_manager_screen.dart';
import 'package:alex_browser/ui/widgets/browser_menu_sheet.dart';

/// The root screen of Alex Browser: owns the tab strip's visible surface
/// (address bar + live WebView content + bottom navigation bar), and
/// listens for cross-cutting engine events (JS dialogs, permission
/// requests) that need a native Flutter overlay regardless of which tab
/// triggered them.
class BrowserShell extends ConsumerStatefulWidget {
  const BrowserShell({super.key});

  @override
  ConsumerState<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends ConsumerState<BrowserShell> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(tabsControllerProvider.notifier).restoreOrCreateInitial();
    if (!mounted) return;
    setState(() => _initialized = true);
    _listenForPrompts();
  }

  void _listenForPrompts() {
    ref.read(tabsControllerProvider.notifier).prompts.listen((PendingPrompt prompt) async {
      if (!mounted) return;
      if (prompt is PendingJsDialogPrompt) {
        final JsDialogResult result = await showJsDialog(context, prompt.request);
        ref.read(tabsControllerProvider.notifier).resolveJsDialog(prompt.tabId, result);
      } else if (prompt is PendingPermissionPrompt) {
        final PermissionPromptResult result = await showPermissionPrompt(context, prompt.request);
        await ref.read(tabsControllerProvider.notifier).resolvePermission(
              prompt.tabId,
              prompt.request,
              result.decision,
              remember: result.remember,
            );
      }
    });
  }

  void _openTabManager() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TabManagerScreen()),
    );
  }

  void _openMenu() {
    final TabsState tabsState = ref.read(tabsControllerProvider);
    final BrowserTab? tab = tabsState.activeTab;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => BrowserMenuSheet(
        currentUrl: tab?.url ?? '',
        currentTitle: tab?.title ?? '',
        onHistory: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()));
        },
        onBookmarks: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BookmarksScreen()));
        },
        onDownloads: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()));
        },
        onSettings: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
        },
        onNewTab: () {
          Navigator.of(ctx).pop();
          ref.read(tabsControllerProvider.notifier).openNewTab(isPrivate: false);
        },
        onNewPrivateTab: () {
          Navigator.of(ctx).pop();
          ref.read(tabsControllerProvider.notifier).openNewTab(isPrivate: true);
        },
      ),
    );
  }

  Future<bool> _handleBackButton() async {
    final TabsController controller = ref.read(tabsControllerProvider.notifier);
    final BrowserTab? tab = ref.read(tabsControllerProvider).activeTab;
    if (tab == null) return true;
    final BrowserEngine? engine = controller.engineFor(tab.id);
    if (engine != null && await engine.canGoBack()) {
      await controller.goBackActiveTab();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final TabsState tabsState = ref.watch(tabsControllerProvider);
    final BrowserTab? activeTab = tabsState.activeTab;
    final TabsController controller = ref.read(tabsControllerProvider.notifier);

    final bool isPrivate = activeTab?.isPrivate ?? false;
    final ThemeData effectiveTheme = isPrivate ? PrivateModeTheme.theme() : Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        final bool shouldPop = await _handleBackButton();
        if (shouldPop && mounted) {
          // At the root of the navigation stack with nowhere left to go
          // back to inside the page itself; let the OS handle it (e.g.
          // minimize the app) by not intercepting further.
        }
      },
      child: Theme(
        data: effectiveTheme,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: AddressBar(
                    pageState: activeTab?.pageState ?? PageLoadState.initial,
                    isPrivate: isPrivate,
                    tabCount: isPrivate ? tabsState.privateTabs.length : tabsState.normalTabs.length,
                    onSubmit: (String input) => controller.navigateActiveTab(input),
                    onTapTabs: _openTabManager,
                    onTapMenu: _openMenu,
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: tabsState.tabs.indexWhere((BrowserTab t) => t.id == activeTab?.id).clamp(
                          0,
                          tabsState.tabs.isEmpty ? 0 : tabsState.tabs.length - 1,
                        ),
                    children: tabsState.tabs.isEmpty
                        ? const <Widget>[SizedBox.shrink()]
                        : tabsState.tabs.map((BrowserTab tab) {
                            final BrowserEngine? engine = controller.engineFor(tab.id);
                            return Stack(
                              children: <Widget>[
                                if (engine != null) Positioned.fill(child: engine.buildView()),
                                if (tab.pageState.hasError)
                                  Positioned.fill(
                                    child: ErrorPage(
                                      state: tab.pageState,
                                      onReload: () => controller.reloadActiveTab(),
                                      onGoHome: () => controller.navigateActiveTab(
                                        ref.read(settingsControllerProvider).homepage,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
                _BottomNavBar(
                  canGoBack: activeTab?.pageState.canGoBack ?? false,
                  canGoForward: activeTab?.pageState.canGoForward ?? false,
                  isPrivate: isPrivate,
                  onBack: () => controller.goBackActiveTab(),
                  onForward: () => controller.goForwardActiveTab(),
                  onHome: () => controller.navigateActiveTab(
                    ref.read(settingsControllerProvider).homepage,
                  ),
                  onNewTab: () => controller.openNewTab(isPrivate: isPrivate),
                  onTabs: _openTabManager,
                  onMenu: _openMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.isPrivate,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onNewTab,
    required this.onTabs,
    required this.onMenu,
  });

  final bool canGoBack;
  final bool canGoForward;
  final bool isPrivate;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onNewTab;
  final VoidCallback onTabs;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return BottomAppBar(
      height: 56,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.arrow_back_rounded),
            color: scheme.onSurface,
          ),
          IconButton(
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            color: scheme.onSurface,
          ),
          IconButton(
            onPressed: onHome,
            icon: const Icon(Icons.home_rounded),
            color: scheme.onSurface,
          ),
          IconButton(
            onPressed: onNewTab,
            icon: const Icon(Icons.add_rounded),
            color: scheme.onSurface,
          ),
          IconButton(
            onPressed: onTabs,
            icon: Icon(isPrivate ? Icons.security_rounded : Icons.layers_rounded),
            color: scheme.onSurface,
          ),
        ],
      ),
    );
  }
}
