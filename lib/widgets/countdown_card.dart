import 'package:flutter/material.dart';
import '../models/models.dart';
import 'dart:async';

class CountdownCard extends StatefulWidget {
  final List<ClassSession> classes;

  const CountdownCard({super.key, required this.classes});

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  ClassSession? _nextClass;
  int _h = 0, _m = 0, _s = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateNextClass();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTimeLeft());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateNextClass() {
    final now = DateTime.now();
    final upcoming = widget.classes.where((c) => c.startTime.isAfter(now)).toList();
    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    setState(() {
      _nextClass = upcoming.isNotEmpty ? upcoming.first : null;
    });
    _updateTimeLeft();
  }

  void _updateTimeLeft() {
    if (_nextClass == null) return;

    final now = DateTime.now();
    final diff = _nextClass!.startTime.difference(now);

    if (diff.isNegative) {
      _updateNextClass();
      return;
    }

    setState(() {
      _h = diff.inHours;
      _m = diff.inMinutes % 60;
      _s = diff.inSeconds % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_nextClass == null) return const SizedBox.shrink();

    final Color primaryBlue = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NEXT CLASS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _nextClass!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place, size: 14, color: Colors.white.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(
                'Room ${_nextClass!.room} • ${_nextClass!.instructor}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildTimeBox(_h, 'HOURS'),
              const SizedBox(width: 12),
              _buildTimeBox(_m, 'MINS'),
              const SizedBox(width: 12),
              _buildTimeBox(_s, 'SECS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(int value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}