import 'package:flutter/material.dart';

import 'package:alex_browser/browser/models/js_dialog_request.dart';
import 'package:alex_browser/core/utils/url_utils.dart';

/// Shows the native alert/confirm/prompt dialog for a [JsDialogRequest] and
/// returns the user's [JsDialogResult]. Mirrors how Chrome/Safari present
/// page-triggered `window.alert`/`confirm`/`prompt` calls as OS-native
/// dialogs rather than in-page content, so a page cannot spoof browser
/// chrome with its own dialog styling.
Future<JsDialogResult> showJsDialog(BuildContext context, JsDialogRequest request) async {
  final String host = UrlUtils.displayHost(request.url);

  switch (request.type) {
    case JsDialogType.alert:
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(host),
          content: Text(request.message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return JsDialogResult.ok;

    case JsDialogType.confirm:
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(host),
          content: Text(request.message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return confirmed == true ? JsDialogResult.ok : JsDialogResult.cancelled;

    case JsDialogType.prompt:
      final TextEditingController controller = TextEditingController(text: request.defaultValue ?? '');
      final String? value = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          title: Text(host),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(request.message),
              const SizedBox(height: 12),
              TextField(controller: controller, autofocus: true),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (value == null) return JsDialogResult.cancelled;
      return JsDialogResult(confirmed: true, promptValue: value);
  }
}
