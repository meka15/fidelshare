import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class NotificationCenter extends StatelessWidget {
  final List<AppNotification> notifications;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final void Function(String id) onMarkAsRead;
  final void Function(String id)? onDelete; // Added individual delete

  const NotificationCenter({
    super.key,
    required this.notifications,
    required this.onClose,
    required this.onClear,
    required this.onMarkAsRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Sort notifications: Unread first, then by most recent timestamp
    final sortedNotifications = [...notifications]
      ..sort((a, b) {
        if (a.read != b.read) return a.read ? 1 : -1;
        return b.timestamp.compareTo(a.timestamp);
      });

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5), // Slightly darker for better focus
        child: GestureDetector(
          onTap: onClose, // Tap background to close
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent tap-through closing when touching the panel
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)
                  ],
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7, // Responsive height
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const Divider(height: 1),
                    Expanded(
                      child: notifications.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: sortedNotifications.length,
                              separatorBuilder: (_, __) => const Divider(indent: 70, height: 1),
                              itemBuilder: (context, index) {
                                final n = sortedNotifications[index];
                                return _buildNotificationItem(context, n);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final unreadCount = notifications.where((n) => !n.read).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          const Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Badge.count(count: unreadCount, backgroundColor: Theme.of(context).colorScheme.primary),
          ],
          const Spacer(),
          if (notifications.isNotEmpty)
            TextButton(onPressed: onClear, child: const Text('Clear all')),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, AppNotification n) {
    final date = DateTime.fromMillisecondsSinceEpoch(n.timestamp);
    final isToday = DateTime.now().day == date.day;
    final timeStr = isToday ? DateFormat.jm().format(date) : DateFormat('MMM d').format(date);

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(n.id),
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        onTap: () => onMarkAsRead(n.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
        leading: CircleAvatar(
          backgroundColor: n.read 
              ? Theme.of(context).colorScheme.surfaceContainerHighest 
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            _getIconForType(n.title), // Dynamic icon based on title
            color: n.read ? Colors.grey : Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(timeStr, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.notifications_none, size: 64, color: Colors.grey.withOpacity(0.5)),
        const SizedBox(height: 16),
        const Text('All caught up!', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  IconData _getIconForType(String title) {
    final t = title.toLowerCase();
    if (t.contains('exam') || t.contains('quiz')) return Icons.school;
    if (t.contains('material') || t.contains('vault')) return Icons.cloud_upload;
    if (t.contains('announcement')) return Icons.campaign;
    return Icons.notifications;
  }
}