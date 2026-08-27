/// The three kinds of native JavaScript dialogs a web page can trigger:
/// `window.alert()`, `window.confirm()`, and `window.prompt()`.
enum JsDialogType { alert, confirm, prompt }

/// A pending JavaScript dialog request surfaced by the browser engine.
/// The UI layer shows a native dialog and resolves it via the completer
/// held internally by the engine implementation.
class JsDialogRequest {
  const JsDialogRequest({
    required this.type,
    required this.url,
    required this.message,
    this.defaultValue,
  });

  final JsDialogType type;
  final String url;
  final String message;
  final String? defaultValue;
}

/// The result the user chose for a [JsDialogRequest].
class JsDialogResult {
  const JsDialogResult({required this.confirmed, this.promptValue});

  final bool confirmed;
  final String? promptValue;

  static const JsDialogResult cancelled = JsDialogResult(confirmed: false);
  static const JsDialogResult ok = JsDialogResult(confirmed: true);
}
