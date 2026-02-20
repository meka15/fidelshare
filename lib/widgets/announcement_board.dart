import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class AnnouncementBoard extends StatefulWidget { // Switched to StatefulWidget for PageController management
  final List<Announcement> announcements;
  final VoidCallback onViewAll;
  final void Function(Announcement ann) onSelect;
  final bool isRepresentative;

  const AnnouncementBoard({
    super.key,
    required this.announcements,
    required this.onViewAll,
    required this.onSelect,
    required this.isRepresentative,
  });

  @override
  State<AnnouncementBoard> createState() => _AnnouncementBoardState();
}

class _AnnouncementBoardState extends State<AnnouncementBoard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcements.isEmpty) return const SizedBox.shrink();

    final topAnnouncements = widget.announcements.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: topAnnouncements.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _buildAnnouncementCard(context, topAnnouncements[index]),
          ),
        ),
        const SizedBox(height: 8),
        _buildPageIndicator(topAnnouncements.length),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Announcements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          TextButton.icon(
            onPressed: widget.onViewAll,
            label: const Text('View All'),
            icon: const Icon(Icons.arrow_forward, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Announcement ann) {
    final date = DateTime.fromMillisecondsSinceEpoch(ann.timestamp);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => widget.onSelect(ann),
      child: Card(
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      ann.authorName[0].toUpperCase(),
                      style: TextStyle(fontSize: 12, color: colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ann.authorName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d').format(date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const Divider(height: 20), // Added a subtle divider
              Text(
                ann.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  ann.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: _currentPage == index ? 18 : 6,
          decoration: BoxDecoration(
            color: _currentPage == index 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}