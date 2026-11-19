import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:alex_browser/browser/models/page_load_state.dart';

/// The main address/search bar: shows the current URL when unfocused (with
/// an HTTPS lock indicator and loading progress), and becomes an editable
/// field accepting either a URL or a search query when tapped — the core
/// "smart" address bar behavior of every modern mobile browser.
class AddressBar extends StatefulWidget {
  const AddressBar({
    super.key,
    required this.pageState,
    required this.isPrivate,
    required this.onSubmit,
    required this.onTapTabs,
    required this.onTapMenu,
    required this.tabCount,
  });

  final PageLoadState pageState;
  final bool isPrivate;
  final ValueChanged<String> onSubmit;
  final VoidCallback onTapTabs;
  final VoidCallback onTapMenu;
  final int tabCount;

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.pageState.url);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant AddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.pageState.url != widget.pageState.url) {
      _controller.text = widget.pageState.url;
    }
  }

  void _onFocusChange() {
    setState(() => _editing = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    } else {
      _controller.text = widget.pageState.url;
    }
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    widget.onSubmit(value.trim());
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isSecure = widget.pageState.isSecure;
    final bool hasError = widget.pageState.hasError;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 10),
          Icon(
            hasError
                ? Icons.warning_amber_rounded
                : (isSecure ? Icons.lock_rounded : Icons.info_outline_rounded),
            size: 16,
            color: hasError
                ? scheme.error
                : (isSecure ? Colors.green.shade600 : scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (KeyEvent event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                  _focusNode.unfocus();
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: _submit,
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search or type a URL',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          if (widget.pageState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: widget.pageState.progress > 0 && widget.pageState.progress < 1
                      ? widget.pageState.progress
                      : null,
                ),
              ),
            )
          else if (!_editing && widget.pageState.url.isNotEmpty)
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onSubmit(widget.pageState.url),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reload',
            ),
          _TabCountButton(count: widget.tabCount, onTap: widget.onTapTabs),
          IconButton(
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            onPressed: widget.onTapMenu,
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Menu',
          ),
        ],
      ),
    );
  }
}

class _TabCountButton extends StatelessWidget {
  const _TabCountButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.onSurfaceVariant, width: 1.4),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
