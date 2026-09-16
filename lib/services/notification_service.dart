import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static const String stockChannelKey = 'stock_alerts';
  static const String debtChannelKey = 'debt_alerts';
  static const String generalChannelKey = 'general_alerts';

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // Use default app launcher icon
      [
        NotificationChannel(
          channelKey: stockChannelKey,
          channelName: 'Low Stock Alerts',
          channelDescription: 'Notifications for items running low in inventory',
          defaultColor: const Color(0xFFFF6B00),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: debtChannelKey,
          channelName: 'Customer Debt Alerts',
          channelDescription: 'Notifications for high or overdue customer debts',
          defaultColor: const Color(0xFFFF6B00),
          ledColor: Colors.orange,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: generalChannelKey,
          channelName: 'Shop Updates & Testing',
          channelDescription: 'General shop alerts and notification test messages',
          defaultColor: const Color(0xFFFF6B00),
          ledColor: Colors.white,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
        ),
      ],
    );
  }

  /// Checks if notification permissions have been granted by user and enabled in app
  static Future<bool> isAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledInApp = prefs.getBool('enable_notifications') ?? true;
    if (!enabledInApp) return false;
    return await AwesomeNotifications().isNotificationAllowed();
  }

  /// Requests notification permission from user if not already granted
  static Future<bool> requestPermission() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    return isAllowed;
  }

  /// Triggers a Low Stock Warning notification
  static Future<void> showLowStockAlert(String productName, num qty) async {
    final allowed = await isAllowed();
    if (!allowed) return;

    final displayQty = qty is int || qty == qty.roundToDouble() 
        ? qty.toInt().toString() 
        : qty.toStringAsFixed(1);

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: stockChannelKey,
        title: '⚠️ Low Stock Alert',
        body: '$productName is running low ($displayQty remaining). Time to restock!',
        notificationLayout: NotificationLayout.Default,
        color: const Color(0xFFFF6B00),
      ),
    );
  }

  /// Triggers an alert when a customer debt reaches or exceeds a significant limit
  static Future<void> showDebtAlert({
    required String customerName,
    required double currentDebt,
    required double creditLimit,
  }) async {
    final allowed = await isAllowed();
    if (!allowed) return;

    final pct = creditLimit > 0 ? (currentDebt / creditLimit * 100).toInt() : 100;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: debtChannelKey,
        title: '💳 Customer Credit Limit Alert',
        body: '$customerName has used $pct% of credit limit (Debt: KES ${currentDebt.toStringAsFixed(0)} / Limit: KES ${creditLimit.toStringAsFixed(0)}).',
        notificationLayout: NotificationLayout.Default,
        color: const Color(0xFFFF6B00),
      ),
    );
  }

  /// Sends an immediate test notification to verify AwesomeNotifications is active
  static Future<bool> showTestNotification() async {
    final allowed = await requestPermission();
    if (!allowed) return false;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 999,
        channelKey: generalChannelKey,
        title: '🔔 M-Bizna Notifications Active',
        body: 'Awesome Notifications is working! Low stock alerts and customer credit warnings will appear here.',
        notificationLayout: NotificationLayout.Default,
        color: const Color(0xFFFF6B00),
      ),
    );
    return true;
  }
}