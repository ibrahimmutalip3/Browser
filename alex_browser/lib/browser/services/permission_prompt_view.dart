import 'package:flutter/material.dart';

import 'package:alex_browser/browser/models/permission_request.dart';
import 'package:alex_browser/core/services/permission_service.dart';
import 'package:alex_browser/core/utils/url_utils.dart';

/// Result the user chose for a [WebPermissionRequest], including whether to
/// remember the choice for this origin (so the site doesn't re-prompt on
/// every visit, mirroring Chrome/Safari's "site settings" behavior).
class PermissionPromptResult {
  const PermissionPromptResult({required this.decision, required this.remember});
  final PermissionDecision decision;
  final bool remember;
}

IconData _iconFor(WebPermissionType type) {
  switch (type) {
    case WebPermissionType.camera:
      return Icons.videocam_rounded;
    case WebPermissionType.microphone:
      return Icons.mic_rounded;
    case WebPermissionType.location:
      return Icons.location_on_rounded;
    case WebPermissionType.notifications:
      return Icons.notifications_rounded;
    case WebPermissionType.storage:
      return Icons.folder_rounded;
  }
}

/// Shows a native dialog explaining exactly which capability the site is
/// requesting (per requirement #15: "the user must understand which
/// permission a site is requesting") before deferring to the OS-level
/// permission prompt handled by [PermissionService].
Future<PermissionPromptResult> showPermissionPrompt(
  BuildContext context,
  WebPermissionRequest request,
) async {
  final String host = UrlUtils.displayHost(request.origin);
  final String typesLabel = request.types.map((WebPermissionType t) => PermissionService.instance.label(t)).join(', ');
  bool remember = true;

  final PermissionPromptResult? result = await showDialog<PermissionPromptResult>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) {
          return AlertDialog(
            icon: Icon(
              request.types.isNotEmpty ? _iconFor(request.types.first) : Icons.security_rounded,
              size: 32,
            ),
            title: Text('Allow $host to use your $typesLabel?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'This website is requesting access to your $typesLabel. '
                  'You can change this later in Settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: remember,
                  title: const Text('Remember my choice for this site'),
                  onChanged: (bool? value) => setState(() => remember = value ?? true),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(
                  PermissionPromptResult(decision: PermissionDecision.deny, remember: remember),
                ),
                child: const Text('Block'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(
                  PermissionPromptResult(decision: PermissionDecision.allow, remember: remember),
                ),
                child: const Text('Allow'),
              ),
            ],
          );
        },
      );
    },
  );

  return result ?? const PermissionPromptResult(decision: PermissionDecision.deny, remember: false);
}
