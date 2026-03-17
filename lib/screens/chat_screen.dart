import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:intl/intl.dart';
import '../utils/time_utils.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/local_database_service.dart';
import 'group_profile_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:math' as math;

class ChatScreen extends StatefulWidget {
  final Student student;
  final String userId;
  final String? sectionId;
  final ChatGroup? group;

  const ChatScreen({
    super.key,
    required this.student,
    required this.userId,
    this.sectionId,
    this.group,
  });

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
  RealtimeChannel? _channel;
  String? _groupId;
  String? _chatTitle;
  bool _isGroup = false;
  String? _sectionId;
  ChatGroup? _activeGroup;

  // Typing Indicator Logic
  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingTimers = {};
  Timer? _localTypingTimer;
  bool _isTyping = false;

  // Premium Design Colors
  final Color _primaryColor = const Color(0xFF4F46E5); // Indigo
  final Color _accentColor = const Color(0xFF818CF8);
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;
  final Color _textDark = const Color(0xFF1E293B);
  final Color _textGray = const Color(0xFF64748B);
  final Color _meBubbleGradientStart = const Color(0xFF4F46E5);
  final Color _meBubbleGradientEnd = const Color(0xFF7C3AED);
  final Color _otherBubbleColor = const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _activeGroup = widget.group;
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

    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
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

