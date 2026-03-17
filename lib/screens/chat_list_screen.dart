import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final Student student;
  final String userId;

  const ChatListScreen({
    super.key,
    required this.student,
    required this.userId,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isLoading = true;
  List<ChatGroup> _groups = [];

  final Color _primaryColor = const Color(0xFF4F46E5);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _textDark = const Color(0xFF1E293B);
  final Color _textGray = const Color(0xFF64748B);

  bool _isMissingSectionColumnError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('column') &&
        msg.contains('section') &&
        (msg.contains('does not exist') || msg.contains('undefined column'));
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      // Fetch groups where user is a member or public groups
      // Assuming 'members' is a JSONB array or we check if user is in it
      // Using a simpler approach for now: query groups where user is in members list
      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .or('is_public.eq.true,members.cs.{"${widget.userId}"}');

      final List<dynamic> data = response;
      final mySection = widget.student.section.trim().toUpperCase();

      setState(() {
        _groups = data
            .where((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final rawSection = row['section'];
              final members = row['members'] != null
                  ? List<String>.from(row['members'])
                  : <String>[];
              final isMember = members.contains(widget.userId);
              final isPublic = row['is_public'] == true;

              if (isMember) return true;
              if (!isPublic) return false;

              if (rawSection == null) {
                return true;
              }

              return rawSection.toString().trim().toUpperCase() == mySection;
            })
            .map((json) => ChatGroup.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading groups: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Text(
          'Chats',
          style: GoogleFonts.plusJakartaSans(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: _primaryColor,
              size: 28,
            ),
            onPressed: _showCreateGroupDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  "Section Discussion",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textGray,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildChatTile(
                title: "Section ${widget.student.section}",
                subtitle: "General discussion for your section",
                icon: Icons.groups_rounded,
                color: const Color(0xFF818CF8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        student: widget.student,
                        userId: widget.userId,
                        sectionId: widget.student.section,
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  "Your Groups",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textGray,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_groups.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final group = _groups[index];
                  return _buildChatTile(
                    title: group.name,
                    subtitle: group.description ?? "No description",
                    icon: Icons.chat_bubble_rounded,
                    imageUrl: group.avatarUrl,
                    color: _primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            student: widget.student,
                            userId: widget.userId,
                            group: group,
                          ),
                        ),
                      );
                    },
                  );
                }, childCount: _groups.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required String title,
    required String subtitle,
    IconData? icon,
    String? imageUrl,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(icon, color: Colors.white, size: 28),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 28),
          ),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: _textGray),
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: _textGray.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No private groups yet",
            style: GoogleFonts.plusJakartaSans(
              color: _textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Create one to chat with specific people",
            style: GoogleFonts.inter(color: _textGray),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.add),
            label: const Text("Create Group"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPublic = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textGray.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Create New Group",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Group Name",
                  hintText: "e.g. Study Buddies",
                  filled: true,
                  fillColor: _bgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  hintText: "What's this group about?",
                  filled: true,
                  fillColor: _bgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  "Public Group",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  "Anyone in your section can find and join",
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                value: isPublic,
                activeColor: _primaryColor,
                onChanged: (v) => setModalState(() => isPublic = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _createGroup(
                    nameController.text,
                    descController.text,
                    isPublic,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Create Group",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup(String name, String desc, bool isPublic) async {
    if (name.isEmpty) return;

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final newGroup = {
        'name': name,
        'description': desc,
        'is_public': isPublic,
        'section': widget.student.section.trim().toUpperCase(),
        'created_by': widget.userId,
        'members': [widget.userId],
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await SupabaseService.client.from('chat_groups').insert(newGroup);
      } catch (e) {
        if (!_isMissingSectionColumnError(e)) rethrow;

        final fallbackGroup = {
          'name': name,
          'description': desc,
          'is_public': isPublic,
          'created_by': widget.userId,
          'members': [widget.userId],
          'created_at': DateTime.now().toIso8601String(),
        };
        await SupabaseService.client.from('chat_groups').insert(fallbackGroup);
      }

      await _loadGroups();
    } catch (e) {
      debugPrint("Error creating group: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to create group: $e")));
        setState(() => _isLoading = false);
      }
    }
  }
}
