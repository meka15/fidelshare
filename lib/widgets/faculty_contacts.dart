import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:url_launcher/url_launcher.dart';

class FacultyContactsView extends StatelessWidget {
  final List<FacultyContact> faculty;
  final bool visible;
  final bool isRepresentative;
  final VoidCallback? onToggleVisibility;

  const FacultyContactsView({
    super.key,
    required this.faculty,
    this.visible = true,
    this.isRepresentative = false,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    // Hide entirely for students if set to invisible
    if (!visible && !isRepresentative) return const SizedBox.shrink();
    if (faculty.isEmpty && !isRepresentative) return const SizedBox.shrink();

    return Opacity(
      opacity: visible ? 1.0 : 0.6, // Dim the section if hidden (Rep view only)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (faculty.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("No faculty contacts listed.", style: TextStyle(fontStyle: FontStyle.italic)),
            )
          else
            _buildHorizontalList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "Faculty Contacts",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (!visible && isRepresentative)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.visibility_off, size: 16, color: Colors.grey),
                ),
            ],
          ),
          if (isRepresentative && onToggleVisibility != null)
            TextButton.icon(
              onPressed: onToggleVisibility,
              icon: Icon(visible ? Icons.visibility : Icons.visibility_off, size: 18),
              label: Text(visible ? "Visible" : "Hidden"),
              style: TextButton.styleFrom(
                foregroundColor: visible ? Theme.of(context).colorScheme.primary : Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalList() {
    return SizedBox(
      height: 120, // Explicit height for the circle + 2 lines of text
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: faculty.length,
        itemBuilder: (context, index) {
          final f = faculty[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => _showFacultyDetails(context, f),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: f.avatar.isNotEmpty ? NetworkImage(f.avatar) : null,
                      child: f.avatar.isEmpty
                          ? Text(f.name[0], style: const TextStyle(fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f.name.split(' ').first,
                      style: Theme.of(context).textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      f.role,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFacultyDetails(BuildContext context, FacultyContact contact) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: contact.avatar.isNotEmpty ? NetworkImage(contact.avatar) : null,
              child: contact.avatar.isEmpty ? Text(contact.name[0], style: const TextStyle(fontSize: 32)) : null,
            ),
            const SizedBox(height: 16),
            Text(contact.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(contact.role, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.secondary)),
            const SizedBox(height: 12),
            _buildAverageRating(context, contact),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildContactAction(
                  context, 
                  Icons.email_rounded, 
                  "Email", 
                  contact.email != null ? () => launchUrl(Uri.parse('mailto:${contact.email}')) : null,
                ),
                _buildContactAction(
                  context, 
                  Icons.phone_rounded, 
                  "Call", 
                  contact.phoneNumber != null ? () => launchUrl(Uri.parse('tel:${contact.phoneNumber}')) : null,
                ),
                _buildContactAction(
                  context, 
                  Icons.star_outline_rounded, 
                  "Rate", 
                  () => _showRatingPrompt(context, contact),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageRating(BuildContext context, FacultyContact contact) {
    // Hardcoded for now: Use ID to generate some consistent dummy ratings
    final rating = contact.averageRating > 0 ? contact.averageRating : (contact.id.hashCode % 15 + 35) / 10;
    final reviews = contact.reviewCount > 0 ? contact.reviewCount : (contact.id.hashCode % 50 + 10);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return Icon(
              starValue <= rating.floor() ? Icons.star_rounded : 
              (index < rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
              color: Colors.amber,
              size: 20,
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(width: 4),
        Text(
          "($reviews reviews)",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _showRatingPrompt(BuildContext context, FacultyContact contact) {
    int selectedStars = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Rate Faculty"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("How would you rate ${contact.name.split(' ').first}'s performance?"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => selectedStars = starIndex),
                    icon: Icon(
                      starIndex <= selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              if (selectedStars > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    selectedStars == 5 ? "Excellent!" : 
                    selectedStars >= 4 ? "Very Good" : 
                    selectedStars >= 3 ? "Good" : "Fair",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: selectedStars == 0 ? null : () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Thanks for rating ${contact.name}! (Hardcoded Preview)"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactAction(BuildContext context, IconData icon, String label, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon),
          iconSize: 28,
          style: IconButton.styleFrom(
            backgroundColor: isEnabled ? null : Theme.of(context).disabledColor.withValues(alpha: 0.1),
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}