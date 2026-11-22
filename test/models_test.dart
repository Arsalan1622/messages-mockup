import 'package:flutter_test/flutter_test.dart';
import 'package:messagesmock/models.dart';

ChatMessage msg({
  required String address,
  required String body,
  required DateTime at,
  bool sent = false,
  bool read = true,
  bool sim = false,
  int? simId,
  String? name,
}) =>
    ChatMessage(
      address: address,
      body: body,
      timestamp: at,
      isSent: sent,
      isRead: read,
      isSimulated: sim,
      simId: simId,
      displayName: name,
    );

void main() {
  group('mergeConversations', () {
    test('merges real + simulated by address, newest conversation first',
        () {
      final real = [
        msg(address: '9771', body: 'token 1', at: DateTime(2026, 11, 8, 17, 24)),
        msg(address: '9771', body: 'TOK', at: DateTime(2026, 11, 8, 17, 41), sent: true),
        msg(address: '3434', body: 'tune', at: DateTime(2026, 11, 20, 9, 0)),
      ];
      final sim = [
        msg(address: '9221', body: 'hello from 9221',
            at: DateTime(2026, 11, 22, 15, 0), read: false, sim: true, simId: 1),
        msg(address: '9771', body: 'simulated reply',
            at: DateTime(2026, 11, 22, 15, 5), read: false, sim: true, simId: 2),
      ];
      final convs = mergeConversations(real, sim, {});
      expect(convs.length, 3);
      // 9771 latest is the simulated 15:05 message -> first.
      expect(convs[0].address, '9771');
      expect(convs[0].messages.length, 3);
      expect(convs[0].latest.body, 'simulated reply');
      expect(convs[0].hasSimulated, isTrue);
      expect(convs[1].address, '9221');
      expect(convs[2].address, '3434');
    });

    test('unread badge counts unread received only, incl. simulated', () {
      final convs = mergeConversations(
        [
          msg(address: '9771', body: 'a', at: DateTime(2026, 11, 8), read: false),
          msg(address: '9771', body: 'b', at: DateTime(2026, 11, 9), read: true),
          msg(address: '9771', body: 'sent', at: DateTime(2026, 11, 10),
              sent: true, read: false),
        ],
        [
          msg(address: '9771', body: 'sim', at: DateTime(2026, 11, 11),
              read: false, sim: true, simId: 9),
        ],
        {},
      );
      expect(convs.single.unreadCount, 2); // one real + one simulated
    });

    test('display name prefers contact, then simulator name, then number',
        () {
      final withContact = mergeConversations(
        [msg(address: '03001234567', body: 'hi', at: DateTime(2026, 11, 11))],
        [],
        {'03001234567': 'Ahmed Raza'},
      );
      expect(withContact.single.displayName, 'Ahmed Raza');
      expect(withContact.single.hasContactName, isTrue);

      final withSimName = mergeConversations(
        [],
        [msg(address: '9221', body: 'hi', at: DateTime(2026, 11, 11),
            sim: true, simId: 1, name: 'MyTelenor')],
        {},
      );
      expect(withSimName.single.displayName, 'MyTelenor');

      final bare = mergeConversations(
        [msg(address: '9771', body: 'hi', at: DateTime(2026, 11, 11))],
        [],
        {},
      );
      expect(bare.single.displayName, '9771');
    });

    test('normalizes spaced/dashed variants of the same number', () {
      final convs = mergeConversations(
        [
          msg(address: '+92 300 1234567', body: 'a',
              at: DateTime(2026, 11, 11)),
          msg(address: '0300-1234567', body: 'b',
              at: DateTime(2026, 11, 12)),
        ],
        [],
        {},
      );
      // Different digit strings stay separate; formatting alone merges.
      expect(convs.length, 2);
      final same = mergeConversations(
        [
          msg(address: '0300 1234567', body: 'a',
              at: DateTime(2026, 11, 11)),
          msg(address: '0300-1234567', body: 'b',
              at: DateTime(2026, 11, 12)),
        ],
        [],
        {},
      );
      expect(same.length, 1);
      expect(same.single.messages.length, 2);
    });
  });

  group('inboxDateLabel', () {
    final now = DateTime(2026, 11, 22, 15, 0); // a Sunday
    test('today shows time', () {
      expect(inboxDateLabel(DateTime(2026, 11, 22, 9, 30), now: now),
          '9:30 AM');
    });
    test('yesterday', () {
      expect(inboxDateLabel(DateTime(2026, 11, 21, 9, 30), now: now),
          'Yesterday');
    });
    test('within the week shows weekday', () {
      expect(inboxDateLabel(DateTime(2026, 11, 20, 9, 30), now: now), 'Fri');
    });
    test('older shows short date', () {
      expect(inboxDateLabel(DateTime(2026, 11, 8, 9, 30), now: now), 'Nov 8');
    });
  });

  group('separatorLabel', () {
    test('new day includes date + time', () {
      expect(
        separatorLabel(DateTime(2026, 11, 8, 17, 24), newDay: true),
        'Sunday, Nov 8 • 5:24 PM',
      );
    });
    test('same-day gap shows weekday + time', () {
      expect(
        separatorLabel(DateTime(2026, 11, 8, 17, 41), newDay: false),
        'Sunday • 5:41 PM',
      );
    });
  });

  group('avatar + initials', () {
    test('same address always gets the same colour', () {
      expect(avatarColorFor('9771'), avatarColorFor('9771'));
    });
    test('initials', () {
      expect(initialsFor('Muhammad Arsalan'), 'MA');
      expect(initialsFor('Ahmed'), 'A');
      expect(initialsFor('  '), '');
    });
  });
}
