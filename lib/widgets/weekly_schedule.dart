import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

class WeeklySchedule extends StatefulWidget {
  final List<ClassSession> classes;
  final bool isRepresentative;
  final Future<void> Function(String id) onCancelClass;
  final Future<void> Function(String id, Map<String, dynamic> updates) onUpdateClass;
  final Future<void> Function(String id) onDeleteClass;

  const WeeklySchedule({
    super.key,
    required this.classes,
    required this.isRepresentative,
    required this.onCancelClass,
    required this.onUpdateClass,
    required this.onDeleteClass,
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
    final now = DateTime.now();
    // Simple logic: if temporary, only show if it's in the current week or matches the day.
    // For a simple app, we'll show temporary classes if they are in the future and match the dayId,
    // OR if they are specifically for TODAY.
    return widget.classes.where((c) {
      if (c.dayOfWeek != dayId) return false;
      if (c.status == 'cancelled' && !widget.isRepresentative) return false;
      
      if (!c.isPermanent && c.date != null) {
        // If it's a temporary class, only show it if the date is today or in the future
        // and within a reasonable range (e.g., this week).
        // For simplicity, let's show it if it matches the weekday and is not in the past.
        final classDate = DateTime(c.date!.year, c.date!.month, c.date!.day);
        final today = DateTime(now.year, now.month, now.day);
        
        // If class date is before today, it's old (unless it's today)
        if (classDate.isBefore(today)) return false;
        
        // Only show if it matches the "active" week (we assume current week for now)
        // A more complex app would have week navigation.
        // For now, let's show it if it's within the next 7 days.
        final diff = c.date!.difference(now).inDays;
        if (diff > 7) return false;
      }
      
      return true;
    }).toList()
      ..sort((a, b) {
        // Ethiopian Day starts at 06:00 Standard
        final aParts = a.time.split(':');
        final bParts = b.time.split(':');
        
        // Normalize time: subtract 6 hours so 06:00 becomes 00:00 (the start of the day)
        int aHour = (int.parse(aParts[0]) - 6);
        if (aHour < 0) aHour += 24;
        
        int bHour = (int.parse(bParts[0]) - 6);
        if (bHour < 0) bHour += 24;
        
        if (aHour != bHour) return aHour.compareTo(bHour);
        return aParts[1].compareTo(bParts[1]);
      });
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.name, 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 15, 
                              decoration: isCancelled ? TextDecoration.lineThrough : null, 
                              color: isCancelled ? Colors.grey : null
                            )
                          ),
                        ),
                        if (!c.isPermanent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Text('TEMP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ),
                      ],
                    ),
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
                  PopupMenuItem(
                    child: const ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete Permanent', style: TextStyle(color: Colors.red))), 
                    onTap: () => _confirmDelete(c)
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ClassSession c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to permanently delete "${c.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              widget.onDeleteClass(c.id);
              Navigator.pop(context);
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _openEditBottomSheet(ClassSession c) {
    final roomController = TextEditingController(text: c.room);
    
    // Parse the existing time into local format pieces
    final standardParts = c.time.split(':');
    final sHour = int.parse(standardParts[0]);
    final sMinute = int.parse(standardParts[1]);
    
    int etHour = (sHour - 6) % 12;
    if (etHour <= 0) etHour += 12;
    bool isNight = sHour < 6 || sHour >= 18;

    final hourController = TextEditingController(text: etHour.toString());
    final minuteController = TextEditingController(text: sMinute.toString().padLeft(2, '0'));
    bool currentIsNight = isNight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Session', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: roomController,
                decoration: InputDecoration(
                  labelText: 'Room',
                  prefixIcon: const Icon(Icons.place_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hourController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Hour (1-12)',
                        prefixIcon: const Icon(Icons.access_time_filled_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: minuteController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Ethiopian Day/Night Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentIsNight ? '🌙 Night Cycle' : '☀️ Day Cycle',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: currentIsNight,
                      onChanged: (val) => setModalState(() => currentIsNight = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    final h = int.tryParse(hourController.text) ?? 12;
                    final m = int.tryParse(minuteController.text) ?? 0;
                    
                    final standardTime = EthiopianTimeUtils.localToStandard(h, m, currentIsNight);
                    
                    widget.onUpdateClass(c.id, {
                      'room': roomController.text, 
                      'time': standardTime,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}