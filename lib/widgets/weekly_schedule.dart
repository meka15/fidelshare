import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';

class WeeklySchedule extends StatefulWidget {
  final List<ClassSession> classes;
  final bool isRepresentative;
  final Future<void> Function(String id) onCancelClass;
  final Future<void> Function(String id, Map<String, dynamic> updates)
  onUpdateClass;
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
  late final PageController _dayPageController;

  List<Map<String, dynamic>> get _visibleDays {
    final today = DateTime.now().weekday;
    if (today == 1 || today > 5) return days;
    return days.where((d) => (d['id'] as int) >= today).toList();
  }

  int get _defaultDay {
    final today = DateTime.now().weekday;
    return today >= 1 && today <= 5 ? today : 1;
  }

  void _ensureActiveDayIsVisible() {
    if (activeDay == 'all') return;
    final visibleIds = _visibleDays.map((d) => d['id'] as int).toSet();
    if (!visibleIds.contains(activeDay)) {
      activeDay = _visibleDays.first['id'];
    }
  }

  @override
  void initState() {
    super.initState();
    activeDay = _defaultDay;
    _dayPageController = PageController(initialPage: _indexForDayId(activeDay));
  }

  @override
  void dispose() {
    _dayPageController.dispose();
    super.dispose();
  }

  int _indexForDayId(dynamic dayId) {
    final index = _visibleDays.indexWhere((d) => d['id'] == dayId);
    return index >= 0 ? index : 0;
  }

  void _jumpToActiveDayIfNeeded() {
    if (activeDay == 'all' || !_dayPageController.hasClients) return;
    final target = _indexForDayId(activeDay);
    final current = (_dayPageController.page ?? target.toDouble()).round();
    if (current != target) {
      _dayPageController.jumpToPage(target);
    }
  }

  DateTime _nextOccurrenceForDayAndTime(int dayId, String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final now = DateTime.now();
    final candidateToday = DateTime(now.year, now.month, now.day, hour, minute);

    int targetWeekday = dayId;
    if (targetWeekday < 1 || targetWeekday > 7) {
      targetWeekday = 1;
    }

    int daysUntil = (targetWeekday - now.weekday + 7) % 7;
    if (daysUntil == 0 && candidateToday.isBefore(now)) {
      daysUntil = 7;
    }

    return candidateToday.add(Duration(days: daysUntil));
  }

  DateTime? _classDateTime(ClassSession c) {
    if (!c.isPermanent && c.date != null) {
      final parts = c.time.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return DateTime(c.date!.year, c.date!.month, c.date!.day, hour, minute);
    }
    return _nextOccurrenceForDayAndTime(c.dayOfWeek, c.time);
  }

  ClassSession? _nextUpcomingClass() {
    final now = DateTime.now();
    final candidates = widget.classes.where((c) {
      if (c.status == 'cancelled') return false;
      final when = _classDateTime(c);
      return when != null && !when.isBefore(now);
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aTime = _classDateTime(a)!;
      final bTime = _classDateTime(b)!;
      return aTime.compareTo(bTime);
    });

    return candidates.first;
  }

  String _dayNameFromId(int id) {
    final day = days.firstWhere(
      (d) => d['id'] == id,
      orElse: () => const {'full': 'Day'},
    );
    return day['full'].toString();
  }

