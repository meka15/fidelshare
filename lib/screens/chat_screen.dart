import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  final Student student;
  final String userId;

  const ChatScreen({super.key, required this.student, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  
  bool _isSending = false;
  String _connectionStatus = 'connecting';
  List<ChatMessage> _messages = [];
  int? _sectionId;
  RealtimeChannel? _channel;

  // SaaS Light Colors
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textGray = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.client.removeChannel(_channel!);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // --- UI COMPONENTS ---

  /// Replaces the buggy NetworkImage and ui-avatars API
  Widget _buildAvatar(String name, {double size = 40}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isMe, bool showName) {
    return Padding(
      padding: EdgeInsets.only(top: showName ? 12 : 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showName) ...[
            _buildAvatar(msg.senderName, size: 32),
            const SizedBox(width: 8),
          ] else if (!isMe && !showName) ...[
            const SizedBox(width: 40), // Offset for consecutive messages
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? _primaryBlue : _bgLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showName && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(msg.senderName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryBlue)),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(color: isMe ? Colors.white : _textDark, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Section Chat', style: GoogleFonts.plusJakartaSans(color: _textDark, fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _connectionStatus == 'online' ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Section ${_sectionId ?? "Loading..."} • Active', style: TextStyle(fontSize: 11, color: _textGray)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.black.withOpacity(0.05)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _sectionId == null 
              ? const Center(child: CircularProgressIndicator()) 
              : _messages.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == widget.userId;
                      final bool showName = index == 0 || _messages[index - 1].senderId != msg.senderId;
                      return _buildBubble(msg, isMe, showName);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // --- INPUT & STATE LOGIC ---

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Type a message...",
                fillColor: _bgLight,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _primaryBlue,
            child: IconButton(
              icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.forum_outlined, size: 48, color: _textGray.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text("No messages yet. Start the chat!", style: TextStyle(color: _textGray)),
      ],
    ));
  }

  // --- DATA LOGIC ---

  Future<void> _initChat() async {
    await _loadSectionId();
    if (_sectionId != null) {
      await _fetchMessages();
      _subscribeRealtime();
    }
  }

  Future<void> _loadSectionId() async {
    final data = await SupabaseService.client.from('profiles').select('section').eq('id', widget.userId).maybeSingle();
    if (data != null && data['section'] != null) {
      setState(() => _sectionId = int.tryParse(data['section'].toString()));
    }
  }

  Future<void> _fetchMessages() async {
    final List<dynamic> data = await SupabaseService.client.from('chat_messages').select().eq('section', _sectionId!).order('timestamp', ascending: true);
    setState(() {
      _messages = data.map((m) => ChatMessage(
        id: m['id'].toString(),
        role: m['role'] ?? 'user',
        senderId: m['sender_id'] ?? '',
        senderName: m['sender_name'] ?? 'Unknown',
        text: m['text'] ?? '',
        timestamp: (m['timestamp'] as num).toInt(),
        section: m['section']?.toString() ?? '',
      )).toList();
    });
    _scrollToBottom();
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.client.channel('chat_$_sectionId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'section', value: _sectionId!),
      callback: (payload) {
        final m = payload.newRecord;
        final msg = ChatMessage(
          id: m['id'].toString(),
          role: m['role'] ?? 'user',
          senderId: m['sender_id'] ?? '',
          senderName: m['sender_name'] ?? 'Unknown',
          text: m['text'] ?? '',
          timestamp: (m['timestamp'] as num).toInt(),
          section: m['section']?.toString() ?? '',
        );
        setState(() { if (!_messages.any((e) => e.id == msg.id)) _messages.add(msg); });
        _scrollToBottom();
      },
    ).subscribe((status, [_]) {
      setState(() => _connectionStatus = status == RealtimeSubscribeStatus.subscribed ? 'online' : 'offline');
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    _controller.clear();
    setState(() => _isSending = true);
    try {
      await SupabaseService.client.from('chat_messages').insert({
        'sender_id': widget.userId,
        'sender_name': widget.student.name,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'section': _sectionId!,
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }
}