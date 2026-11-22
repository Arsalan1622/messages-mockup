import 'package:flutter/material.dart';

import 'inbox_screen.dart';
import 'sim_store.dart';

/// Messages (mockup) — a testing clone of Google Messages.
///
/// Shows the phone's real SMS inbox (read-only) and lets the user simulate
/// incoming messages that live only on this phone. This app NEVER sends
/// anything: it has no SEND_SMS permission and no network permission.
void main() {
  runApp(const MessagesMockApp());
}

class MessagesMockApp extends StatelessWidget {
  const MessagesMockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Messages',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFBFE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFBFE),
          foregroundColor: Colors.black87,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFE8DEF8),
          foregroundColor: Colors.black87,
          elevation: 2,
        ),
      ),
      home: const _FirstRunGate(child: InboxScreen()),
    );
  }
}

/// Shows the one-time explainer on first launch so this mockup is never
/// confused with the real Google Messages app.
class _FirstRunGate extends StatefulWidget {
  const _FirstRunGate({required this.child});
  final Widget child;

  @override
  State<_FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<_FirstRunGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await SimStore.instance.getMeta('first_run_seen');
      if (seen == '1' || !mounted) return;
      await SimStore.instance.setMeta('first_run_seen', '1');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Testing mockup — not real Messages'),
          content: const Text(
            'This app looks like Google Messages, but it is only a mockup '
            'for testing:\n\n'
            '• It shows your real SMS inbox (read-only).\n'
            '• "Simulate incoming message" adds a fake message that stays '
            'only on this phone.\n'
            '• It can never send SMS. Use the real Google Messages app '
            'for actual messaging.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
