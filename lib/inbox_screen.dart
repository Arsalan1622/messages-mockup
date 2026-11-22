import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'avatar.dart';
import 'conversation_screen.dart';
import 'models.dart';
import 'sim_store.dart';
import 'simulate_screen.dart';
import 'sms_service.dart';

/// Inbox: real SMS + locally simulated messages, merged and sorted by time,
/// in the Google Messages layout.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _sms = SmsService();
  List<Conversation> _conversations = [];
  bool _loading = true;
  bool _smsAllowed = false;
  bool _smsPermanentlyDenied = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final smsStatus = await Permission.sms.status;
    _smsAllowed = smsStatus.isGranted;
    _smsPermanentlyDenied = smsStatus.isPermanentlyDenied;

    List<ChatMessage> real = [];
    Map<String, String> names = {};
    if (_smsAllowed) {
      real = await _sms.getAllSms();
      if (await Permission.contacts.isGranted) {
        final addresses =
            real.map((m) => m.address).toSet().toList(growable: false);
        names = await _sms.getContactNames(addresses);
      }
    }
    final simulated = await SimStore.instance.getAll();
    if (!mounted) return;
    setState(() {
      _conversations = mergeConversations(real, simulated, names);
      _loading = false;
    });
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (status.isGranted) {
      // Contacts are optional: names for saved contacts, numbers otherwise.
      await Permission.contacts.request();
    }
    await _load();
  }

  List<Conversation> get _visible {
    if (_query.trim().isEmpty) return _conversations;
    final q = _query.trim().toLowerCase();
    return _conversations.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q) ||
          c.latest.body.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openSimulator({String? address, String? displayName}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SimulateScreen(
          initialAddress: address,
          initialDisplayName: displayName,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About this app'),
        content: const Text(
          'Messages (mockup) is for testing only.\n\n'
          '• It shows your real SMS inbox (read-only).\n'
          '• "Simulate incoming message" adds a fake received message that '
          'lives only on this phone — it is never sent anywhere.\n'
          '• This app cannot send SMS at all. Use the real Google Messages '
          'app for actual messaging.\n\n'
          'Long-press a simulated message or conversation to delete it. '
          'Real SMS cannot be deleted from this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStartChatSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Simulate incoming message'),
              subtitle: const Text(
                  'Add a fake received message — stored only on this phone'),
              onTap: () {
                Navigator.of(context).pop();
                _openSimulator();
              },
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('This app never sends messages'),
              subtitle: Text('Use the real Google Messages app to send SMS'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onConversationLongPress(Conversation conv) async {
    if (!conv.hasSimulated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Real SMS — read-only in this app, cannot delete.'),
        ),
      );
      return;
    }
    final realCount = conv.messages.where((m) => !m.isSimulated).length;
    final simCount = conv.messages.length - realCount;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete simulated messages?'),
        content: Text(
          realCount > 0
              ? 'This removes $simCount simulated message(s) from '
                  '${conv.displayName}. The $realCount real SMS stay.'
              : 'This removes the $simCount simulated message(s) and the '
                  'conversation disappears.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SimStore.instance.deleteConversation(conv.address);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () async {
              final q = await showSearch<String>(
                context: context,
                delegate: _ConversationSearch(_conversations),
              );
              if (q != null && mounted) setState(() => _query = q);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.person,
                  color: colorScheme.onPrimaryContainer, size: 22),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'simulate') _openSimulator();
              if (value == 'about') _showAbout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'simulate',
                child: ListTile(
                  leading: Icon(Icons.sms_outlined),
                  title: Text('Simulate incoming message'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About this app'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_smsAllowed && !_loading) _permissionBanner(),
          if (_query.isNotEmpty)
            Material(
              color: colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: const Icon(Icons.search),
                title: Text('Search: "$_query"'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _query = ''),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visible.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _visible.length,
                          itemBuilder: (context, i) =>
                              _row(_visible[i], colorScheme),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStartChatSheet,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Start chat'),
      ),
    );
  }

  Widget _permissionBanner() {
    return Material(
      color: Colors.amber.shade100,
      child: ListTile(
        leading: const Icon(Icons.sms_outlined),
        title: const Text('Show your real messages?'),
        subtitle: const Text(
          'Allow SMS permission to see your real inbox here. '
          'Simulated messages work without it.',
        ),
        trailing: TextButton(
          onPressed: _smsPermanentlyDenied
              ? openAppSettings
              : _requestSmsPermission,
          child: Text(_smsPermanentlyDenied ? 'Settings' : 'Allow'),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.message_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _smsAllowed
                  ? 'Your inbox is empty. Simulate a message to test the app.'
                  : 'Allow SMS permission to see your real messages, or '
                      'simulate one to test the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openSimulator(),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Simulate incoming message'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Conversation conv, ColorScheme colorScheme) {
    final latest = conv.latest;
    final unread = conv.unreadCount;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: AvatarCircle(
        address: conv.address,
        displayName: conv.displayName,
        showInitials: conv.hasContactName,
      ),
      title: Text(
        conv.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        latest.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            inboxDateLabel(latest.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: unread > 0
                  ? colorScheme.primary
                  : Colors.grey.shade600,
              fontWeight:
                  unread > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(conversation: conv),
          ),
        );
        await _load();
      },
      onLongPress: () => _onConversationLongPress(conv),
    );
  }
}

class _ConversationSearch extends SearchDelegate<String> {
  _ConversationSearch(this.conversations);
  final List<Conversation> conversations;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? conversations
        : conversations.where((c) {
            return c.displayName.toLowerCase().contains(q) ||
                c.address.toLowerCase().contains(q);
          }).toList();
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final c = matches[i];
        return ListTile(
          leading: AvatarCircle(
            address: c.address,
            displayName: c.displayName,
            showInitials: c.hasContactName,
            radius: 20,
          ),
          title: Text(c.displayName),
          subtitle: Text(c.latest.body,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            close(context, '');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConversationScreen(conversation: c),
              ),
            );
          },
        );
      },
    );
  }
}
