import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'materials_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../widgets/announcement_list_view.dart';
import '../widgets/notification_center.dart';

class MainScreen extends StatefulWidget {
  // ... (All your existing final variables and constructor stay exactly the same)
  final Student student;
  final String internalUserId;
  final List<StudyMaterial> materials;
  final List<Announcement> announcements;
  final List<FacultyContact> faculty;
  final EduSyncSettings settings;
  final List<ClassSession> classes;
  final List<AppNotification> notifications;
  final Set<String> viewedAnnIds;
  final bool isSyncing;
  final Future<void> Function() onLogout;
  final Future<void> Function(Announcement ann) onAddAnnouncement;
  final Future<void> Function(String id) onDeleteAnnouncement;
  final Future<void> Function(ClassSession classData) onAddClass;
  final Future<void> Function(String id, Map<String, dynamic> updates) onUpdateClass;
  final Future<void> Function(String id) onDeleteClass;
  final Future<void> Function(String id) onCancelClass;
  final Future<void> Function(FacultyContact faculty) onAddFaculty;
  final Future<void> Function(StudyMaterial material) onAddMaterial;
  final Future<void> Function(String id) onDeleteMaterial;
  final void Function(String id) onDownloadMaterial;
  final void Function(EduSyncSettings newSettings) onUpdateSettings;
  final void Function(List<String> ids) onMarkAnnouncementsViewed;
  final void Function() onClearNotifications;
  final void Function(String id) onMarkNotificationRead;
  final VoidCallback onToggleFacultyVisibility;

  const MainScreen({
    super.key,
    required this.student,
    required this.internalUserId,
    required this.materials,
    required this.announcements,
    required this.faculty,
    required this.settings,
    required this.classes,
    required this.notifications,
    required this.viewedAnnIds,
    required this.isSyncing,
    required this.onLogout,
    required this.onAddAnnouncement,
    required this.onDeleteAnnouncement,
    required this.onAddClass,
    required this.onUpdateClass,
    required this.onDeleteClass,
    required this.onCancelClass,
    required this.onAddFaculty,
    required this.onAddMaterial,
    required this.onDeleteMaterial,
    required this.onDownloadMaterial,
    required this.onUpdateSettings,
    required this.onMarkAnnouncementsViewed,
    required this.onClearNotifications,
    required this.onMarkNotificationRead,
    required this.onToggleFacultyVisibility,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  AppTab _currentTab = AppTab.home;
  bool _isAnnViewOpen = false;
  String? _highlightedAnnId;
  bool _isNotifOpen = false;

  @override
  Widget build(BuildContext context) {
    // SaaS Colors
    const Color primaryBlue = Color(0xFF2563EB);
    const Color bgWhite = Colors.white;

    final Map<AppTab, Widget> screens = {
      AppTab.home: HomeScreen(
        student: widget.student,
        announcements: widget.announcements,
        classes: widget.classes,
        faculty: widget.faculty,
        notifications: widget.notifications,
        facultyVisible: widget.settings.facultyVisible,
        onOpenNotifications: () => setState(() => _isNotifOpen = true),
        onViewAllAnnouncements: () => setState(() => _isAnnViewOpen = true),
        onSelectAnnouncement: (id) => setState(() {
          _highlightedAnnId = id;
          _isAnnViewOpen = true;
        }),
        onPostAnnouncement: widget.onAddAnnouncement,
        onAddClass: widget.onAddClass,
        onAddFaculty: widget.onAddFaculty,
        onCancelClass: widget.onCancelClass,
        onToggleFacultyVisibility: widget.onToggleFacultyVisibility,
      ),
      AppTab.schedule: ScheduleScreen(
        classes: widget.classes,
        isRepresentative: widget.student.isRepresentative,
        onCancelClass: widget.onCancelClass,
        onUpdateClass: widget.onUpdateClass,
        onDeleteClass: widget.onDeleteClass,
      ),
      AppTab.materials: MaterialsScreen(
        materials: widget.materials,
        student: widget.student,
        onAddMaterial: widget.onAddMaterial,
        onDeleteMaterial: widget.onDeleteMaterial,
        onDownloadMaterial: widget.onDownloadMaterial,
      ),
      AppTab.chat: ChatScreen(
        student: widget.student,
        userId: widget.internalUserId,
      ),
      AppTab.profile: ProfileScreen(
        student: widget.student,
        settings: widget.settings,
        onUpdateSettings: widget.onUpdateSettings,
        onLogout: widget.onLogout,
      ),
    };

    return Scaffold(
      backgroundColor: bgWhite,
      body: Stack(
        children: [
          // Smooth tab transitions
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: screens[_currentTab]!,
          ),
          
          if (_isAnnViewOpen)
            AnnouncementListView(
              announcements: widget.announcements,
              viewedIds: widget.viewedAnnIds,
              highlightId: _highlightedAnnId,
              isRepresentative: widget.student.isRepresentative,
              onClose: () => setState(() {
                _isAnnViewOpen = false;
                _highlightedAnnId = null;
              }),
              onDelete: widget.onDeleteAnnouncement,
              onMarkViewed: widget.onMarkAnnouncementsViewed,
            ),
          if (_isNotifOpen)
            NotificationCenter(
              notifications: widget.notifications,
              onClose: () => setState(() => _isNotifOpen = false),
              onClear: widget.onClearNotifications,
              onMarkAsRead: widget.onMarkNotificationRead,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: bgWhite,
          indicatorColor: primaryBlue.withOpacity(0.1),
          height: 70,
          elevation: 0,
          selectedIndex: _currentTab.index,
          onDestinationSelected: (index) {
            setState(() {
              _currentTab = AppTab.values[index];
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _navItem(Icons.grid_view_rounded, Icons.grid_view_outlined, 'Home'),
            _navItem(Icons.calendar_today_rounded, Icons.calendar_today_outlined, 'Schedule'),
            _navItem(Icons.folder_rounded, Icons.folder_outlined, 'Files'),
            _navItem(Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
            _navItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  NavigationDestination _navItem(IconData selected, IconData unselected, String label) {
    return NavigationDestination(
      icon: Icon(unselected, color: const Color(0xFF64748B), size: 24),
      selectedIcon: Icon(selected, color: const Color(0xFF2563EB), size: 24),
      label: label,
    );
  }
}