  void _jumpToToday(List<Map<String, dynamic>> visibleDays) {
    final targetId = visibleDays.first['id'];
    setState(() => activeDay = targetId);
    _dayPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    _ensureActiveDayIsVisible();
    final visibleDays = _visibleDays;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _jumpToActiveDayIfNeeded();
    });

    return Column(
      children: [
        _buildHeader(context),
        _buildNextClassCard(context, colorScheme, visibleDays),
        _buildDaySelector(colorScheme, visibleDays),
        if (activeDay != 'all') _buildPagerDots(colorScheme, visibleDays),
        Expanded(
          child: activeDay == 'all'
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildFullWeek(),
                )
              : _buildDailyPager(visibleDays),
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
              Text(
                'Weekly Schedule',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Theory & Lab sessions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          ActionChip(
            avatar: Icon(
              activeDay == 'all'
                  ? Icons.calendar_view_day_rounded
                  : Icons.calendar_view_week_rounded,
              size: 16,
            ),
            label: Text(activeDay == 'all' ? 'Daily View' : 'Full Week'),
            onPressed: () => setState(
              () => activeDay = activeDay == 'all'
                  ? _visibleDays.first['id']
                  : 'all',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextClassCard(
    BuildContext context,
    ColorScheme colorScheme,
    List<Map<String, dynamic>> visibleDays,
  ) {
    final nextClass = _nextUpcomingClass();
    if (nextClass == null) return const SizedBox(height: 8);

    final nextTime = _classDateTime(nextClass);
    final dayName = _dayNameFromId(nextClass.dayOfWeek);
    final subtitle = nextTime == null
        ? '$dayName • ${EthiopianTimeUtils.formatString(nextClass.time)}'
        : '$dayName • ${EthiopianTimeUtils.formatString(nextClass.time)} • ${nextTime.month}/${nextTime.day}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next: ${nextClass.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (activeDay != 'all')
            TextButton(
              onPressed: () => _jumpToToday(visibleDays),
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(
    ColorScheme colorScheme,
    List<Map<String, dynamic>> visibleDays,
  ) {
    if (activeDay == 'all') return const SizedBox.shrink();
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        primary: false,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: visibleDays.length,
        itemBuilder: (context, index) {
          final day = visibleDays[index];
          final isActive = activeDay == day['id'];
          return GestureDetector(
            onTap: () {
              setState(() => activeDay = day['id']);
              _dayPageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 88,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? colorScheme.primary.withOpacity(0.1)
                      : colorScheme.outlineVariant,
                ),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day['label'],
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day['full'].toString().substring(0, 1),
                    style: TextStyle(
                      color: isActive
                          ? Colors.white.withOpacity(0.9)
                          : colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                  if (isActive)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyPager(List<Map<String, dynamic>> visibleDays) {
    return PageView.builder(
      controller: _dayPageController,
      itemCount: visibleDays.length,
      scrollDirection: Axis.horizontal,
      onPageChanged: (index) {
        final dayId = visibleDays[index]['id'];
        if (activeDay != dayId) {
          setState(() => activeDay = dayId);
        }
      },
      itemBuilder: (context, index) {
        final dayId = visibleDays[index]['id'] as int;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: _buildSingleDay(dayId),
        );
      },
    );
  }

  Widget _buildPagerDots(
    ColorScheme colorScheme,
    List<Map<String, dynamic>> visibleDays,
  ) {
    final activeIndex = _indexForDayId(activeDay);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(visibleDays.length, (index) {
          final selected = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }),
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
            child: Text(
              day['full'].toUpperCase(),
              style: const TextStyle(
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          if (dayClasses.isEmpty)
            const Text(
              'No classes scheduled',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            )
          else
            ...dayClasses.map((c) => _classCard(c)),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  List<Widget> _buildSingleDay(int dayId) {
    final list = _getSortedClasses(dayId);
    if (list.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 100),
            child: Text('No class for this day 🎉'),
          ),
        ),
      ];
    }
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
    }).toList()..sort((a, b) {
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
                color: isCancelled
                    ? Colors.grey.shade100
                    : colorScheme.primaryContainer.withOpacity(0.2),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
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
                          child: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCancelled ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (!c.isPermanent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'TEMP',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c.room} • ${c.instructor}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isRepresentative)
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                    onTap: () => Future.delayed(
                      Duration.zero,
                      () => _openEditBottomSheet(c),
                    ),
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(
                        isCancelled ? Icons.check_circle : Icons.cancel,
                      ),
                      title: Text(isCancelled ? 'Restore' : 'Cancel'),
                    ),
                    onTap: () => widget.onCancelClass(c.id),
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text(
                        'Delete Permanent',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    onTap: () => _confirmDelete(c),
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
        content: Text(
          'Are you sure you want to permanently delete "${c.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteClass(c.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
    final minuteController = TextEditingController(
      text: sMinute.toString().padLeft(2, '0'),
    );
    bool currentIsNight = isNight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Session',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: roomController,
                decoration: InputDecoration(
                  labelText: 'Room',
                  prefixIcon: const Icon(Icons.place_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
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
                        prefixIcon: const Icon(
                          Icons.access_time_filled_rounded,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Ethiopian Day/Night Toggle
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
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
                      onChanged: (val) =>
                          setModalState(() => currentIsNight = val),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    final h = int.tryParse(hourController.text) ?? 12;
                    final m = int.tryParse(minuteController.text) ?? 0;

                    final standardTime = EthiopianTimeUtils.localToStandard(
                      h,
                      m,
                      currentIsNight,
                    );

                    widget.onUpdateClass(c.id, {
                      'room': roomController.text,
                      'time': standardTime,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
