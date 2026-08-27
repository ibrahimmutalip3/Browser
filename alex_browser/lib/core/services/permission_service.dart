import 'package:permission_handler/permission_handler.dart';

/// The kinds of permissions a website can request through the WebView
/// (camera, microphone, geolocation, notifications). This is distinct from
/// the OS-level [Permission] enum from permission_handler, because a site
/// permission also needs to be remembered per-origin (see
/// SitePermissionsRepository), not just granted once at the OS level.
enum WebPermissionType {
  camera,
  microphone,
  location,
  notifications,
  storage,
}

/// Bridges OS-level runtime permissions (via permission_handler) with the
/// browser's per-site permission model. A website request first needs the
/// OS-level permission (camera/mic/location hardware access), and then the
/// browser's own site-permission decision (does *this* origin get to use
/// the camera the OS already allows the app to access).
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  Permission _osPermissionFor(WebPermissionType type) {
    switch (type) {
      case WebPermissionType.camera:
        return Permission.camera;
      case WebPermissionType.microphone:
        return Permission.microphone;
      case WebPermissionType.location:
        return Permission.locationWhenInUse;
      case WebPermissionType.notifications:
        return Permission.notification;
      case WebPermissionType.storage:
        return Permission.storage;
    }
  }

  /// Checks the current OS-level permission status without prompting.
  Future<PermissionStatus> checkStatus(WebPermissionType type) async {
    return _osPermissionFor(type).status;
  }

  /// Requests the OS-level permission, showing the native system prompt if
  /// it hasn't been decided yet. Returns true if granted.
  Future<bool> requestOsPermission(WebPermissionType type) async {
    final Permission permission = _osPermissionFor(type);
    final PermissionStatus status = await permission.status;

    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final PermissionStatus result = await permission.request();
    return result.isGranted;
  }

  /// Opens the system app settings screen — used when a permission was
  /// permanently denied and the user needs to enable it manually.
  Future<bool> openSystemSettings() => openAppSettings();

  String label(WebPermissionType type) {
    switch (type) {
      case WebPermissionType.camera:
        return 'Camera';
      case WebPermissionType.microphone:
        return 'Microphone';
      case WebPermissionType.location:
        return 'Location';
      case WebPermissionType.notifications:
        return 'Notifications';
      case WebPermissionType.storage:
        return 'Storage';
    }
  }
}
