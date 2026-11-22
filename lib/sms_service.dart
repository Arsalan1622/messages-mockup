import 'package:flutter/services.dart';

import 'models.dart';

/// Reads the phone's real SMS store through a small Kotlin platform channel
/// (content://sms). Read-only: this app never writes to the SMS provider and
/// never sends anything.
class SmsService {
  static const _channel = MethodChannel('com.kakar.messagesmock/sms');

  /// All SMS (received + sent), newest first. Empty list when the provider
  /// has nothing or the permission is missing.
  Future<List<ChatMessage>> getAllSms() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getAllSms');
      if (raw == null) return [];
      final out = <ChatMessage>[];
      for (final item in raw) {
        final m = Map<String, dynamic>.from(item as Map);
        final address = (m['address'] as String?)?.trim() ?? '';
        final body = (m['body'] as String?) ?? '';
        final millis = (m['date'] as num?)?.toInt() ?? 0;
        if (address.isEmpty || body.isEmpty) continue;
        out.add(ChatMessage(
          address: address,
          body: body,
          timestamp: DateTime.fromMillisecondsSinceEpoch(millis),
          isSent: (m['type'] as num?)?.toInt() == 2,
          isRead: (m['read'] as num?)?.toInt() == 1,
        ));
      }
      return out;
    } on PlatformException {
      return [];
    }
  }

  /// Phonebook display names for the given addresses (short codes and
  /// unsaved numbers simply have no entry).
  Future<Map<String, String>> getContactNames(
      List<String> addresses) async {
    if (addresses.isEmpty) return {};
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getContactNames',
        {'addresses': addresses},
      );
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } on PlatformException {
      return {};
    }
  }
}
