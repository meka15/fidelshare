import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

class ScheduleTimeline extends StatelessWidget {
  final List<ClassSession> classes;
  final bool isRepresentative;
  final Future<void> Function(String id) onCancelClass;

  const ScheduleTimeline({
    super.key,
    required this.classes,
    required this.isRepresentative,
    required this.onCancelClass,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    // Filter for today's classes
    final todayClasses = classes.where((c) {
      if (c.status == 'cancelled' && !isRepresentative) return false;
      return c.dayOfWeek == now.weekday;
    }).toList();

    todayClasses.sort((a, b) => a.time.compareTo(b.time)); // Sorting by time string

    if (todayClasses.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's Schedule",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: todayClasses.length,
          itemBuilder: (context, index) {
            final c = todayClasses[index];
            final isCancelled = c.status == 'cancelled';
            
            // Logic to determine time state
            // Note: In a real app, parse c.time into a DateTime object for precise comparison
            final isOngoing = !isCancelled && _checkIsOngoing(c.time); 

            return _TimelineItem(
              session: c,
              isFirst: index == 0,
              isLast: index == todayClasses.length - 1,
              isOngoing: isOngoing,
              isCancelled: isCancelled,
              isRepresentative: isRepresentative,
              onToggleCancel: () => onCancelClass(c.id),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text("🎉", style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            "No classes today!",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  bool _checkIsOngoing(String timeStr) {
    // Simple mock logic: if the hour matches now, call it ongoing
    // Replace with actual DateTime parsing for production
    final hourNow = DateTime.now().hour;
    return timeStr.contains(hourNow.toString().padLeft(2, '0'));
  }
}

class _TimelineItem extends StatelessWidget {
  final ClassSession session;
  final bool isFirst;
  final bool isLast;
  final bool isOngoing;
  final bool isCancelled;
  final bool isRepresentative;
  final VoidCallback onToggleCancel;

  const _TimelineItem({
    required this.session,
    required this.isFirst,
    required this.isLast,
    required this.isOngoing,
    required this.isCancelled,
    required this.isRepresentative,
    required this.onToggleCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = isOngoing ? colorScheme.primary : Colors.grey.shade400;

    return IntrinsicHeight(
      child: Row(
        children: [
          // Left Side: Timeline indicators
          SizedBox(
            width: 70,
            child: Column(
              children: [
                if (!isFirst) Container(width: 2, height: 20, color: Colors.grey.shade200),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOngoing ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    EthiopianTimeUtils.formatString(session.time),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOngoing ? colorScheme.onPrimary : Colors.black54,
                    ),
                  ),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : Colors.grey.shade200)),
              ],
            ),
          ),
          
          // Right Side: Class Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 4, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOngoing ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOngoing ? colorScheme.primary.withOpacity(0.5) : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCancelled ? Colors.grey : null,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.room_outlined, size: 14, color: colorScheme.secondary),
                            const SizedBox(width: 4),
                            Text(session.room, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 12),
                            Icon(Icons.person_outline, size: 14, color: colorScheme.secondary),
                            const SizedBox(width: 4),
                            Flexible(child: Text(session.instructor, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isCancelled)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Badge(label: Text("CANCELLED"), backgroundColor: Colors.red),
                    ),
                  if (isRepresentative)
                    IconButton(
                      icon: Icon(
                        isCancelled ? Icons.restore : Icons.block,
                        size: 20,
                        color: isCancelled ? Colors.green : Colors.red,
                      ),
                      onPressed: onToggleCancel,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}