  Future<void> _openGroupProfile() async {
    if (_activeGroup == null) return;

    final updated = await Navigator.push<ChatGroup>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupProfileScreen(
          student: widget.student,
          userId: widget.userId,
          group: _activeGroup!,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _activeGroup = updated;
        _chatTitle = updated.name;
      });
    }
  }

  // --- UI COMPONENTS ---

  /// Replaces the buggy NetworkImage and ui-avatars API
  Widget _buildAvatar(
    String name, {
    double size = 40,
    Color? color,
    String? imageUrl,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color ?? _primaryColor,
            (color ?? _primaryColor).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.35),
        boxShadow: [
          BoxShadow(
            color: (color ?? _primaryColor).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.35),
              child: Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.45,
                  ),
                ),
              ),
            )
          : Text(
              initial,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.45,
              ),
            ),
    );
  }

  Widget _buildDateSeparator(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String label;
    if (isToday) {
      label = "Today";
    } else if (isYesterday) {
      label = "Yesterday";
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: Divider(color: _textGray.withOpacity(0.1), thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _textGray.withOpacity(0.05)),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _textGray,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(color: _textGray.withOpacity(0.1), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isMe, bool showName) {
    final statusColor = (isMe ? Colors.white70 : _textGray).withOpacity(0.6);

    return Padding(
      padding: EdgeInsets.only(top: showName ? 18 : 3, bottom: 3),
      child: GestureDetector(
        onTap: () => _showDetails(msg),
        onLongPress: () => _showOptions(msg),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showName) ...[
              _buildAvatar(
                msg.senderName,
                size: 36,
                imageUrl: msg.senderAvatarUrl,
              ),
              const SizedBox(width: 10),
            ] else if (!isMe && !showName) ...[
              const SizedBox(width: 46),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            _meBubbleGradientStart,
                            _meBubbleGradientEnd,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : _otherBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isMe ? 22 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? _primaryColor.withOpacity(0.25)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 10,
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
                        padding: const EdgeInsets.only(bottom: 6, left: 2),
                        child: Text(
                          msg.senderName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    Text(
                      msg.text,
                      style: GoogleFonts.inter(
                        color: isMe ? Colors.white : _textDark,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.isEdited)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 10,
                              color: statusColor,
                            ),
                          ),
                        Text(
                          EthiopianTimeUtils.format(
                            DateTime.fromMillisecondsSinceEpoch(msg.timestamp),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Icon(
                            msg.seenBy.isEmpty ? Icons.done : Icons.done_all,
                            size: 14,
                            color: msg.seenBy.isEmpty
                                ? statusColor
                                : const Color(0xFF22D3EE), // Cyan
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 2,
        leadingWidth: 40,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textDark,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: GestureDetector(
          onTap: _activeGroup != null ? _openGroupProfile : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              _buildAvatar(
                _activeGroup?.name ?? _sectionId ?? "S",
                size: 38,
                color: _accentColor,
                imageUrl: _activeGroup?.avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chatTitle ?? 'Loading...',
                      style: GoogleFonts.plusJakartaSans(
                        color: _textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _connectionStatus == 'online'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (_connectionStatus == 'online')
                                BoxShadow(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _connectionStatus == 'online'
                              ? 'Online'
                              : 'Disconnected',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _textGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_activeGroup != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: _textGray.withOpacity(0.8),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: _textGray),
            onPressed: _activeGroup != null ? _openGroupProfile : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: (_sectionId == null && _groupId == null)
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    itemCount:
                        _messages.length + (_isLoadingOldMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && _isLoadingOldMessages) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final msgIndex = _isLoadingOldMessages
                          ? index - 1
                          : index;
                      final msg = _messages[msgIndex];
                      final isMe = msg.senderId == widget.userId;

                      bool showDate = true;
                      if (msgIndex > 0) {
                        final prevMsg = _messages[msgIndex - 1];
                        final date1 = DateTime.fromMillisecondsSinceEpoch(
                          msg.timestamp,
                        );
                        final date2 = DateTime.fromMillisecondsSinceEpoch(
                          prevMsg.timestamp,
                        );
                        if (date1.year == date2.year &&
                            date1.month == date2.month &&
                            date1.day == date2.day) {
                          showDate = false;
                        }
                      }

                      final bool showName =
                          msgIndex == 0 ||
                          showDate ||
                          _messages[msgIndex - 1].senderId != msg.senderId;

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
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _otherBubbleColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: _primaryColor),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _textGray.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(fontSize: 15, color: _textDark),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: GoogleFonts.inter(
                    color: _textGray.withOpacity(0.6),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_meBubbleGradientStart, _meBubbleGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final hasTyping = _typingUsers.isNotEmpty;

    String text;
    if (_typingUsers.length == 1) {
      text = "${_typingUsers.values.first} is typing...";
    } else if (_typingUsers.length == 2) {
      text =
          "${_typingUsers.values.elementAt(0)} and ${_typingUsers.values.elementAt(1)} are typing...";
    } else {
      text = "${_typingUsers.length} people are typing...";
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final slide =
            Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: !hasTyping
          ? const SizedBox(key: ValueKey('typing-empty'))
          : Container(
              key: const ValueKey('typing-active'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withOpacity(0.10),
                    _accentColor.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryColor.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _TypingDot(index: index, color: _primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Typing now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _primaryColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          text,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _textDark,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 64,
              color: _primaryColor.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No messages yet",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Be the first to say hello to the section!",
            style: GoogleFonts.inter(fontSize: 14, color: _textGray),
          ),
        ],
      ),
    );
  }

  // --- DATA LOGIC ---

  Future<void> _initChat() async {
    if (_activeGroup != null) {
      setState(() {
        _groupId = _activeGroup!.id;
        _chatTitle = _activeGroup!.name;
        _isGroup = true;
      });
    } else if (widget.sectionId != null) {
      setState(() {
        _sectionId = widget.sectionId;
        _chatTitle = 'Section $_sectionId Chat';
      });
    } else {
      await _loadContext();
    }

    if (_sectionId != null || _groupId != null) {
      await _loadLocalMessages();
      _syncNewMessages();
      _subscribeRealtime();
    }
  }

  Future<void> _loadContext() async {
    final data = await SupabaseService.client
        .from('profiles')
        .select('section')
        .eq('id', widget.userId)
        .maybeSingle();
    if (data != null && data['section'] != null) {
      setState(() {
        _sectionId = data['section'].toString();
        _chatTitle = 'Section $_sectionId Chat';
      });
    }
  }

  Future<void> _loadLocalMessages() async {
    if (_sectionId == null && _groupId == null) return;
    final localMsgs = _isGroup
        ? await _localDb.getGroupMessages(_groupId!, limit: 20)
        : await _localDb.getMessages(_sectionId!, limit: 20);
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
    if (_connectionStatus == 'offline' ||
        (_sectionId == null && _groupId == null))
      return;

    int? latestTimestamp = _isGroup
        ? await _localDb.getLatestGroupTimestamp(_groupId!)
        : await _localDb.getLatestTimestamp(_sectionId!);

    SupabaseQueryBuilder query = SupabaseService.client.from('chat_messages');
    PostgrestFilterBuilder filter = _isGroup
        ? query.select('*, profiles(avater_url)').eq('group_id', _groupId!)
        : query.select('*, profiles(avater_url)').eq('section', _sectionId!);

    List<dynamic> data;
    if (latestTimestamp != null) {
      data = await filter
          .gt('timestamp', latestTimestamp)
          .order('timestamp', ascending: true);
    } else {
      // If we don't have any local messages, we should probably fetch the latest 20
      data = await filter.order('timestamp', ascending: false).limit(20);
      data = data.reversed.toList();
    }

    if (data.isNotEmpty) {
      final newMessages = data
          .map(
            (m) => ChatMessage(
              id: m['id'].toString(),
              role: m['role'] ?? 'user',
              senderId: m['sender_id'] ?? '',
              senderName: m['sender_name'] ?? 'Unknown',
              senderAvatarUrl: m['profiles']?['avater_url'],
              text: m['text'] ?? '',
              timestamp: (m['timestamp'] as num).toInt(),
              section: m['section']?.toString(),
              groupId: m['group_id']?.toString(),
              isEdited: m['is_edited'] == true,
              seenBy: m['seen_by'] != null
                  ? List<Map<String, String>>.from(
                      (m['seen_by'] as List).map(
                        (e) => Map<String, String>.from(e),
                      ),
                    )
                  : [],
            ),
          )
          .toList();

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
    if (_isLoadingOldMessages ||
        _messages.isEmpty ||
        (_sectionId == null && _groupId == null))
      return;

    setState(() => _isLoadingOldMessages = true);

    try {
      final oldestTimestamp = _messages.first.timestamp;

      // Try local DB first
      List<ChatMessage> olderMessages = _isGroup
          ? await _localDb.getGroupMessages(
              _groupId!,
              beforeTimestamp: oldestTimestamp,
              limit: 20,
            )
          : await _localDb.getMessages(
              _sectionId!,
              beforeTimestamp: oldestTimestamp,
              limit: 20,
            );

      // If local DB doesn't have 20 messages, we try fetching from remote
      if (olderMessages.length < 20 && _connectionStatus == 'online') {
        PostgrestFilterBuilder filter = SupabaseService.client
            .from('chat_messages')
            .select('*, profiles(avater_url)');

        if (_isGroup) {
          filter = filter.eq('group_id', _groupId!);
        } else {
          filter = filter.eq('section', _sectionId!);
        }

        final data = await filter
            .lt('timestamp', oldestTimestamp)
            .order('timestamp', ascending: false)
            .limit(20);

        final remoteMessages = data
            .map(
              (m) => ChatMessage(
                id: m['id'].toString(),
                role: m['role'] ?? 'user',
                senderId: m['sender_id'] ?? '',
                senderName: m['sender_name'] ?? 'Unknown',
                senderAvatarUrl: m['profiles']?['avater_url'],
                text: m['text'] ?? '',
                timestamp: (m['timestamp'] as num).toInt(),
                section: m['section']?.toString(),
                groupId: m['group_id']?.toString(),
              ),
            )
            .toList();

        if (remoteMessages.isNotEmpty) {
          await _localDb.insertMessages(remoteMessages);
          olderMessages =
              remoteMessages; // Use remote, as we should have all or overlapping
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
    final channelName = _isGroup ? 'chat_group_$_groupId' : 'chat_$_sectionId';
    final filterCol = _isGroup ? 'group_id' : 'section';
    final filterVal = _isGroup ? _groupId! : _sectionId!;

    _channel = SupabaseService.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: filterCol,
            value: filterVal,
          ),
          callback: (payload) async {
            debugPrint("Chat Realtime Event: ${payload.eventType}");
            if (payload.eventType == PostgresChangeEvent.insert) {
              final m = payload.newRecord;
              debugPrint("New Message Received: ${m['id']}");

              // Fetch avatar URL for the new message sender
              String? avatarUrl;
              try {
                final profile = await SupabaseService.client
                    .from('profiles')
                    .select('avater_url')
                    .eq('id', m['sender_id'])
                    .maybeSingle();
                avatarUrl = profile?['avater_url'];
              } catch (e) {
                debugPrint("Error fetching avatar for real-time: $e");
              }

              final msg = ChatMessage(
                id: m['id'].toString(),
                role: m['role'] ?? 'user',
                senderId: m['sender_id'] ?? '',
                senderName: m['sender_name'] ?? 'Unknown',
                senderAvatarUrl: avatarUrl,
                text: m['text'] ?? '',
                timestamp: (m['timestamp'] as num).toInt(),
                section: m['section']?.toString(),
                groupId: m['group_id']?.toString(),
                isEdited: m['is_edited'] == true,
                seenBy: m['seen_by'] != null
                    ? List<Map<String, String>>.from(
                        (m['seen_by'] as List).map(
                          (e) => Map<String, String>.from(e),
                        ),
                      )
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
                  ? List<Map<String, String>>.from(
                      (m['seen_by'] as List).map(
                        (e) => Map<String, String>.from(e),
                      ),
                    )
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
                    groupId: _messages[idx].groupId,
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
        )
        .onBroadcast(
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
                _typingTimers[userId] = Timer(
                  const Duration(milliseconds: 500),
                  () {
                    // Slight delay for smoother UI
                    if (mounted) {
                      setState(() {
                        _typingTimers.remove(userId);
                      });
                    }
                  },
                );
              }
            });
          },
        )
        .subscribe();
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
    if (_channel == null || (_sectionId == null && _groupId == null)) return;
    unawaited(
      _channel!.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': widget.userId,
          'user_name': widget.student.name,
          'section_id': _sectionId,
          'group_id': _groupId,
          'typing': isTyping,
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_connectionStatus == 'offline') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send messages while offline')),
      );
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
        if (_sectionId != null) 'section': _sectionId,
        if (_groupId != null) 'group_id': _groupId,
      });

      // Send push notifications server-side
      try {
        final payload = {
          if (_sectionId != null) 'section': _sectionId,
          if (_groupId != null) 'group_id': _groupId,
          'title': _isGroup
              ? "${_activeGroup?.name ?? 'Group'}: ${widget.student.name}"
              : widget.student.name,
          'body': text,
          'type': 'chat',
          'data': {
            'message': text,
            'senderId': widget.userId,
            if (_sectionId != null) 'section': _sectionId,
            if (_groupId != null) 'groupId': _groupId,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                title: const Text(
                  'Delete Message',
                  style: TextStyle(color: Colors.red),
                ),
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
              Text(
                'Sender: ${msg.senderName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Sent: ${EthiopianTimeUtils.format(date)}'),
              if (msg.isEdited) ...[
                const SizedBox(height: 8),
                const Text(
                  'Status: Edited',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Message:',
                style: TextStyle(color: _textGray, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(msg.text),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Seen By (${msg.seenBy.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (msg.seenBy.isEmpty)
                Text(
                  'No one has seen this yet',
                  style: TextStyle(
                    color: _textGray,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...msg.seenBy.map(
                  (user) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _buildAvatar(
                          user['name'] ?? '?',
                          size: 24,
                          imageUrl:
                              user['avatarUrl'], // We might need to store this or fetch it
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            user['name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _markVisibleMessagesAsSeen() async {
    if (_connectionStatus == 'offline' || _messages.isEmpty) return;

    // Only target messages I haven't seen yet and I didn't send
    final unseen = _messages
        .where(
          (m) =>
              m.senderId != widget.userId &&
              !m.seenBy.any((u) => u['id'] == widget.userId),
        )
        .toList();

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
        newSeenBy.add({
          'id': widget.userId,
          'name': widget.student.name,
          'avatarUrl': widget.student.avatarUrl ?? '',
        });

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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
                        content: Text(
                          'Reason: $e\n\nTips: Check if Row Level Security (RLS) is enabled in Supabase and allows UPDATES for your user.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
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
              content: Text(
                'Reason: $e\n\nCheck your Supabase RLS policies for the "delete" operation.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
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
  final Color color;

  const _TypingDot({required this.index, required this.color});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.index * 130), () {
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final wave = math.sin(_animation.value * math.pi);
        final lift = wave * 4;
        final opacity = 0.45 + (wave * 0.55);
        final scale = 0.86 + (wave * 0.32);

        return Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.35),
                      blurRadius: 6,
                      spreadRadius: 0.3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
