import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dashboard/dashboard_providers.dart';

class NotificationService {
  static const _channel = MethodChannel('twiny/messages');
  final ProviderContainer _container;

  NotificationService(this._container);

  void init() {
    _channel.setMethodCallHandler(_handleMethodCall);
    developer.log('NotificationService initialized', name: 'NotificationService');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final Map<dynamic, dynamic> data = call.arguments;
        final String key = (data['key'] as String?) ?? '';
        final String pkg = (data['package'] as String?) ?? '';
        final String title = (data['title'] as String?) ?? '';
        final String text = (data['text'] as String?) ?? '';
        final int timestamp = (data['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;

        developer.log(
          'Notification received ($pkg): $title - $text',
          name: 'NotificationService',
        );

        await _processAutoReply(
          key: key,
          packageName: pkg,
          chatName: title,
          message: text,
          timestamp: timestamp,
        );
        break;
      default:
        developer.log(
          'Unknown method called from Android: ${call.method}',
          name: 'NotificationService',
        );
    }
  }

  String _appKeyFromPackage(String pkg) {
    if (pkg.contains('whatsapp')) return 'whatsapp';
    if (pkg.contains('teams')) return 'teams';
    return 'unknown';
  }

  Future<void> _processAutoReply({
    required String key,
    required String packageName,
    required String chatName,
    required String message,
    required int timestamp,
  }) async {
    try {
      if (chatName.isEmpty || message.isEmpty) return;

      final chatService = _container.read(firebaseChatServiceProvider);
      final aiService = _container.read(firebaseAiServiceProvider);
      final appKey = _appKeyFromPackage(packageName);

      // Sync incoming notification to Cloud Firestore
      await chatService.logNotification(
        key: key,
        packageName: packageName,
        title: chatName,
        text: message,
        timestamp: timestamp,
      );

      // ── Layer 1: Per-Chat Auto-Reply Toggle ─────────────
      final isAutoEnabled = _container
          .read(autoReplySettingsProvider.notifier)
          .isEnabled(chatName);
      if (!isAutoEnabled) {
        developer.log(
          'Auto-reply disabled for [$chatName]. Skipping.',
          name: 'NotificationService',
        );
        return;
      }

      // ── Layer 2: Noise Filtering ────────────────────────
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('reacted to') ||
          lowerMsg.contains('typing...') ||
          message.trim().length < 2) {
        developer.log(
          'Interpreted notification as noise: "$message". Skipping.',
          name: 'NotificationService',
        );
        return;
      }

      // ── Layer 3: Context (Firestore + Local History & Brain State) ──
      final brainState = await chatService.getBrainState(chatName);
      List<Map<String, dynamic>> history =
          await chatService.getRecentMessages(chatName, limit: 20);

      if (history.isEmpty) {
        final appMsgsMap = _container.read(appMessagesProvider);
        final allLocal = [
          ...appMsgsMap['whatsapp'] ?? [],
          ...appMsgsMap['teams'] ?? [],
        ];
        final searchName = chatName.toLowerCase();
        history = allLocal
            .whereType<Map>()
            .where((m) {
              final histName = (m['chat_name'] as String? ?? '').toLowerCase();
              return histName.contains(searchName) ||
                  searchName.contains(histName);
            })
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      if (history.isEmpty && (brainState == null || brainState.isEmpty)) {
        developer.log(
          'No chat history or Brain State found for [$chatName]. Skipping to prevent hallucination.',
          name: 'NotificationService',
        );
        return;
      }

      // Store incoming message in Firestore chat history
      await chatService.addMessage(
        chatName: chatName,
        sender: 'other',
        text: message,
        app: appKey,
      );

      developer.log(
        'Generating Firebase AI reply for [$chatName]...',
        name: 'NotificationService',
      );
      final replyText = await aiService.generateReply(
        chatName: chatName,
        incomingMessage: message,
        history: history,
        brainState: brainState,
      );

      if (replyText != null && replyText.isNotEmpty) {
        developer.log(
          'Sending Firebase AI Reply: "$replyText" to [$chatName] (Key: $key)',
          name: 'NotificationService',
        );
        final sent = await _channel.invokeMethod('sendNotificationReply', {
          'key': key,
          'message': replyText,
        });

        if (sent == true) {
          await Future.wait([
            chatService.addMessage(
              chatName: chatName,
              sender: 'me',
              text: replyText,
              app: appKey,
            ),
            chatService.logNotification(
              key: key,
              packageName: packageName,
              title: chatName,
              text: message,
              timestamp: timestamp,
              replySent: replyText,
            ),
          ]);
        }
      } else {
        developer.log(
          'Firebase AI returned empty reply for [$chatName]. Skipping.',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log('Auto-reply failed: $e', name: 'NotificationService');
    }
  }
}
