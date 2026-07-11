import 'package:flutter/material.dart';

class DashboardItem {
  final String title;
  final String description;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final int? count;
  final String route;
  final Map<String, dynamic>? arguments;
  final bool enabled;

  const DashboardItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    this.count,
    required this.route,
    this.arguments,
    this.enabled = true,
  });

  DashboardItem copyWith({
    String? title,
    String? description,
    IconData? icon,
    Color? backgroundColor,
    Color? borderColor,
    int? count,
    String? route,
    Map<String, dynamic>? arguments,
    bool? enabled,
  }) {
    return DashboardItem(
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      count: count ?? this.count,
      route: route ?? this.route,
      arguments: arguments ?? this.arguments,
      enabled: enabled ?? this.enabled,
    );
  }
}

