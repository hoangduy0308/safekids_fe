import 'package:flutter/foundation.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  List<NotificationItem> get sortedNotifications {
    final sorted = List<NotificationItem>.from(_notifications);
    sorted.sort((a, b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      return b.timestamp.compareTo(a.timestamp);
    });
    return sorted;
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      _notifications = [
        NotificationItem(
          id: '1',
          childId: 'child1',
          childName: 'Hdi',
          category: NotificationCategory.alert,
          title: 'đã rời khỏi vùng an toàn',
          description: 'Vị trí: Ngoài nhà',
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
          isRead: false,
          actionLabel: 'Xem bản đồ',
          metadata: {'type': 'location', 'safe': false},
        ),
        NotificationItem(
          id: '2',
          childId: 'child1',
          childName: 'Hdi',
          category: NotificationCategory.update,
          title: 'đã vào vùng an toàn',
          description: 'Vị trí: Nhà',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isRead: false,
          actionLabel: 'Xem bản đồ',
          metadata: {'type': 'location', 'safe': true},
        ),
      ];

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Lỗi tải thông báo: $e';
      debugPrint('[NotificationProvider] Error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> dismissNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
  }

  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
