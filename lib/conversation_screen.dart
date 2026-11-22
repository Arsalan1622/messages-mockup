import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'avatar.dart';
import 'models.dart';
import 'sim_store.dart';
import 'simulate_screen.dart';

/// One conversation: Google Messages style bubbles, date separators, and a
/// look-alike input bar that opens the simulator instead of sending anything.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late List<ChatMessage> _messages;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.conversation.messages);
    // Opening the conversation marks its simulated messages read.
    SimStore.instance.markConversationRead(widget.conversation.address);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _openSimulator() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SimulateScreen(
          initialAddress: widget.conversation.address,
          initialDisplayName: widget.conversation.hasContactName
              ? null
              : widget.conversation.displayName,
        ),
      ),
    );
    if (saved == true) {
      final fresh = await SimStore.instance.getAll();
      final mine = fresh.where((m) =>
          normalizeAddress(m.address) ==
          normalizeAddress(widget.conversation.address));
      setState(() {
        _messages = [
          ..._messages.where((m) => !m.isSimulated),
          ...mine,
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  void _onMessageLongPress(ChatMessage m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.of(context).pop();
                Clipboard.setData(ClipboardData(text: m.body));
              },
            ),
            if (m.isSimulated)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete simulated message'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await SimStore.instance.deleteMessage(m.simId!);
                  setState(() {
                    _messages.removeWhere((x) => x.simId == m.simId);
                  });
                },
              )
            else
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Real SMS — read-only in this app'),
                subtitle: Text('Real messages cannot be deleted here'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarCircle(
              address: conv.address,
              displayName: conv.displayName,
              showInitials: conv.hasContactName,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conv.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Call (not available in mockup)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calling is not part of this mockup.'),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'simulate') _openSimulator();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'simulate',
                child: ListTile(
                  leading: Icon(Icons.sms_outlined),
                  title: Text('Simulate a message from this sender'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('No messages'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final prev = i > 0 ? _messages[i - 1] : null;
                      final newDay = prev == null ||
                          !_sameDay(prev.timestamp, m.timestamp);
                      final gap = prev != null &&
                          m.timestamp
                                  .difference(prev.timestamp)
                                  .inMinutes >=
                              60;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (newDay || gap)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                separatorLabel(m.timestamp, newDay: newDay),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          _bubble(m, colorScheme),
                        ],
                      );
                    },
                  ),
          ),
          _inputBar(colorScheme),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m, ColorScheme colorScheme) {
    final sent = m.isSent;
    return Align(
      alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _onMessageLongPress(m),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sent
                ? const Color(0xFFEADDFF) // sent: light purple
                : const Color(0xFFF0EDF5), // received: pale lavender-grey
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            m.body,
            style: const TextStyle(fontSize: 16, height: 1.35),
          ),
        ),
      ),
    );
  }

  /// Looks like the Google Messages input bar, but tapping it opens the
  /// simulator — it never sends anything.
  Widget _inputBar(ColorScheme colorScheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _openSimulator,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDF5),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: colorScheme.primary,
                        tooltip: 'Simulate a message',
                        onPressed: _openSimulator,
                      ),
                      const Expanded(
                        child: Text(
                          'Text message',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        color: Colors.grey.shade600,
                        onPressed: _openSimulator,
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        color: Colors.grey.shade600,
                        onPressed: _openSimulator,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _openSimulator,
              backgroundColor: const Color(0xFFF8D7E8),
              foregroundColor: Colors.black87,
              elevation: 0,
              child: const Icon(Icons.graphic_eq),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
