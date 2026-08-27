import 'package:alex_browser/core/services/permission_service.dart';

/// A pending request from a website (via getUserMedia, geolocation API,
/// Notification API, etc) for access to a sensitive capability.
class WebPermissionRequest {
  const WebPermissionRequest({
    required this.origin,
    required this.types,
  });

  final String origin;
  final List<WebPermissionType> types;
}

/// The decision the user made for a [WebPermissionRequest].
enum PermissionDecision { allow, deny }
