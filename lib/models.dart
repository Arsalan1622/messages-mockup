import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One message, either read from the phone's real SMS store or simulated
/// locally by the user. Simulated messages never leave the phone and the app
/// never sends anything.
class ChatMessage {
  ChatMessage({
    required this.address,
    required this.body,
    required this.timestamp,
    required this.isSent,
    required this.isRead,
    this.isSimulated = false,
    this.simId,
    this.displayName,
  });

  final String address; // phone number / short code / sender id, as stored
  final String body;
  final DateTime timestamp;
  final bool isSent; // true = sent by the user (right bubble)
  final bool isRead;
  final bool isSimulated;
  final int? simId; // sqflite row id for simulated messages
  final String? displayName; // optional sender name given in the simulator

  ChatMessage copyWith({bool? isRead}) => ChatMessage(
        address: address,
        body: body,
        timestamp: timestamp,
        isSent: isSent,
        isRead: isRead ?? this.isRead,
        isSimulated: isSimulated,
        simId: simId,
        displayName: displayName,
      );
}

/// One inbox row: all messages with one sender, real + simulated merged.
class Conversation {
  Conversation({
    required this.address,
    required this.messages,
    this.contactName,
  });

  final String address;
  final List<ChatMessage> messages; // ascending by time
  final String? contactName;

  ChatMessage get latest => messages.last;

  int get unreadCount => messages.where((m) => !m.isRead && !m.isSent).length;

  bool get hasSimulated => messages.any((m) => m.isSimulated);

  /// Name to show: phonebook contact name first, then a name the user typed
  /// in the simulator, then the raw address.
  String get displayName {
    if (contactName != null && contactName!.isNotEmpty) return contactName!;
    for (final m in messages.reversed) {
      if (m.displayName != null && m.displayName!.isNotEmpty) {
        return m.displayName!;
      }
    }
    return address;
  }

  bool get hasContactName => contactName != null && contactName!.isNotEmpty;
}

/// Normalise an address for grouping: drop spaces, dashes and brackets so
/// "+92 300 1234567" and "03001234567" variants group sensibly. Short codes
/// (9771, 9221) are untouched.
String normalizeAddress(String address) {
  var a = address.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  return a;
}

/// Merge real SMS and simulated messages into conversations, newest first.
List<Conversation> mergeConversations(
  List<ChatMessage> real,
  List<ChatMessage> simulated,
  Map<String, String> contactNames,
) {
  final Map<String, List<ChatMessage>> byAddress = {};
  for (final m in [...real, ...simulated]) {
    byAddress.putIfAbsent(normalizeAddress(m.address), () => []).add(m);
  }
  final convs = <Conversation>[];
  for (final entry in byAddress.entries) {
    final msgs = entry.value..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final displayAddress = msgs.last.address;
    convs.add(Conversation(
      address: displayAddress,
      messages: msgs,
      contactName: contactNames[normalizeAddress(displayAddress)],
    ));
  }
  convs.sort((a, b) => b.latest.timestamp.compareTo(a.latest.timestamp));
  return convs;
}

/// Inbox right-hand label, like Google Messages: time today, weekday within
/// the last week, short date otherwise.
String inboxDateLabel(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(when.year, when.month, when.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat('h:mm a').format(when);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEE').format(when);
  if (when.year == n.year) return DateFormat('MMM d').format(when);
  return DateFormat('MMM d, yyyy').format(when);
}

/// Date separator inside a conversation, matching Google Messages:
/// "Sunday, Nov 8 • 5:24 PM" on a new day, "Sunday • 5:41 PM" for a later
/// cluster on the same day.
String separatorLabel(DateTime when, {required bool newDay}) {
  if (newDay) {
    return '${DateFormat('EEEE, MMM d').format(when)} • '
        '${DateFormat('h:mm a').format(when)}';
  }
  return '${DateFormat('EEEE').format(when)} • '
      '${DateFormat('h:mm a').format(when)}';
}

/// Avatar background colours, cycling like Google Messages.
const List<Color> avatarPalette = [
  Color(0xFF7C4DFF), // purple
  Color(0xFF29B6F6), // light blue
  Color(0xFF66BB6A), // green
  Color(0xFFFF9800), // orange
  Color(0xFFFFCA28), // yellow
  Color(0xFF26A69A), // teal
  Color(0xFFEC407A), // pink
  Color(0xFF5C6BC0), // indigo
];

Color avatarColorFor(String address) {
  var hash = 0;
  for (final c in normalizeAddress(address).codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return avatarPalette[hash % avatarPalette.length];
}

/// Initials for a saved contact, e.g. "Muhammad Arsalan" -> "MA".
String initialsFor(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
