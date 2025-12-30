import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // Use app icon
      [
        NotificationChannel(
          channelKey: 'stock_alerts',
          channelName: 'Stock Alerts',
          channelDescription: 'Notifications for low inventory',
          defaultColor: Color(0xFFFF6B00),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        )
      ],
    );
  }

  static Future<void> showLowStockAlert(String productName, int qty) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'stock_alerts',
        title: '⚠️ Low Stock Warning',
        body: 'Only $qty left of $productName. Time to restock!',
        notificationLayout: NotificationLayout.Default,
        color: Color(0xFFFF6B00),
      ),
    );
  }
}