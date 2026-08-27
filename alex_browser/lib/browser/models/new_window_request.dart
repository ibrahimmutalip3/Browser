/// A request from the page to open a new browsing context — either from
/// `target="_blank"`, `window.open()`, or a middle-click/long-press on a
/// link. The browser UI decides whether to open this as a new foreground
/// tab, a new background tab, or (if popups are blocked) to discard it.
class NewWindowRequest {
  const NewWindowRequest({
    required this.url,
    required this.isUserGesture,
  });

  final String url;

  /// True if the window.open() call happened as a direct result of a user
  /// gesture (tap/click). Browsers use this to distinguish legitimate
  /// popups (e.g. OAuth login windows) from abusive ad popups fired by
  /// script on page load.
  final bool isUserGesture;
}
