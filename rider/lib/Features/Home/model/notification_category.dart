import 'package:flutter/material.dart';

enum NotificationCategory { orders, payments, system }

class NotificationEntry {
  final String title;
  final String description;
  final String time;
  final String dayGroup;
  final NotificationCategory category;
  final IconData icon;

  const NotificationEntry({
    required this.title,
    required this.description,
    required this.time,
    required this.dayGroup,
    required this.category,
    required this.icon,
  });
}
