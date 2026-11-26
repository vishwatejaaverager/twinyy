import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseChatService {
  final FirebaseFirestore _firestore;

  FirebaseChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  /// Produces a deterministic, Firestore-safe document ID for a chat name.
  static String chatDocId(String chatName) {
    final normalized = chatName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) {
      return 'chat_${_fnv1aHex(chatName)}';
    }
    return '${normalized}_${_fnv1aHex(chatName.trim().toLowerCase())}';
  }

  /// Deterministic FNV-1a 32-bit hex hash (safe across app restarts).
  static String _fnv1aHex(String input) {
    int hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _messageDocId(String sender, String text, int timestampSec) {
    final bucket = timestampSec ~/ 60;
    return 'msg_${_fnv1aHex('$sender|$text|$bucket')}';
  }

  /// Uploads/syncs a batch of messages for a single chat into Cloud Firestore.
  Future<bool> uploadChatMessages(
    String app,
    String chatName,
    List<dynamic> messages,
  ) async {
    if (chatName.trim().isEmpty) return false;
    try {
      final docId = chatDocId(chatName);
      final chatRef = _chatsCollection.doc(docId);
      final messagesRef = chatRef.collection('messages');

      // Firestore WriteBatch supports up to 500 operations; chunk at 400.
      const chunkSize = 400;
      String lastText = '';
      int lastTimestamp = 0;

      for (int i = 0; i < messages.length; i += chunkSize) {
        final chunk = messages.sublist(
          i,
          i + chunkSize > messages.length ? messages.length : i + chunkSize,
        );
        final batch = _firestore.batch();

        for (final raw in chunk) {
          if (raw is! Map) continue;
          final sender = (raw['sender'] as String?) ?? 'other';
          final text = (raw['text'] as String?) ?? '';
          final ts = (raw['timestamp'] as num?)?.toInt() ??
              (DateTime.now().millisecondsSinceEpoch ~/ 1000);
          final deviceTime = (raw['device_time'] as num?)?.toInt() ?? (ts * 1000);
          final contactMatch = raw['contact_match'] == true;
          final contactName = raw['contact_name'] as String?;

          if (ts >= lastTimestamp && text.isNotEmpty) {
            lastTimestamp = ts;
            lastText = text;
          }

          final msgId = _messageDocId(sender, text, ts);
          batch.set(
            messagesRef.doc(msgId),
            {
              'chat_name': chatName,
              'app': app,
              'sender': sender,
              'text': text,
              'timestamp': ts,
              'device_time': deviceTime,
              'contact_match': contactMatch,
              'contact_name': ?contactName,
              'synced_at': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }

      await chatRef.set(
        {
          'chat_name': chatName,
          'app': app,
          if (lastText.isNotEmpty) 'last_message': lastText,
          if (lastTimestamp > 0) 'last_timestamp': lastTimestamp,
          'message_count': messages.length,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      developer.log(
        'Synced ${messages.length} messages for [$chatName] ($app) to Firestore',
        name: 'FirebaseChatService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to upload chat [$chatName] to Firestore: $e',
        name: 'FirebaseChatService',
      );
      return false;
    }
  }

  /// Syncs all messages for an app, grouped by chat_name.
  Future<bool> syncAppMessages(String app, List<dynamic> allMessages) async {
    if (allMessages.isEmpty) return true;
    final Map<String, List<dynamic>> grouped = {};
    for (final msg in allMessages) {
      if (msg is! Map) continue;
      final chat = (msg['chat_name'] as String?)?.trim() ?? '';
      if (chat.isEmpty) continue;
      grouped.putIfAbsent(chat, () => []).add(msg);
    }

    bool allSucceeded = true;
    for (final entry in grouped.entries) {
      final ok = await uploadChatMessages(app, entry.key, entry.value);
      if (!ok) allSucceeded = false;
    }
    return allSucceeded;
  }

  /// Appends a single message (e.g., manual reply or AI auto-reply) to Firestore.
  Future<bool> addMessage({
    required String chatName,
    required String sender,
    required String text,
    String app = 'unknown',
  }) async {
    if (chatName.trim().isEmpty || text.trim().isEmpty) return false;
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final nowSec = nowMs ~/ 1000;
      final docId = chatDocId(chatName);
      final chatRef = _chatsCollection.doc(docId);
      final msgId = _messageDocId(sender, text, nowSec);

      await chatRef.collection('messages').doc(msgId).set(
        {
          'chat_name': chatName,
          'app': app,
          'sender': sender,
          'text': text,
          'timestamp': nowSec,
          'device_time': nowMs,
          'synced_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await chatRef.set(
        {
          'chat_name': chatName,
          if (app != 'unknown') 'app': app,
          'last_message': text,
          'last_timestamp': nowSec,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to add message for [$chatName]: $e',
        name: 'FirebaseChatService',
      );
      return false;
    }
  }

  /// Fetches recent messages for a chat from Firestore in chronological order.
  Future<List<Map<String, dynamic>>> getRecentMessages(
    String chatName, {
    int limit = 25,
  }) async {
    if (chatName.trim().isEmpty) return [];
    try {
      final docId = chatDocId(chatName);
      final snap = await _chatsCollection
          .doc(docId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs
          .map((d) => d.data())
          .toList()
          .reversed
          .toList();
    } catch (e) {
      developer.log(
        'Failed to fetch recent messages for [$chatName]: $e',
        name: 'FirebaseChatService',
      );
      return [];
    }
  }

  /// Saves the Brain Sync Markdown rulebook for a contact in Firestore.
  Future<bool> saveBrainState(String chatName, String brainState) async {
    if (chatName.trim().isEmpty) return false;
    try {
      final docId = chatDocId(chatName);
      await _chatsCollection.doc(docId).set(
        {
          'chat_name': chatName,
          'brain_state': brainState,
          'brain_synced_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to save brain state for [$chatName]: $e',
        name: 'FirebaseChatService',
      );
      return false;
    }
  }

  /// Retrieves the active Brain Sync Markdown rulebook for a contact, if any.
  Future<String?> getBrainState(String chatName) async {
    if (chatName.trim().isEmpty) return null;
    try {
      final docId = chatDocId(chatName);
      final doc = await _chatsCollection.doc(docId).get();
      if (!doc.exists) return null;
      final state = doc.data()?['brain_state'] as String?;
      return (state != null && state.trim().isNotEmpty) ? state : null;
    } catch (e) {
      developer.log(
        'Failed to fetch brain state for [$chatName]: $e',
        name: 'FirebaseChatService',
      );
      return null;
    }
  }

  /// Persists the auto-reply toggle for a chat in Firestore.
  Future<void> setAutoReplyEnabled(String chatName, bool enabled) async {
    if (chatName.trim().isEmpty) return;
    try {
      final docId = chatDocId(chatName);
      await _chatsCollection.doc(docId).set(
        {
          'chat_name': chatName,
          'auto_reply_enabled': enabled,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      developer.log(
        'Failed to sync auto-reply setting for [$chatName]: $e',
        name: 'FirebaseChatService',
      );
    }
  }

  /// Loads all auto-reply settings stored in Firestore.
  Future<Map<String, bool>> getAllAutoReplySettings() async {
    try {
      final snap = await _chatsCollection.get();
      final Map<String, bool> result = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = data['chat_name'] as String?;
        final enabled = data['auto_reply_enabled'];
        if (name != null && enabled is bool) {
          result[name] = enabled;
        }
      }
      return result;
    } catch (e) {
      developer.log(
        'Failed to load auto-reply settings from Firestore: $e',
        name: 'FirebaseChatService',
      );
      return {};
    }
  }

  /// Logs an incoming notification and optional AI reply to Cloud Firestore.
  Future<void> logNotification({
    required String key,
    required String packageName,
    required String title,
    required String text,
    required int timestamp,
    String? replySent,
  }) async {
    try {
      final notifId = 'notif_${_fnv1aHex('$key|$timestamp')}';
      await _notificationsCollection.doc(notifId).set(
        {
          'key': key,
          'package': packageName,
          'title': title,
          'text': text,
          'timestamp': timestamp,
          'reply_sent': ?replySent,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      developer.log(
        'Failed to log notification to Firestore: $e',
        name: 'FirebaseChatService',
      );
    }
  }

  /// Deletes a contact's chat document and all its messages from Cloud Firestore.
  Future<bool> deletePerson(String personName) async {
    if (personName.trim().isEmpty) return false;
    try {
      final docId = chatDocId(personName);
      final chatRef = _chatsCollection.doc(docId);
      final messagesSnap = await chatRef.collection('messages').get();

      const chunkSize = 400;
      final docs = messagesSnap.docs;
      for (int i = 0; i < docs.length; i += chunkSize) {
        final chunk = docs.sublist(
          i,
          i + chunkSize > docs.length ? docs.length : i + chunkSize,
        );
        final batch = _firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await chatRef.delete();
      developer.log(
        'Deleted [$personName] and ${docs.length} messages from Firestore',
        name: 'FirebaseChatService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Failed to delete [$personName] from Firestore: $e',
        name: 'FirebaseChatService',
      );
      return false;
    }
  }
}
