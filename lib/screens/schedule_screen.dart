import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/weekly_schedule.dart';

class ScheduleScreen extends StatelessWidget {
  final List<ClassSession> classes;
  final bool isRepresentative;
  final Future<void> Function(String id) onCancelClass;
  final Future<void> Function(String id, Map<String, dynamic> updates) onUpdateClass;
  final Future<void> Function(String id) onDeleteClass;

  const ScheduleScreen({
    super.key,
    required this.classes,
    required this.isRepresentative,
    required this.onCancelClass,
    required this.onUpdateClass,
    required this.onDeleteClass,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Schedule')),
      body: WeeklySchedule(
        classes: classes,
        isRepresentative: isRepresentative,
        onCancelClass: onCancelClass,
        onUpdateClass: onUpdateClass,
        onDeleteClass: onDeleteClass,
      ),
    );
  }
}
