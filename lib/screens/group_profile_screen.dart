import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class GroupProfileScreen extends StatefulWidget {
  final Student student;
  final String userId;
  final ChatGroup group;

  const GroupProfileScreen({
    super.key,
    required this.student,
    required this.userId,
    required this.group,
  });

  @override
  State<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends State<GroupProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublic = false;
  Set<String> _members = {};
  List<Map<String, dynamic>> _sectionUsers = [];

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;
  final Color _textDark = const Color(0xFF1E293B);
  final Color _textGray = const Color(0xFF64748B);

  bool _isMissingSectionColumnError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('column') &&
        msg.contains('section') &&
        (msg.contains('does not exist') || msg.contains('undefined column'));
  }

  dynamic _coerceSectionValue(String section) {
    final normalized = section.trim().toUpperCase();
    final parsed = int.tryParse(normalized);
    return parsed ?? normalized;
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.group.name;
    _descriptionController.text = widget.group.description ?? '';
    _avatarUrlController.text = widget.group.avatarUrl ?? '';
    _isPublic = widget.group.isPublic;
    _members = widget.group.members.toSet();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final latestGroup = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('id', widget.group.id)
          .maybeSingle();

      if (latestGroup != null) {
        _nameController.text =
            latestGroup['name']?.toString() ?? _nameController.text;
        _descriptionController.text =
            latestGroup['description']?.toString() ?? '';
        _avatarUrlController.text = latestGroup['avatar_url']?.toString() ?? '';
        _isPublic = latestGroup['is_public'] == true;
        _members = latestGroup['members'] != null
            ? Set<String>.from(List<String>.from(latestGroup['members']))
            : _members;
      }

      final normalizedSection = widget.student.section.trim().toUpperCase();
      final sectionValue = _coerceSectionValue(normalizedSection);

      dynamic usersRaw = await SupabaseService.client
          .from('profiles')
          .select('id,name,student_id,avater_url,section')
          .eq('section', sectionValue);

      if (usersRaw is List && usersRaw.isEmpty) {
        if (sectionValue is int) {
          usersRaw = await SupabaseService.client
              .from('profiles')
              .select('id,name,student_id,avater_url,section')
              .eq('section', normalizedSection);
        } else {
          final parsed = int.tryParse(normalizedSection);
          if (parsed != null) {
            usersRaw = await SupabaseService.client
                .from('profiles')
                .select('id,name,student_id,avater_url,section')
                .eq('section', parsed);
          }
        }
      }

      final users = List<Map<String, dynamic>>.from(usersRaw as List)
        ..sort((a, b) {
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

      setState(() {
        _sectionUsers = users;
        _members.add(widget.userId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group info: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _allSectionUsersSelected {
    if (_sectionUsers.isEmpty) return false;
    final allIds = _sectionUsers.map((u) => u['id'].toString()).toSet();
    return allIds.every(_members.contains);
  }

  void _toggleSelectAll(bool selected) {
    final allIds = _sectionUsers.map((u) => u['id'].toString()).toSet();
    setState(() {
      if (selected) {
        _members.addAll(allIds);
      } else {
        _members.removeAll(allIds);
        _members.add(widget.userId);
      }
    });
  }

  Future<void> _save() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group name is required')));
      return;
    }

    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatePayload = {
        'name': groupName,
        'description': _descriptionController.text.trim(),
        'avatar_url': _avatarUrlController.text.trim().isEmpty
            ? null
            : _avatarUrlController.text.trim(),
        'is_public': _isPublic,
        'section': widget.student.section.trim().toUpperCase(),
        'members': _members.toList(),
      };

      dynamic updated;
      try {
        updated = await SupabaseService.client
            .from('chat_groups')
            .update(updatePayload)
            .eq('id', widget.group.id)
            .select()
            .single();
      } catch (e) {
        if (!_isMissingSectionColumnError(e)) rethrow;

        final fallbackPayload = {
          'name': groupName,
          'description': _descriptionController.text.trim(),
          'avatar_url': _avatarUrlController.text.trim().isEmpty
              ? null
              : _avatarUrlController.text.trim(),
          'is_public': _isPublic,
          'members': _members.toList(),
        };

        updated = await SupabaseService.client
            .from('chat_groups')
            .update(fallbackPayload)
            .eq('id', widget.group.id)
            .select()
            .single();
      }

      if (!mounted) return;

      Navigator.pop(context, ChatGroup.fromJson(updated));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save group settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatarPreview() {
    final groupName = _nameController.text.trim();
    final initial = groupName.isEmpty ? 'G' : groupName[0].toUpperCase();
    final avatarUrl = _avatarUrlController.text.trim();

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(26),
      ),
      child: avatarUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    final isSelf = userId == widget.userId;
    final name = user['name']?.toString() ?? 'Unknown';
    final studentId = user['student_id']?.toString() ?? '';
    final avatarUrl = user['avater_url']?.toString();
    final selected = _members.contains(userId);

    return CheckboxListTile(
      value: selected,
      onChanged: isSelf
          ? null
          : (checked) {
              setState(() {
                if (checked == true) {
                  _members.add(userId);
                } else {
                  _members.remove(userId);
                }
              });
            },
      controlAffinity: ListTileControlAffinity.leading,
      secondary: CircleAvatar(
        backgroundColor: _primaryColor.withOpacity(0.15),
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
            ? NetworkImage(avatarUrl)
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(
        isSelf ? '$name (You)' : name,
        style: GoogleFonts.inter(color: _textDark, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        studentId,
        style: GoogleFonts.inter(color: _textGray, fontSize: 12),
      ),
      activeColor: _primaryColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        title: Text(
          'Group Profile',
          style: GoogleFonts.plusJakartaSans(
            color: _textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              children: [
                Center(child: _buildAvatarPreview()),
                const SizedBox(height: 14),
                TextField(
                  controller: _avatarUrlController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Avatar URL',
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    filled: true,
                    fillColor: _surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isPublic,
                  activeColor: _primaryColor,
                  title: Text(
                    'Public Group',
                    style: GoogleFonts.inter(
                      color: _textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Anyone in section ${widget.student.section} can find this group.',
                    style: GoogleFonts.inter(color: _textGray, fontSize: 12),
                  ),
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Section ${widget.student.section} members',
                          style: GoogleFonts.plusJakartaSans(
                            color: _textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _toggleSelectAll(!_allSectionUsersSelected),
                        child: Text(
                          _allSectionUsersSelected
                              ? 'Unselect all'
                              : 'Select all',
                          style: GoogleFonts.inter(
                            color: _primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ..._sectionUsers.map(_buildUserTile),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
