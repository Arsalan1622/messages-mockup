# Messages (mockup)

A testing clone of Google Messages for Android — **for mockup/testing only**.
It shows the phone's real SMS inbox (read-only) and lets you simulate
incoming messages that live only on this phone. Use the real Google Messages
app for actual messaging.

Package: `com.kakar.messagesmock` · Flutter · fully offline.

## What it does

- **Inbox** — real SMS conversations merged with simulated ones, Google
  Messages style: coloured avatar circles, name/number, preview, day/time,
  unread badges, search, pull-to-refresh.
- **Conversation** — bubbles (received left, sent right in light purple),
  date separators (`Sunday, Nov 8 • 5:24 PM`), timestamps.
- **Simulate incoming message** — from the ⋮ menu, the "Start chat" button,
  or a conversation's menu. Fields: sender number/name (free text, e.g.
  `9221`, `9771`), message text, optional custom date/time. The message is
  stored locally (sqflite) and appears in the inbox + conversation exactly
  like a real received message.
- **Delete simulated only** — long-press a simulated message or conversation
  to delete it. Real SMS are read-only in this app and cannot be deleted.

## What it never does

- **Never sends anything.** No `SEND_SMS` permission, no SMS provider
  writes, no network permission. Simulated messages never leave the phone.
- No account, no cloud, no analytics.

## Permissions

| Permission | Why |
|---|---|
| `READ_SMS` | Show the real SMS inbox. If denied, the app still works with simulated messages only, and offers a retry. |
| `READ_CONTACTS` | Show phonebook names instead of numbers. Optional — numbers are shown without it. |

## Phone test (v1.0)

1. Uninstall any older build of this app, then install the APK.
2. On first launch, read the explainer and tap **Got it**.
3. Tap **Allow** on the SMS banner so real conversations appear.
4. Check the inbox matches Google Messages: same conversations, previews,
   times, unread badges.
5. Tap **Start chat** → **Simulate incoming message**, sender `9221`,
   message `Test message`, save. It must appear at the top of the inbox and
   inside the `9221` conversation as a received bubble.
6. Long-press the simulated message → delete it; long-press the conversation
   → delete simulated messages. Real SMS must be untouched.
7. Confirm nothing was sent: check the real Google Messages app — no new
   message from `9221` appears there, and no SMS was sent from the phone.

## Build

GitHub Actions builds the release APK on every push to `main` (tests run
before the build). Pushing a tag like `v1.0`, or clicking **Run workflow**
in the Actions tab, also publishes a GitHub release with the APK attached
(manual runs publish as `v1.0`).

Release signing needs these repo secrets (values live only in the local
`keystore-backup/` folder, never in this repo):

- `ANDROID_KEYSTORE_BASE64` — base64 of the release keystore
- `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`

Without them the CI build produces an **unsigned** release APK; sign it with
`apksigner` using the backed-up keystore. All future versions must use the
same keystore or Android will refuse to install them over v1.0.

Binary assets (launcher icons, Gradle wrapper jar) are stored as base64 text
under `tools/assets/` and restored by `tools/decode-assets.sh` before the
build, because the upload route only carries UTF-8 files.
