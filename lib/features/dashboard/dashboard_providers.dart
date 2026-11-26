import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_ai_service.dart';
import '../../services/firebase_chat_service.dart';
import '../onboarding/onboarding_providers.dart';

final dashboardPlatformProvider =
    Provider((ref) => const MethodChannel('twiny/messages'));
final firebaseAiServiceProvider = Provider((ref) => FirebaseAiService());
final firebaseChatServiceProvider = Provider((ref) => FirebaseChatService());

final researchModeProvider = StateProvider<bool>((ref) => false);
final accessibilityEnabledProvider = StateProvider<bool>((ref) => false);
final notificationAccessEnabledProvider = StateProvider<bool>((ref) => false);
final isSyncingCloudProvider = StateProvider<bool>((ref) => false);
final currentViewProvider = StateProvider<String>((ref) => 'whatsapp');

final notificationsProvider = StateProvider<List<dynamic>>((ref) => []);
final appMessagesProvider = StateProvider<Map<String, List<dynamic>>>((ref) => {
      'whatsapp': [],
      'teams': [],
    });
final appCountsProvider = StateProvider<Map<String, int>>((ref) => {
      'whatsapp': 0,
      'teams': 0,
    });

final autoReplySettingsProvider =
    StateNotifierProvider<AutoReplySettingsNotifier, Map<String, bool>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final chatService = ref.watch(firebaseChatServiceProvider);
  return AutoReplySettingsNotifier(prefs, chatService);
});

class AutoReplySettingsNotifier extends StateNotifier<Map<String, bool>> {
  final SharedPreferences _prefs;
  final FirebaseChatService _chatService;
  static const String _key = 'auto_reply_settings';

  AutoReplySettingsNotifier(this._prefs, this._chatService) : super({}) {
    _load();
    _syncFromCloud();
  }

  void _load() {
    final String? json = _prefs.getString(_key);
    if (json != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(json);
        state = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
  }

  Future<void> _syncFromCloud() async {
    final cloudSettings = await _chatService.getAllAutoReplySettings();
    if (cloudSettings.isNotEmpty) {
      final merged = {...cloudSettings, ...state};
      state = merged;
      await _prefs.setString(_key, jsonEncode(merged));
    }
  }

  Future<void> toggle(String chatName, bool value) async {
    final newState = {...state, chatName: value};
    state = newState;
    await _prefs.setString(_key, jsonEncode(newState));
    await _chatService.setAutoReplyEnabled(chatName, value);
  }

  bool isEnabled(String chatName) => state[chatName] ?? false;
}

class DashboardNotifier extends StateNotifier<void> {
  final Ref ref;
  final MethodChannel _platform;
  Timer? _timer;

