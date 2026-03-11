import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/data_service.dart';

class QuickActions extends StatefulWidget {
  final Student student;
  final Future<void> Function(Announcement ann) onPostAnnouncement;
  final Future<void> Function(ClassSession classData) onAddClass;
  final Future<void> Function(FacultyContact faculty) onAddFaculty;

  const QuickActions({
    super.key,
    required this.student,
    required this.onPostAnnouncement,
    required this.onAddClass,
    required this.onAddFaculty,
  });

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions> {
  bool _isDrafting = false;

  // Modern Input Decoration Helper
  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
      );

  void _showStyledModal(BuildContext context, String title, List<Widget> children) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  void _openAnnouncementModal() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    _showStyledModal(context, 'New Announcement', [
      TextField(controller: titleController, decoration: _inputStyle('Topic / Title', Icons.title)),
      const SizedBox(height: 16),
      TextField(
        controller: contentController,
        maxLines: 4,
        decoration: _inputStyle('Write your message...', Icons.edit_note),
      ),
      const SizedBox(height: 12),
      StatefulBuilder(builder: (context, setModalState) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isDrafting ? null : () async {
              setModalState(() => _isDrafting = true);
              final draft = await GeminiService.draftMessage('FidelShare', widget.student.name, titleController.text);
              contentController.text = draft;
              setModalState(() => _isDrafting = false);
            },
            icon: _isDrafting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(_isDrafting ? 'Gemini is thinking...' : 'AI Draft with Gemini'),
          ),
        );
      }),
      const SizedBox(height: 24),
      _buildSubmitButton('Post to Class Board', () {
        if (titleController.text.isEmpty || contentController.text.isEmpty) return;
        final ann = Announcement(
          id: DataService.generateId(),
          title: titleController.text,
          content: contentController.text,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          authorName: widget.student.name,
          authorId: widget.student.isRepresentative ? 'REP-${widget.student.studentId}' : widget.student.studentId,
          section: widget.student.section,
        );
        widget.onPostAnnouncement(ann);
        Navigator.pop(context);
      }),
    ]);
  }

  void _openClassModal() {
    final nameController = TextEditingController();
    final instructorController = TextEditingController();
    final roomController = TextEditingController();
    int dayOfWeek = DateTime.now().weekday;
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    bool isPermanent = true;
    DateTime selectedDate = DateTime.now();

    _showStyledModal(context, 'New Class Session', [
      TextField(controller: nameController, decoration: _inputStyle('Class Name', Icons.book_outlined)),
      const SizedBox(height: 16),
      TextField(controller: instructorController, decoration: _inputStyle('Instructor', Icons.person_outline)),
      const SizedBox(height: 16),
      TextField(controller: roomController, decoration: _inputStyle('Room / Hall', Icons.place_outlined)),
      const SizedBox(height: 16),
      StatefulBuilder(builder: (context, setModalState) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPermanent ? 'Weekly Permanent' : 'One-time Temporary',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: isPermanent,
                    onChanged: (val) => setModalState(() => isPermanent = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: selectedTime);
                      if (picked != null) setModalState(() => selectedTime = picked);
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(selectedTime.format(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isPermanent
                      ? DropdownButtonFormField<int>(
                          value: dayOfWeek > 5 ? 1 : dayOfWeek,
                          decoration: _inputStyle('Day', Icons.calendar_month),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Mon')),
                            DropdownMenuItem(value: 2, child: Text('Tue')),
                            DropdownMenuItem(value: 3, child: Text('Wed')),
                            DropdownMenuItem(value: 4, child: Text('Thu')),
                            DropdownMenuItem(value: 5, child: Text('Fri')),
                          ],
                          onChanged: (v) => dayOfWeek = v ?? 1,
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedDate = picked;
                                dayOfWeek = picked.weekday;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text('${selectedDate.month}/${selectedDate.day}'),
                        ),
                ),
              ],
            ),
          ],
        );
      }),
      const SizedBox(height: 24),
      _buildSubmitButton('Add to Schedule', () {
        if (nameController.text.isEmpty || instructorController.text.isEmpty) return;
        
        final session = ClassSession(
          id: DataService.generateId(),
          name: nameController.text,
          instructor: instructorController.text,
          room: roomController.text,
          time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
          status: 'upcoming',
          dayOfWeek: dayOfWeek,
          startTime: isPermanent 
              ? DateTime.now() // placeholder, DataService fix it
              : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute),
          section: widget.student.section,
          isPermanent: isPermanent,
          date: isPermanent ? null : selectedDate,
        );
        widget.onAddClass(session);
        Navigator.pop(context);
      }),
    ]);
  }

  void _openFacultyModal() {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    _showStyledModal(context, 'Register Faculty', [
      TextField(controller: nameController, decoration: _inputStyle('Full Name', Icons.badge_outlined)),
      const SizedBox(height: 16),
      TextField(controller: roleController, decoration: _inputStyle('Role (e.g. Professor)', Icons.work_outline)),
      const SizedBox(height: 16),
      TextField(controller: emailController, decoration: _inputStyle('Email Address', Icons.email_outlined), keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      TextField(controller: phoneController, decoration: _inputStyle('Phone Number', Icons.phone_outlined), keyboardType: TextInputType.phone),
      const SizedBox(height: 24),
      _buildSubmitButton('Save Contact', () {
        if (nameController.text.isEmpty || roleController.text.isEmpty) return;
        
        final faculty = FacultyContact(
          id: DataService.generateId(),
          name: nameController.text,
          role: roleController.text,
          avatar: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nameController.text)}&background=137fec&color=fff',
          email: emailController.text.isNotEmpty ? emailController.text : null,
          phoneNumber: phoneController.text.isNotEmpty ? phoneController.text : null,
          section: widget.student.section,
        );
        widget.onAddFaculty(faculty);
        Navigator.pop(context);
      }),
    ]);
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.student.isRepresentative) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('REPRESENTATIVE TOOLS', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ActionCard(title: 'Broadcast', subtitle: 'Post Update', icon: Icons.campaign, color: Colors.orange, onTap: _openAnnouncementModal),
              _ActionCard(title: 'Schedule', subtitle: 'Add Class', icon: Icons.calendar_today, color: Colors.blue, onTap: _openClassModal),
              _ActionCard(title: 'Faculty', subtitle: 'Add Contact', icon: Icons.school, color: Colors.purple, onTap: _openFacultyModal),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}