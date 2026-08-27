import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/tabs/controllers/tabs_controller.dart';
import 'package:alex_browser/tabs/models/browser_tab.dart';

/// Full-screen tab manager: shows every open tab as a card (favicon,
/// title, URL, a live thumbnail placeholder) with tap-to-switch and
/// swipe/close-button to close, split into Normal and Private sections
/// mirroring Chrome/Safari's tab switcher.
class TabManagerScreen extends ConsumerStatefulWidget {
  const TabManagerScreen({super.key});

  @override
  ConsumerState<TabManagerScreen> createState() => _TabManagerScreenState();
}

class _TabManagerScreenState extends ConsumerState<TabManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _sectionController;

  @override
  void initState() {
    super.initState();
    _sectionController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TabsState tabsState = ref.watch(tabsControllerProvider);
    final TabsController controller = ref.read(tabsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabs'),
        bottom: TabBar(
          controller: _sectionController,
          tabs: <Widget>[
            Tab(text: 'Open (${tabsState.normalTabs.length})'),
            Tab(text: 'Private (${tabsState.privateTabs.length})'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New tab',
            onPressed: () async {
              final bool isPrivateSection = _sectionController.index == 1;
              await controller.openNewTab(isPrivate: isPrivateSection);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _sectionController,
        children: <Widget>[
          _TabGrid(
            tabs: tabsState.normalTabs,
            activeTabId: tabsState.activeTabId,
            emptyLabel: 'No open tabs',
            onSelect: (String id) {
              controller.setActiveTab(id);
              Navigator.of(context).pop();
            },
            onClose: (String id) => controller.closeTab(id),
          ),
          _TabGrid(
            tabs: tabsState.privateTabs,
            activeTabId: tabsState.activeTabId,
            emptyLabel: 'No private tabs',
            isPrivate: true,
            onSelect: (String id) {
              controller.setActiveTab(id);
              Navigator.of(context).pop();
            },
            onClose: (String id) => controller.closeTab(id),
            trailing: tabsState.privateTabs.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: () => controller.closeAllPrivateTabs(),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Close all private tabs'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TabGrid extends StatelessWidget {
  const _TabGrid({
    required this.tabs,
    required this.activeTabId,
    required this.emptyLabel,
    required this.onSelect,
    required this.onClose,
    this.isPrivate = false,
    this.trailing,
  });

  final List<BrowserTab> tabs;
  final String? activeTabId;
  final String emptyLabel;
  final bool isPrivate;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isPrivate ? Icons.security_rounded : Icons.layers_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(emptyLabel, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: tabs.length,
            itemBuilder: (BuildContext context, int index) {
              final BrowserTab tab = tabs[index];
              final bool isActive = tab.id == activeTabId;
              return _TabCard(
                tab: tab,
                isActive: isActive,
                isPrivate: isPrivate,
                onTap: () => onSelect(tab.id),
                onClose: () => onClose(tab.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.isActive,
    required this.isPrivate,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool isActive;
  final bool isPrivate;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? scheme.primary : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: <Widget>[
                    _Favicon(url: tab.faviconUrl, isPrivate: isPrivate),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onClose,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: isPrivate
                      ? scheme.surfaceContainerHighest
                      : scheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: Icon(
                    isPrivate ? Icons.security_rounded : Icons.public_rounded,
                    size: 40,
                    color: scheme.outlineVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  tab.url.isEmpty ? 'New Tab' : tab.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Favicon extends StatelessWidget {
  const _Favicon({required this.url, required this.isPrivate});
  final String? url;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    const double size = 16;
    if (url == null || url!.isEmpty) {
      return Icon(
        isPrivate ? Icons.security_rounded : Icons.public_rounded,
        size: size,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        url!,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          isPrivate ? Icons.security_rounded : Icons.public_rounded,
          size: size,
        ),
      ),
    );
  }
}
