import 'package:flutter/material.dart';

enum AssistantActionType {
  openScreen,
  whatsappDebtor,
  openSuppliers,
  openPos,
  openReports,
  restockProduct,
}

class AssistantMetric {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  AssistantMetric({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });
}

class AssistantItem {
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final Map<String, dynamic>? extraData;

  AssistantItem({
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    this.extraData,
  });
}

class AssistantAction {
  final String label;
  final IconData icon;
  final AssistantActionType actionType;
  final Map<String, dynamic>? payload;

  AssistantAction({
    required this.label,
    required this.icon,
    required this.actionType,
    this.payload,
  });
}

class AssistantMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? intent;
  final List<AssistantMetric>? metrics;
  final List<AssistantItem>? items;
  final List<AssistantAction>? actions;

  AssistantMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.intent,
    this.metrics,
    this.items,
    this.actions,
  });
}
