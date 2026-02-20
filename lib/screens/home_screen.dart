import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/announcement_board.dart';
import '../widgets/countdown_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/schedule_timeline.dart';
import '../widgets/faculty_contacts.dart';

class HomeScreen extends StatelessWidget {
  final Student student;
  final List<Announcement> announcements;
  final List<ClassSession> classes;
  final List<FacultyContact> faculty;
  final List<AppNotification> notifications;
  final bool facultyVisible;
  final VoidCallback onOpenNotifications;
  final VoidCallback onViewAllAnnouncements;
  final void Function(String id) onSelectAnnouncement;
  final Future<void> Function(Announcement ann) onPostAnnouncement;
  final Future<void> Function(ClassSession classData) onAddClass;
  final Future<void> Function(FacultyContact faculty) onAddFaculty;
  final Future<void> Function(String id) onCancelClass;
  final VoidCallback onToggleFacultyVisibility;

  const HomeScreen({
    super.key,
    required this.student,
    required this.announcements,
    required this.classes,
    required this.faculty,
    required this.notifications,
    this.facultyVisible = true,
    required this.onOpenNotifications,
    required this.onViewAllAnnouncements,
    required this.onSelectAnnouncement,
    required this.onPostAnnouncement,
    required this.onAddClass,
    required this.onAddFaculty,
    required this.onCancelClass,
    required this.onToggleFacultyVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    Theme.of(context).colorScheme.primary.withOpacity(0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FidelShare',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Section ${student.section}'.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: onOpenNotifications,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.notifications_outlined),
                          if (notifications.any((n) => !n.read))
                            Positioned(
                              right: 14,
                              top: 14,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (classes.isNotEmpty) CountdownCard(classes: classes),
            AnnouncementBoard(
              announcements: announcements,
              onViewAll: onViewAllAnnouncements,
              onSelect: (a) => onSelectAnnouncement(a.id),
              isRepresentative: student.isRepresentative,
            ),
            const SizedBox(height: 16),
            QuickActions(
              student: student,
              onPostAnnouncement: onPostAnnouncement,
              onAddClass: onAddClass,
              onAddFaculty: onAddFaculty,
            ),
            const SizedBox(height: 24),
            ScheduleTimeline(
              classes: classes.where((c) => c.status != 'cancelled' || student.isRepresentative).toList(),
              isRepresentative: student.isRepresentative,
              onCancelClass: onCancelClass,
            ),
            const SizedBox(height: 24),
            FacultyContactsView(
              faculty: faculty,
              visible: facultyVisible,
              isRepresentative: student.isRepresentative,
              onToggleVisibility: onToggleFacultyVisibility,
            ),
          ],
        ),
      ),
    );
  }
}
