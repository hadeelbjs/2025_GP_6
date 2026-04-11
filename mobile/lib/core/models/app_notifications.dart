enum NotificationType {
  wifiWarning,
  breachAlert,
  friendRequest,
  // ── Anomaly ──
  unknownDevice,
  newLocation,
  newWifi,
  failedAttempts,
  unusualChatActivity,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final bool? actionTaken; // null = لم يتصرف | true = أنا | false = لم أفعل


  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.actionTaken,
  });
  AppNotification copyWith({bool? isRead, bool? actionTaken}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      actionTaken: actionTaken ?? this.actionTaken,
    );
  }
}