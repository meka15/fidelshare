import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class AnnouncementListView extends StatefulWidget {
  final List<Announcement> announcements;
  final Set<String> viewedIds;
  final void Function(List<String> ids)? onMarkViewed;
  final String? highlightId;
  final VoidCallback onClose;
  final Future<void> Function(String id)? onDelete;
  final bool isRepresentative;

  const AnnouncementListView({
    super.key,
    required this.announcements,
    required this.viewedIds,
    required this.onClose,
    required this.isRepresentative,
    this.onMarkViewed,
    this.highlightId,
    this.onDelete,
  });

  @override
  State<AnnouncementListView> createState() => _AnnouncementListViewState();
}

class _AnnouncementListViewState extends State<AnnouncementListView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    
    // Suggestion: Only mark as viewed if the list isn't empty
    if (widget.announcements.isNotEmpty) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          widget.onMarkViewed?.call(widget.announcements.map((a) => a.id).toList());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep sorting logic efficient
    final sorted = List<Announcement>.from(widget.announcements)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Positioned.fill(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            _buildAppBar(context, sorted.length),
            Expanded(
              child: ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = sorted[index];
                  final isUnread = !widget.viewedIds.contains(item.id);
                  
                  // Wrap in Dismissible if representative for better UX
                  if (widget.isRepresentative && widget.onDelete != null) {
                    return Dismissible(
                      key: Key(item.id),
                      direction: DismissDirection.endToStart,
                      background: _buildDeleteBackground(),
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) => widget.onDelete!(item.id),
                      child: _buildAnnouncementCard(context, item, isUnread),
                    );
                  }

                  return _buildAnnouncementCard(context, item, isUnread);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, int count) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: widget.onClose),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Class Board', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('$count Active Posts', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Announcement item, bool isUnread) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: isUnread ? 2 : 0,
      color: isUnread 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUnread 
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isUnread) 
                  const Badge(label: Text('NEW')) 
                else 
                  const SizedBox.shrink(),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(item.content, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('— ${item.authorName}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}