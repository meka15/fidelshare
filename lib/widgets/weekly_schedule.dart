import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

class WeeklySchedule extends StatefulWidget {
  final List<ClassSession> classes;
  final bool isRepresentative;
  final Future<void> Function(String id) onCancelClass;
  final Future<void> Function(String id, Map<String, dynamic> updates) onUpdateClass;

  const WeeklySchedule({
    super.key,
    required this.classes,
    required this.isRepresentative,
    required this.onCancelClass,
    required this.onUpdateClass,
  });

  @override
  State<WeeklySchedule> createState() => _WeeklyScheduleState();
}

class _WeeklyScheduleState extends State<WeeklySchedule> {
  final List<Map<String, dynamic>> days = const [
    {'id': 1, 'label': 'Mon', 'full': 'Monday'},
    {'id': 2, 'label': 'Tue', 'full': 'Tuesday'},
    {'id': 3, 'label': 'Wed', 'full': 'Wednesday'},
    {'id': 4, 'label': 'Thu', 'full': 'Thursday'},
    {'id': 5, 'label': 'Fri', 'full': 'Friday'},
  ];

  late dynamic activeDay;

  @override
  void initState() {
    super.initState();
    final current = DateTime.now().weekday;
    activeDay = current >= 1 && current <= 5 ? current : 1;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildHeader(context),
        _buildDaySelector(colorScheme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: activeDay == 'all' ? _buildFullWeek() : _buildSingleDay(activeDay),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly Schedule', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text('Theory & Lab sessions', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          ActionChip(
            avatar: Icon(activeDay == 'all' ? Icons.calendar_view_day : Icons.calendar_view_week, size: 16),
            label: Text(activeDay == 'all' ? 'Daily View' : 'Full Week'),
            onPressed: () => setState(() => activeDay = activeDay == 'all' ? (DateTime.now().weekday.clamp(1, 5)) : 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(ColorScheme colorScheme) {
    if (activeDay == 'all') return const SizedBox.shrink();
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isActive = activeDay == day['id'];
          return GestureDetector(
            onTap: () => setState(() => activeDay = day['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: isActive ? null : Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(day['label'], style: TextStyle(color: isActive ? Colors.white : colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  if (isActive) Container(margin: const EdgeInsets.only(top: 4), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFullWeek() {
    return days.map((day) {
      final dayClasses = _getSortedClasses(day['id']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(day['full'].toUpperCase(), style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          ),
          if (dayClasses.isEmpty)
            const Text('No classes scheduled', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
          else
            ...dayClasses.map((c) => _classCard(c)),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  List<Widget> _buildSingleDay(int dayId) {
    final list = _getSortedClasses(dayId);
    if (list.isEmpty) return [const Center(child: Padding(padding: EdgeInsets.only(top: 100), child: Text('Nothing scheduled for today! 🎉')))];
    return list.map((c) => _classCard(c)).toList();
  }

  List<ClassSession> _getSortedClasses(int dayId) {
    return widget.classes
        .where((c) => c.dayOfWeek == dayId)
        .where((c) => c.status != 'cancelled' || widget.isRepresentative)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Widget _classCard(ClassSession c) {
    final isCancelled = c.status == 'cancelled';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 60,
              decoration: BoxDecoration(
                color: isCancelled ? Colors.grey.shade100 : colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              child: Center(
                child: Text(
                  EthiopianTimeUtils.formatString(c.time),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? Colors.grey : colorScheme.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: isCancelled ? TextDecoration.lineThrough : null, color: isCancelled ? Colors.grey : null)),
                    const SizedBox(height: 4),
                    Text('${c.room} • ${c.instructor}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            if (widget.isRepresentative)
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  PopupMenuItem(child: const ListTile(leading: Icon(Icons.edit), title: Text('Edit')), onTap: () => Future.delayed(Duration.zero, () => _openEditBottomSheet(c))),
                  PopupMenuItem(child: ListTile(leading: Icon(isCancelled ? Icons.check_circle : Icons.cancel), title: Text(isCancelled ? 'Restore' : 'Cancel')), onTap: () => widget.onCancelClass(c.id)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _openEditBottomSheet(ClassSession c) {
    final roomController = TextEditingController(text: c.room);
    final timeController = TextEditingController(text: c.time);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: roomController, decoration: const InputDecoration(labelText: 'Room', prefixIcon: Icon(Icons.place))),
            const SizedBox(height: 16),
            TextField(controller: timeController, decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.access_time))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onUpdateClass(c.id, {'room': roomController.text, 'time': timeController.text});
                  Navigator.pop(context);
                },
                child: const Text('Update Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}