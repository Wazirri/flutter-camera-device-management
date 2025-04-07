import 'package:flutter/material.dart';

class MenuItemData {
  final String route;
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final List<MenuItemData>? subItems;
  final bool isVisible;

  MenuItemData({
    required this.route,
    required this.title,
    required this.icon,
    required this.activeIcon,
    this.subItems,
    this.isVisible = true,
  });

  // Create a copy of this menu item with different visibility
  MenuItemData copyWith({
    String? route,
    String? title,
    IconData? icon,
    IconData? activeIcon,
    List<MenuItemData>? subItems,
    bool? isVisible,
  }) {
    return MenuItemData(
      route: route ?? this.route,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      subItems: subItems ?? this.subItems,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}
