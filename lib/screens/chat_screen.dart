import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:intl/intl.dart';
import '../utils/time_utils.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/local_database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

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
  String? _sectionId;
  RealtimeChannel? _channel;
  
  // Typing Indicator Logic
  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};
  Timer? _localTypingTimer;
  bool _isTyping = false;

  // SaaS Light Colors
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textGray = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller.addListener(_onTypingChanged);
    _initChat();
    _checkConnectivity();
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.client.removeChannel(_channel!);
    _localTypingTimer?.cancel();
    for (var timer in _typingTimers.values) {
      timer.cancel();
    }
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
    final statusColor = (isMe ? Colors.white70 : _textGray).withOpacity(0.5);
    
    return Padding(
      padding: EdgeInsets.only(top: showName ? 16 : 2, bottom: 2),
      child: GestureDetector(
        onTap: () => _showDetails(msg),
        onLongPress: () => _showOptions(msg),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showName) ...[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _primaryBlue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))
                  ],
                ),
                child: _buildAvatar(msg.senderName, size: 34),
              ),
              const SizedBox(width: 8),
            ] else if (!isMe && !showName) ...[
              const SizedBox(width: 42),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [_primaryBlue, _primaryBlue.withBlue(230)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe ? _primaryBlue.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showName && !isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          msg.senderName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue.withOpacity(0.9),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14, right: 4),
                          child: Text(
                            msg.text,
                            style: GoogleFonts.inter(
                              color: isMe ? Colors.white : _textDark,
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (msg.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(right: 3, bottom: 1),
                                  child: Icon(Icons.edit_rounded, size: 10, color: statusColor),
                                ),
                              Text(
                                EthiopianTimeUtils.format(DateTime.fromMillisecondsSinceEpoch(msg.timestamp)),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  msg.seenBy.isEmpty ? Icons.done : Icons.done_all,
                                  size: 13,
                                  color: msg.seenBy.isEmpty 
                                    ? statusColor 
                                    : Colors.cyanAccent.withOpacity(0.9),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
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
          _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  // --- INPUT & STATE LOGIC ---

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
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

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    String text;
    if (_typingUsers.length == 1) {
      text = "${_typingUsers.values.first} is typing...";
    } else if (_typingUsers.length == 2) {
      text = "${_typingUsers.values.elementAt(0)} and ${_typingUsers.values.elementAt(1)} are typing...";
    } else {
      text = "${_typingUsers.length} people are typing...";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) => _TypingDot(index: index)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _textGray,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
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
      setState(() => _sectionId = data['section'].toString());
    }
  }

  Future<void> _loadLocalMessages() async {
    if (_sectionId == null) return;
    final localMsgs = await _localDb.getMessages(_sectionId!, limit: 20);
    setState(() {
      _messages = localMsgs.reversed.toList();
    });
    // Scroll to bottom only initially
    if (_messages.isNotEmpty) {
      _scrollToBottom();
      // Bulk mark as seen (only messages where I'm not in seenBy)
      _markVisibleMessagesAsSeen();
    }
  }

  Future<void> _syncNewMessages() async {
    if (_connectionStatus == 'offline' || _sectionId == null) return;

    int? latestTimestamp = await _localDb.getLatestTimestamp(_sectionId!);
    
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
        isEdited: m['is_edited'] == true,
        seenBy: m['seen_by'] != null 
            ? List<Map<String, String>>.from((m['seen_by'] as List).map((e) => Map<String, String>.from(e)))
            : [],
      )).toList();
      
      await _localDb.insertMessages(newMessages);
      
      setState(() {
        for (var msg in newMessages) {
          if (!_messages.any((e) => e.id == msg.id)) {
            _messages.add(msg);
            _markAsSeen(msg);
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
          for (var msg in olderMessages) {
            _markAsSeen(msg);
          }
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
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'section', value: _sectionId!),
      callback: (payload) {
        debugPrint("Chat Realtime Event: ${payload.eventType}");
        if (payload.eventType == PostgresChangeEvent.insert) {
          final m = payload.newRecord;
          debugPrint("New Message Received: ${m['id']}");
          final msg = ChatMessage(
            id: m['id'].toString(),
            role: m['role'] ?? 'user',
            senderId: m['sender_id'] ?? '',
            senderName: m['sender_name'] ?? 'Unknown',
            text: m['text'] ?? '',
            timestamp: (m['timestamp'] as num).toInt(),
            section: m['section']?.toString() ?? '',
            isEdited: m['is_edited'] == true,
            seenBy: m['seen_by'] != null 
                ? List<Map<String, String>>.from((m['seen_by'] as List).map((e) => Map<String, String>.from(e)))
                : [],
          );
          
          _localDb.insertMessage(msg);

          setState(() { 
            if (!_messages.any((e) => e.id == msg.id)) {
              _messages.add(msg); 
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }
          });
          _scrollToBottom();
          _markAsSeen(msg);
        } else if (payload.eventType == PostgresChangeEvent.update) {
          final m = payload.newRecord;
          final id = m['id'].toString();
          final text = m['text']?.toString();
          final isEdited = m['is_edited'] == true;
          final timestamp = (m['timestamp'] as num?)?.toInt();
          final seenBy = m['seen_by'] != null 
              ? List<Map<String, String>>.from((m['seen_by'] as List).map((e) => Map<String, String>.from(e)))
              : <Map<String, String>>[];
          
          if (text != null) _localDb.updateMessage(id, text);
          _localDb.updateMessageReceipts(id, seenBy);
          
          setState(() {
            final idx = _messages.indexWhere((e) => e.id == id);
            if (idx != -1) {
              _messages[idx] = ChatMessage(
                id: _messages[idx].id,
                role: _messages[idx].role,
                senderId: _messages[idx].senderId,
                senderName: _messages[idx].senderName,
                text: text ?? _messages[idx].text,
                timestamp: timestamp ?? _messages[idx].timestamp,
                section: _messages[idx].section,
                isEdited: isEdited,
                seenBy: seenBy,
              );
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }
          });
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final id = payload.oldRecord['id'].toString();
          debugPrint("Message Deleted Realtime: $id");
          _localDb.deleteMessage(id);
          setState(() {
            _messages.removeWhere((e) => e.id == id);
          });
        }
      },
    ).onBroadcast(
      event: 'typing',
      callback: (payload) {
        final String? userId = payload['user_id']?.toString();
        final String? userName = payload['user_name']?.toString();
        final bool isTyping = payload['typing'] == true;

        if (userId == null || userId == widget.userId) return;

        setState(() {
          if (isTyping) {
            _typingUsers[userId] = userName ?? "Someone";
            
            // Timeout protection: remove user if no update for 4 seconds
            _typingTimers[userId]?.cancel();
            _typingTimers[userId] = Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  _typingUsers.remove(userId);
                  _typingTimers.remove(userId);
                });
              }
            });
          } else {
            _typingUsers.remove(userId);
            _typingTimers[userId]?.cancel();
            _typingTimers[userId] = Timer(const Duration(milliseconds: 500), () { // Slight delay for smoother UI
               if (mounted) {
                 setState(() {
                    _typingTimers.remove(userId);
                 });
               }
            });
          }
        });
      },
    ).subscribe();
  }

  void _onTypingChanged() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    }

    _localTypingTimer?.cancel();
    _localTypingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingStatus(false);
      }
    });

    if (text.isEmpty && _isTyping) {
      _isTyping = false;
      _sendTypingStatus(false);
      _localTypingTimer?.cancel();
    }
  }

  void _sendTypingStatus(bool isTyping) {
    if (_channel == null || _sectionId == null) return;
    unawaited(_channel!.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'user_id': widget.userId,
        'user_name': widget.student.name,
        'section_id': _sectionId,
        'typing': isTyping,
      },
    ));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    
    if (_connectionStatus == 'offline') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot send messages while offline')));
      return;
    }
    
    _controller.clear();
    _isTyping = false;
    _sendTypingStatus(false);
    _localTypingTimer?.cancel();
    
    setState(() => _isSending = true);
    try {
      await SupabaseService.client.from('chat_messages').insert({
        'sender_id': widget.userId,
        'sender_name': widget.student.name,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'section': _sectionId!,
      });

      // Send push notifications server-side (so secrets are not shipped in the app)
      try {
        final sectionId = _sectionId!;
        final payload = {
          'section': sectionId,
          // 'exclude_user_id': widget.userId,
          'title': widget.student.name,
          'body': text,
          'type': 'chat',
          'data': {
            'message': text,
            'senderId': widget.userId,
            'section': sectionId,
          },
        };
        
        debugPrint('--- SEND PUSH DEBUG ---');
        debugPrint('Payload: $payload');
        
        final response = await SupabaseService.client.functions.invoke(
          'send_push',
          body: payload,
        );
        
        debugPrint('Response: ${response.data}');
        debugPrint('-----------------------');
      } catch (e) {
        debugPrint('send_push invoke error: $e');
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showOptions(ChatMessage msg) {
    final isMe = msg.senderId == widget.userId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Message Details'),
              onTap: () {
                Navigator.pop(context);
                _showDetails(msg);
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg.id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(ChatMessage msg) {
    final date = DateTime.fromMillisecondsSinceEpoch(msg.timestamp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Message Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sender: ${msg.senderName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sent: ${EthiopianTimeUtils.format(date)}'),
              if (msg.isEdited) ...[
                const SizedBox(height: 8),
                const Text('Status: Edited', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.blue)),
              ],
              const SizedBox(height: 16),
              Text('Message:', style: TextStyle(color: _textGray, fontSize: 12)),
              const SizedBox(height: 4),
              Text(msg.text),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Seen By (${msg.seenBy.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              if (msg.seenBy.isEmpty)
                Text('No one has seen this yet', style: TextStyle(color: _textGray, fontSize: 12, fontStyle: FontStyle.italic))
              else
                ...msg.seenBy.map((user) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      _buildAvatar(user['name'] ?? '?', size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user['name'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _markVisibleMessagesAsSeen() async {
    if (_connectionStatus == 'offline' || _messages.isEmpty) return;
    
    // Only target messages I haven't seen yet and I didn't send
    final unseen = _messages.where((m) => 
      m.senderId != widget.userId && 
      !m.seenBy.any((u) => u['id'] == widget.userId)
    ).toList();

    for (var msg in unseen) {
      await _markAsSeen(msg);
    }
  }

  Future<void> _markAsSeen(ChatMessage msg) async {
    if (msg.senderId == widget.userId || _connectionStatus == 'offline') return;
    
    final alreadySeen = msg.seenBy.any((u) => u['id'] == widget.userId);
    if (!alreadySeen) {
      try {
        final newSeenBy = List<Map<String, String>>.from(msg.seenBy);
        newSeenBy.add({'id': widget.userId, 'name': widget.student.name});
        
        await SupabaseService.client
            .from('chat_messages')
            .update({'seen_by': newSeenBy})
            .eq('id', msg.id);
            
        _localDb.updateMessageReceipts(msg.id, newSeenBy);
      } catch (e) {
        debugPrint("Error marking as seen: $e");
      }
    }
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final editController = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Modify message...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != msg.text) {
                Navigator.pop(context);
                try {
                  final response = await SupabaseService.client
                      .from('chat_messages')
                      .update({
                        'text': newText,
                        'is_edited': true,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      })
                      .eq('id', msg.id)
                      .select();

                  if (response.isEmpty) {
                    throw 'No message was updated. This usually means you do not have permission to edit this message (Row Level Security) or the message ID is invalid.';
                  }
                  debugPrint("Chat Message Updated: ${msg.id}");
                } catch (e) {
                  debugPrint("CRITICAL ERROR editing message: $e");
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Edit Failed'),
                        content: Text('Reason: $e\n\nTips: Check if Row Level Security (RLS) is enabled in Supabase and allows UPDATES for your user.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                      ),
                    );
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await SupabaseService.client
            .from('chat_messages')
            .delete()
            .eq('id', id)
            .select();

        if (response.isEmpty) {
          throw 'No message was deleted. This usually means you do not have permission to delete this message or it was already deleted.';
        }
        debugPrint("Chat Message Deleted: $id");
      } catch (e) {
        debugPrint("CRITICAL ERROR deleting message: $e");
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Failed'),
              content: Text('Reason: $e\n\nCheck your Supabase RLS policies for the "delete" operation.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }
}

class _TypingDot extends StatefulWidget {
  final int index;
  const _TypingDot({required this.index});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Color(0xFF64748B),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
