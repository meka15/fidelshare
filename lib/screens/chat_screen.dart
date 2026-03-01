import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/chat_database.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Helper: list item — either a message or a date-separator header.
// ---------------------------------------------------------------------------
abstract class _ChatItem {}

class _DateSeparator extends _ChatItem {
  final String label;
  _DateSeparator(this.label);
}

class _MessageItem extends _ChatItem {
  final ChatMessage message;
  _MessageItem(this.message);
}

// ---------------------------------------------------------------------------
// ChatScreen
// ---------------------------------------------------------------------------
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
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _connectionStatus = 'connecting';
  List<ChatMessage> _messages = [];
  /// Tracks IDs already in [_messages] for O(1) duplicate detection.
  final Set<String> _messageIds = {};
  List<_ChatItem> _items = [];
  int? _sectionId;
  RealtimeChannel? _channel;
  StreamSubscription? _connectivitySub;

  static const int _pageSize = 20;
  static const double _scrollLoadThreshold = 60.0;

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
    _listenConnectivity();
  }

  @override
  void dispose() {
    if (_channel != null) SupabaseService.client.removeChannel(_channel!);
    _controller.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Connectivity listener
  // -------------------------------------------------------------------------
  void _listenConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && _sectionId != null) {
        _syncNewMessages();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Scroll listener — load older messages when user reaches the top.
  // -------------------------------------------------------------------------
  void _onScroll() {
    if (_scroll.position.pixels <= _scrollLoadThreshold && !_isLoadingMore && _hasMore) {
      _loadOlderMessages();
    }
  }

  // -------------------------------------------------------------------------
  // UI COMPONENTS
  // -------------------------------------------------------------------------

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
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: _textGray.withOpacity(0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: _textGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: _textGray.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isMe, bool showName) {
    return Padding(
      padding: EdgeInsets.only(top: showName ? 12 : 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showName) ...[
            _buildAvatar(msg.senderName, size: 32),
            const SizedBox(width: 8),
          ] else if (!isMe && !showName) ...[
            const SizedBox(width: 40),
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
                      child: Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : _textDark,
                      fontSize: 14,
                      height: 1.4,
                    ),
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
            Text(
              'Section Chat',
              style: GoogleFonts.plusJakartaSans(
                color: _textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _connectionStatus == 'online'
                        ? Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Section ${_sectionId ?? "Loading..."} • Active',
                  style: TextStyle(fontSize: 11, color: _textGray),
                ),
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
                        itemCount:
                            _items.length + (_isLoadingMore || _hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Loading indicator at top
                          if (index == 0 && (_isLoadingMore || _hasMore)) {
                            return _isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          final itemIndex =
                              (_isLoadingMore || _hasMore) ? index - 1 : index;
                          final item = _items[itemIndex];
                          if (item is _DateSeparator) {
                            return _buildDateSeparator(item.label);
                          }
                          final msg = (item as _MessageItem).message;
                          final isMe = msg.senderId == widget.userId;
                          final bool showName = itemIndex == 0 ||
                              (_items[itemIndex - 1] is _DateSeparator) ||
                              (_items[itemIndex - 1] is _MessageItem &&
                                  (_items[itemIndex - 1] as _MessageItem)
                                          .message
                                          .senderId !=
                                      msg.senderId);
                          return _buildBubble(msg, isMe, showName);
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // INPUT AREA
  // -------------------------------------------------------------------------

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Type a message...",
                fillColor: _bgLight,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _primaryBlue,
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined,
              size: 48, color: _textGray.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "No messages yet. Start the chat!",
            style: TextStyle(color: _textGray),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // DATA LOGIC
  // -------------------------------------------------------------------------

  Future<void> _initChat() async {
    await _loadSectionId();
    if (_sectionId == null) return;

    // 1. Instantly show cached messages from local DB (no network wait).
    await _loadLocalMessages();

    // 2. Sync new messages from Supabase if online.
    await _syncNewMessages();

    // 3. Subscribe to realtime for live updates.
    _subscribeRealtime();
  }

  Future<void> _loadSectionId() async {
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('section')
          .eq('id', widget.userId)
          .maybeSingle();
      if (data != null && data['section'] != null) {
        setState(
          () => _sectionId = int.tryParse(data['section'].toString()),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadLocalMessages() async {
    if (_sectionId == null) return;
    final cached = await ChatLocalDatabase.getMessages(
      _sectionId!,
      limit: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _messages = cached;
      _messageIds
        ..clear()
        ..addAll(cached.map((m) => m.id));
      _items = _buildItems(_messages);
      _hasMore = cached.length >= _pageSize;
    });
    if (cached.isNotEmpty) _scrollToBottom();
  }

  Future<void> _syncNewMessages() async {
    if (_sectionId == null) return;
    try {
      final latestTs = await ChatLocalDatabase.getLatestTimestamp(_sectionId!);

      dynamic query = SupabaseService.client
          .from('chat_messages')
          .select()
          .eq('section', _sectionId!);
      if (latestTs != null) {
        query = query.gt('timestamp', latestTs);
      }
      final List<dynamic> data =
          await query.order('timestamp', ascending: true);

      if (data.isEmpty) return;

      final newMessages = _parseMessages(data);
      await ChatLocalDatabase.insertMessages(newMessages, _sectionId!);

      if (!mounted) return;
      setState(() {
        for (final msg in newMessages) {
          if (_messageIds.add(msg.id)) {
            _messages.add(msg);
          }
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _items = _buildItems(_messages);
      });
      _scrollToBottom();
    } catch (_) {
      // Offline or network error — local cache is still shown.
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_sectionId == null || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final oldestTs = _messages.isNotEmpty ? _messages.first.timestamp : null;
      if (oldestTs == null) {
        setState(() => _hasMore = false);
        return;
      }

      final older = await ChatLocalDatabase.getMessages(
        _sectionId!,
        limit: _pageSize,
        beforeTimestamp: oldestTs,
      );

      if (older.isEmpty) {
        // Try fetching from network.
        try {
          final List<dynamic> data = await SupabaseService.client
              .from('chat_messages')
              .select()
              .eq('section', _sectionId!)
              .lt('timestamp', oldestTs)
              .order('timestamp', ascending: false)
              .limit(_pageSize);

          if (data.isNotEmpty) {
            final fetched = _parseMessages(data);
            await ChatLocalDatabase.insertMessages(fetched, _sectionId!);
            if (!mounted) return;
            setState(() => _prependMessages(fetched, fetched.length >= _pageSize));
          } else {
            setState(() => _hasMore = false);
          }
        } catch (_) {
          setState(() => _hasMore = false);
        }
        return;
      }

      if (!mounted) return;
      setState(() => _prependMessages(older, older.length >= _pageSize));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Merges [prepended] messages at the front of [_messages], deduplicating via
  /// [_messageIds], sorts by timestamp, and rebuilds [_items].
  void _prependMessages(List<ChatMessage> prepended, bool hasMore) {
    for (final msg in prepended) {
      if (_messageIds.add(msg.id)) {
        _messages.add(msg);
      }
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _items = _buildItems(_messages);
    _hasMore = hasMore;
  }

  /// Parses a raw Supabase response list into [ChatMessage] objects.
  static List<ChatMessage> _parseMessages(List<dynamic> data) {
    return data
        .map(
          (m) => ChatMessage(
            id: m['id'].toString(),
            role: m['role'] ?? 'user',
            senderId: m['sender_id'] ?? '',
            senderName: m['sender_name'] ?? 'Unknown',
            text: m['text'] ?? '',
            timestamp: (m['timestamp'] as num).toInt(),
            section: m['section']?.toString() ?? '',
          ),
        )
        .toList();
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.client
        .channel('chat_$_sectionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'section',
            value: _sectionId!,
          ),
          callback: (payload) async {
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
            await ChatLocalDatabase.insertMessages([msg], _sectionId!);
            if (!mounted) return;
            setState(() {
              if (_messageIds.add(msg.id)) {
                _messages.add(msg);
                _items = _buildItems(_messages);
              }
            });
            _scrollToBottom();
          },
        )
        .subscribe((status, [_]) {
          if (!mounted) return;
          setState(
            () => _connectionStatus =
                status == RealtimeSubscribeStatus.subscribed
                    ? 'online'
                    : 'offline',
          );
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // -------------------------------------------------------------------------
  // DATE SEPARATOR HELPERS
  // -------------------------------------------------------------------------

  static String _dateLabel(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day) {
      return 'Today';
    }
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  static String _dayKey(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static List<_ChatItem> _buildItems(List<ChatMessage> messages) {
    final items = <_ChatItem>[];
    String? lastDay;
    for (final msg in messages) {
      final day = _dayKey(msg.timestamp);
      if (day != lastDay) {
        items.add(_DateSeparator(_dateLabel(msg.timestamp)));
        lastDay = day;
      }
      items.add(_MessageItem(msg));
    }
    return items;
  }
}
