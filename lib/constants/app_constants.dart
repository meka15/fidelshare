import 'package:flutter/material.dart';
import '../models/models.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color backgroundWhite = Colors.white;
  static const Color surfaceLight = Color(0xFFF8FAFF);

  static const List<Color> primaryGradient = [primaryBlue, secondaryBlue];

  static const List<Color> fabGradient = [accentPurple, accentPink];
}

class TabConfig {
  static const tabs = [
    AppTab.home,
    AppTab.schedule,
    AppTab.materials,
    AppTab.profile,
  ];

  static IconData getIcon(AppTab tab, {bool selected = false}) {
    switch (tab) {
      case AppTab.home:
        return selected ? Icons.dashboard_rounded : Icons.dashboard_outlined;
      case AppTab.schedule:
        return selected ? Icons.event_note_rounded : Icons.event_note_outlined;
      case AppTab.materials:
        return selected
            ? Icons.folder_copy_rounded
            : Icons.folder_copy_outlined;
      case AppTab.profile:
        return selected
            ? Icons.account_circle_rounded
            : Icons.account_circle_outlined;
      case AppTab.chat:
        return selected
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded;
    }
  }
}
