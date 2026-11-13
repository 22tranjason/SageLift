// Keep browser-specific Google APIs out of the offline data layer.
export 'google_drive_sync_port_stub.dart'
    if (dart.library.html) 'google_drive_sync_port_web.dart';