  DashboardNotifier(this.ref)
      : _platform = ref.read(dashboardPlatformProvider),
        super(null);

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollAll());
    _pollAll();
  }

  void stopPolling() {
    _timer?.cancel();
  }

  Future<void> _pollAll() async {
    await Future.wait([
      checkAccessibilityPermission(),
      checkNotificationPermission(),
      fetchResearchMode(),
      fetchCounts(),
      fetchNotifications(),
      fetchAllAppMessages(),
    ]);
  }

  Future<void> checkNotificationPermission() async {
    try {
      final bool enabled =
          await _platform.invokeMethod('isNotificationListenerEnabled');
      ref.read(notificationAccessEnabledProvider.notifier).state = enabled;
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    try {
      final String? json = await _platform.invokeMethod('getNotifications');
      if (json != null) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(const JsonDecoder().convert(json));
        final List<dynamic> list = data['notifications'] ?? [];
        ref.read(notificationsProvider.notifier).state = list.reversed.toList();
      }
    } catch (_) {}
  }

  Future<void> fetchResearchMode() async {
    try {
      final bool enabled =
          await _platform.invokeMethod('isResearchModeEnabled');
      ref.read(researchModeProvider.notifier).state = enabled;
    } catch (_) {}
  }

  Future<void> fetchCounts() async {
    try {
      final String? json = await _platform.invokeMethod('getAppCounts');
      if (json == null) return;
      final Map<String, dynamic> data = jsonDecode(json);
      final counts = ref.read(appCountsProvider);
      final newCounts = Map<String, int>.from(counts);
      for (final app in counts.keys) {
        newCounts[app] = data[app] as int? ?? 0;
      }
      ref.read(appCountsProvider.notifier).state = newCounts;
    } catch (_) {}
  }

  Future<void> fetchAllAppMessages() async {
    await Future.wait([
      _fetchMessagesForApp('whatsapp'),
      _fetchMessagesForApp('teams'),
    ]);
  }

  Future<void> _fetchMessagesForApp(String app) async {
    try {
      final String? json = await _platform.invokeMethod(
        'getMessagesForApp',
        {'app': app},
      );
      if (json == null) return;
      final Map<String, dynamic> data = jsonDecode(json);
      final List<dynamic> msgs = data['messages'] ?? [];
      final messages = ref.read(appMessagesProvider);
      final newMessages = Map<String, List<dynamic>>.from(messages);
      newMessages[app] = msgs.reversed.toList();
      ref.read(appMessagesProvider.notifier).state = newMessages;
    } catch (_) {}
  }

  Future<void> checkAccessibilityPermission() async {
    try {
      final bool enabled =
          await _platform.invokeMethod('isAccessibilityEnabled');
      ref.read(accessibilityEnabledProvider.notifier).state = enabled;
      if (!enabled && ref.read(researchModeProvider)) {
        ref.read(researchModeProvider.notifier).state = false;
      }
    } catch (_) {}
  }

  Future<void> toggleResearchMode(bool value) async {
    try {
      await _platform
          .invokeMethod(value ? 'enableResearchMode' : 'disableResearchMode');
      ref.read(researchModeProvider.notifier).state = value;
    } catch (_) {}
  }

  Future<void> clearMessagesForChat(String app, String chatName) async {
    try {
      final bool success =
          await _platform.invokeMethod('clearMessagesForChat', {
        'app': app,
        'chatName': chatName,
      });
      if (success) {
        await _fetchMessagesForApp(app);
      }
    } catch (_) {}
  }

  // ── Firebase Cloud Firestore & Firebase AI Actions ─────────────────────────

  Future<bool> uploadIndividualChat(
    String app,
    String chatName,
    List<dynamic> messages,
  ) async {
    final chatService = ref.read(firebaseChatServiceProvider);
    return chatService.uploadChatMessages(app, chatName, messages);
  }

  Future<bool> syncAllChatsToCloud() async {
    if (ref.read(isSyncingCloudProvider)) return false;
    ref.read(isSyncingCloudProvider.notifier).state = true;
    try {
      final chatService = ref.read(firebaseChatServiceProvider);
      final appMessages = ref.read(appMessagesProvider);
      final waOk = await chatService.syncAppMessages(
        'whatsapp',
        appMessages['whatsapp'] ?? [],
      );
      final teamsOk = await chatService.syncAppMessages(
        'teams',
        appMessages['teams'] ?? [],
      );
      return waOk && teamsOk;
    } finally {
      ref.read(isSyncingCloudProvider.notifier).state = false;
    }
  }

  Future<bool> deletePerson(String personName) async {
    final chatService = ref.read(firebaseChatServiceProvider);
    return chatService.deletePerson(personName);
  }

  Future<void> updateMessage(
    String chatName,
    String sender,
    String text, {
    String app = 'unknown',
  }) async {
    final chatService = ref.read(firebaseChatServiceProvider);
    await chatService.addMessage(
      chatName: chatName,
      sender: sender,
      text: text,
      app: app,
    );
  }

  Future<bool> brainSync(String chatName, String rulebook) async {
    final chatService = ref.read(firebaseChatServiceProvider);
    return chatService.saveBrainState(chatName, rulebook);
  }

  Future<List<String>?> getBrainSyncQuestions(String contextData) async {
    final aiService = ref.read(firebaseAiServiceProvider);
    return aiService.generateDiscoveryQuestions(contextData);
  }

  Future<String?> finalizeBrainSync(
    String originalIntent,
    String userAnswers,
  ) async {
    final aiService = ref.read(firebaseAiServiceProvider);
    return aiService.generateRulebook(
      originalIntent: originalIntent,
      userAnswers: userAnswers,
    );
  }

  Future<String?> generateSimulatedReply(
    String chatName,
    String incomingMessage,
  ) async {
    final aiService = ref.read(firebaseAiServiceProvider);
    final chatService = ref.read(firebaseChatServiceProvider);

    final brainState = await chatService.getBrainState(chatName);
    List<Map<String, dynamic>> history =
        await chatService.getRecentMessages(chatName, limit: 20);

    if (history.isEmpty) {
      final appMsgsMap = ref.read(appMessagesProvider);
      final allLocal = [
        ...appMsgsMap['whatsapp'] ?? [],
        ...appMsgsMap['teams'] ?? [],
      ];
      history = allLocal
          .whereType<Map>()
          .where((m) =>
              (m['chat_name'] as String? ?? '').toLowerCase() ==
              chatName.toLowerCase())
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }

    return aiService.generateReply(
      chatName: chatName,
      incomingMessage: incomingMessage,
      history: history,
      brainState: brainState,
    );
  }
}

final dashboardNotifierProvider = Provider((ref) => DashboardNotifier(ref));
