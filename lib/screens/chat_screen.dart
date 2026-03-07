import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/local_database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
  final LocalDatabaseService _localDb = LocalDatabaseService();
  
  bool _isSending = false;
  bool _isLoadingOldMessages = false;
  bool _hasMoreOlderMessages = true;
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
    _scroll.addListener(_onScroll);
    _initChat();
    _checkConnectivity();
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.client.removeChannel(_channel!);
    _controller.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels <= _scroll.position.minScrollExtent + 50 &&
        !_isLoadingOldMessages &&
        _hasMoreOlderMessages) {
      _loadOlderMessages();
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      setState(() => _connectionStatus = 'offline');
    } else {
      setState(() => _connectionStatus = 'online');
    }
    
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        setState(() => _connectionStatus = 'offline');
      } else {
        setState(() => _connectionStatus = 'online');
        if (_sectionId != null) {
          _syncNewMessages();
        }
      }
    });
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

  Widget _buildDateSeparator(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
    
    String label;
    if (isToday) {
      label = "Today";
    } else if (isYesterday) {
      label = "Yesterday";
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _bgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: _textGray, fontWeight: FontWeight.w500),
        ),
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
                Text('Section ${_sectionId ?? "Loading..."} • ${_connectionStatus == 'online' ? 'Active' : 'Offline'}', style: TextStyle(fontSize: 11, color: _textGray)),
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
                    itemCount: _messages.length + (_isLoadingOldMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && _isLoadingOldMessages) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        ));
                      }
                      
                      final msgIndex = _isLoadingOldMessages ? index - 1 : index;
                      final msg = _messages[msgIndex];
                      final isMe = msg.senderId == widget.userId;
                      
                      bool showDate = true;
                      if (msgIndex > 0) {
                        final prevMsg = _messages[msgIndex - 1];
                        final date1 = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
                        final date2 = DateTime.fromMillisecondsSinceEpoch(prevMsg.timestamp);
                        if (date1.year == date2.year && date1.month == date2.month && date1.day == date2.day) {
                          showDate = false;
                        }
                      }
                      
                      final bool showName = msgIndex == 0 || showDate || _messages[msgIndex - 1].senderId != msg.senderId;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) _buildDateSeparator(msg.timestamp),
                          _buildBubble(msg, isMe, showName),
                        ],
                      );
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
      await _loadLocalMessages();
      _syncNewMessages();
      _subscribeRealtime();
    }
  }

  Future<void> _loadSectionId() async {
    final data = await SupabaseService.client.from('profiles').select('section').eq('id', widget.userId).maybeSingle();
    if (data != null && data['section'] != null) {
      setState(() => _sectionId = int.tryParse(data['section'].toString()));
    }
  }

  Future<void> _loadLocalMessages() async {
    final localMsgs = await _localDb.getMessages(_sectionId.toString(), limit: 20);
    setState(() {
      _messages = localMsgs.reversed.toList();
    });
    // Scroll to bottom only initially
    if (_messages.isNotEmpty) {
      _scrollToBottom();
    }
  }

  Future<void> _syncNewMessages() async {
    if (_connectionStatus == 'offline' || _sectionId == null) return;

    int? latestTimestamp = await _localDb.getLatestTimestamp(_sectionId.toString());
    
    SupabaseQueryBuilder query = SupabaseService.client.from('chat_messages');
    PostgrestFilterBuilder filter = query.select().eq('section', _sectionId!);
    
    List<dynamic> data;
    if (latestTimestamp != null) {
      data = await filter.gt('timestamp', latestTimestamp).order('timestamp', ascending: true);
    } else {
      // If we don't have any local messages, we should probably fetch the latest 20
      data = await filter.order('timestamp', ascending: false).limit(20);
      data = data.reversed.toList();
    }

    if (data.isNotEmpty) {
      final newMessages = data.map((m) => ChatMessage(
        id: m['id'].toString(),
        role: m['role'] ?? 'user',
        senderId: m['sender_id'] ?? '',
        senderName: m['sender_name'] ?? 'Unknown',
        text: m['text'] ?? '',
        timestamp: (m['timestamp'] as num).toInt(),
        section: m['section']?.toString() ?? '',
      )).toList();
      
      await _localDb.insertMessages(newMessages);
      
      setState(() {
        for (var msg in newMessages) {
          if (!_messages.any((e) => e.id == msg.id)) {
            _messages.add(msg);
          }
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOldMessages || _messages.isEmpty || _sectionId == null) return;
    
    setState(() => _isLoadingOldMessages = true);
    
    try {
      final oldestTimestamp = _messages.first.timestamp;
      
      // Try local DB first
      List<ChatMessage> olderMessages = await _localDb.getMessages(
        _sectionId.toString(), 
        beforeTimestamp: oldestTimestamp, 
        limit: 20
      );

      // If local DB doesn't have 20 messages, we try fetching from remote
      if (olderMessages.length < 20 && _connectionStatus == 'online') {
        final data = await SupabaseService.client.from('chat_messages')
            .select()
            .eq('section', _sectionId!)
            .lt('timestamp', oldestTimestamp)
            .order('timestamp', ascending: false)
            .limit(20);
            
        final remoteMessages = data.map((m) => ChatMessage(
            id: m['id'].toString(),
            role: m['role'] ?? 'user',
            senderId: m['sender_id'] ?? '',
            senderName: m['sender_name'] ?? 'Unknown',
            text: m['text'] ?? '',
            timestamp: (m['timestamp'] as num).toInt(),
            section: m['section']?.toString() ?? '',
          )).toList();
          
        if (remoteMessages.isNotEmpty) {
          await _localDb.insertMessages(remoteMessages);
          olderMessages = remoteMessages; // Use remote, as we should have all or overlapping
        }
      }

      if (olderMessages.isEmpty) {
        setState(() => _hasMoreOlderMessages = false);
      } else {
        // Remember current scroll position to maintain it
        final double currentPosition = _scroll.position.pixels;
        final double maxScroll = _scroll.position.maxScrollExtent;
        
        setState(() {
          // Merge old messages, ensuring no duplicates
          for (var msg in olderMessages) {
            if (!_messages.any((e) => e.id == msg.id)) {
              _messages.insert(0, msg);
            }
          }
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        
        // Wait for frame to calculate new extent and maintain scroll position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            final double newMaxScroll = _scroll.position.maxScrollExtent;
            _scroll.jumpTo(currentPosition + (newMaxScroll - maxScroll));
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading older messages: \$e");
    } finally {
      setState(() => _isLoadingOldMessages = false);
    }
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
        
        _localDb.insertMessage(msg);

        setState(() { 
          if (!_messages.any((e) => e.id == msg.id)) {
            _messages.add(msg); 
          }
        });
        _scrollToBottom();
      },
    ).subscribe((status, [_]) {
      // status could be used to update connection UI, but we already use connectivity_plus
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    
    if (_connectionStatus == 'offline') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot send messages while offline')));
      return;
    }
    
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
