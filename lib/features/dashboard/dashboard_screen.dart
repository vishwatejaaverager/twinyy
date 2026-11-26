import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/hybrid_ai_service.dart';
import 'dashboard_providers.dart';
import '../ondevice/on_device_model_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App tab config
// ─────────────────────────────────────────────────────────────────────────────

enum _BrainSyncStage { architect, legislator, activation }

class _AppTab {
  final String key; // matches MainActivity key
  final String label;
  final IconData icon;
  final Color color;

  const _AppTab({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _kAppTabs = [
  _AppTab(
    key: 'whatsapp',
    label: 'WhatsApp',
    icon: Icons.chat_rounded,
    color: Color(0xFF25D366),
  ),
  _AppTab(
    key: 'teams',
    label: 'Teams',
    icon: Icons.groups_rounded,
    color: Color(0xFF5B5FC7),
  ),
  _AppTab(
    key: 'simulation',
    label: 'Simulation',
    icon: Icons.psychology_rounded,
    color: Color(0xFF06D6A0),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class ResearchDashboard extends ConsumerStatefulWidget {
  const ResearchDashboard({super.key});

  @override
  ConsumerState<ResearchDashboard> createState() => _ResearchDashboardState();
}

class _ResearchDashboardState extends ConsumerState<ResearchDashboard> {
  bool _hasPromptedModelDownload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(dashboardNotifierProvider).startPolling();
      Permission.contacts.request();
      await ref.read(dashboardNotifierProvider).fetchOnDeviceAiStatus();
      _maybePromptForModelDownload();
    });
  }

  void _maybePromptForModelDownload() {
    if (!mounted || _hasPromptedModelDownload) return;
    final aiStatus = ref.read(onDeviceAiStatusProvider);
    if (aiStatus.status == OnDeviceAiStatus.downloadable) {
      _hasPromptedModelDownload = true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.download_for_offline_rounded,
                color: Color(0xFF06D6A0),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Download On-Device Model?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Gemini Nano v4 (On-Device AI) is not downloaded on this phone yet.\n\nDownload it now so Twiny can run local on-device scheduling, entity extraction, and auto-replies?',
            style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('LATER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06D6A0),
                foregroundColor: const Color(0xFF0D0D0D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 17),
              label: const Text(
                'DOWNLOAD NOW',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(dashboardNotifierProvider).downloadOnDeviceModel();
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    // We can stop polling if the dashboard is ever disposed (e.g., on logout)
    // ref.read(dashboardNotifierProvider).stopPolling();
    super.dispose();
  }

  // ── Accessibility ─────────────────────────────────────

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Accessibility Required'),
        content: const Text(
          'Enable the Twiny Accessibility Service in Android Settings to start capturing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(dashboardPlatformProvider)
                  .invokeMethod('openAccessibilitySettings');
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomIndex = ref.watch(bottomNavIndexProvider);
    final accessibilityEnabled = ref.watch(accessibilityEnabledProvider);
    final notificationAccessEnabled = ref.watch(
      notificationAccessEnabledProvider,
    );
    final currentView = ref.watch(currentViewProvider);
    final notifications = ref.watch(notificationsProvider);
    final appMessages = ref.watch(appMessagesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(bottomIndex),
      body: Column(
        children: [
          _buildOnDeviceAiBanner(),
          Expanded(
            child: switch (bottomIndex) {
              0 => const _SimulationView(),
              1 => const _BookingsView(),
              2 => _buildChannelsHub(
                accessibilityEnabled: accessibilityEnabled,
                notificationAccessEnabled: notificationAccessEnabled,
                currentView: currentView,
                appMessages: appMessages,
                notifications: notifications,
              ),
              _ => const OnDeviceModelScreen(),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        backgroundColor: const Color(0xFF141724),
        indicatorColor: const Color(0xFF7C3AED).withValues(alpha: 0.28),
        height: 64,
        onDestinationSelected: (idx) {
          ref.read(bottomNavIndexProvider.notifier).state = idx;
          if (idx == 1) {
            ref
                .read(dashboardNotifierProvider)
                .fetchBookings(seedIfEmpty: true);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(
              Icons.psychology_rounded,
              color: Color(0xFF06D6A0),
            ),
            label: 'Simulate',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF7C3AED),
            ),
            label: 'Bookings & DB',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub_rounded, color: Color(0xFF25D366)),
            label: 'WhatsApp & Teams',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory_rounded, color: Color(0xFF06D6A0)),
            label: 'On-Device',
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsHub({
    required bool accessibilityEnabled,
    required bool notificationAccessEnabled,
    required String currentView,
    required Map<String, List<dynamic>> appMessages,
    required List<dynamic> notifications,
  }) {
    final channelToggles = ref.watch(channelAutoReplyProvider);
    final waAuto = channelToggles['whatsapp'] ?? true;
    final teamsAuto = channelToggles['teams'] ?? true;
    final activeSubTab =
        (currentView == 'whatsapp' ||
            currentView == 'teams' ||
            currentView == 'notifications')
        ? currentView
        : 'whatsapp';

    return Column(
      children: [
        if (!accessibilityEnabled) _buildPermissionBanner(),
        if (!notificationAccessEnabled) _buildNotificationPermissionBanner(),
        // Master Auto-Reply Toggles for WhatsApp & Microsoft Teams
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHANNEL AUTO-REPLY MASTER SWITCHES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChannelMasterTile(
                      label: 'WhatsApp Reply',
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      enabled: waAuto,
                      onChanged: (v) => ref
                          .read(channelAutoReplyProvider.notifier)
                          .toggleChannel('whatsapp', v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildChannelMasterTile(
                      label: 'Teams Reply',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF5B5FC7),
                      enabled: teamsAuto,
                      onChanged: (v) => ref
                          .read(channelAutoReplyProvider.notifier)
                          .toggleChannel('teams', v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildControlBar(),
        _buildChannelsSubSwitcher(activeSubTab),
        Expanded(
          child: activeSubTab == 'whatsapp'
              ? _AppMessageList(
                  tab: _kAppTabs[0],
                  messages: appMessages['whatsapp'] ?? [],
                )
              : activeSubTab == 'teams'
              ? _AppMessageList(
                  tab: _kAppTabs[1],
                  messages: appMessages['teams'] ?? [],
                )
              : _NotificationList(notifications: notifications),
        ),
      ],
    );
  }

  Widget _buildChannelMasterTile({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? color.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? color.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: enabled ? color : Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: enabled ? Colors.white : Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: enabled,
              activeThumbColor: color,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsSubSwitcher(String activeSubTab) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: 'whatsapp',
            label: Text('WhatsApp Chats', style: TextStyle(fontSize: 11)),
            icon: Icon(Icons.chat, size: 15),
          ),
          ButtonSegment(
            value: 'teams',
            label: Text('Teams Chats', style: TextStyle(fontSize: 11)),
            icon: Icon(Icons.groups_rounded, size: 15),
          ),
          ButtonSegment(
            value: 'notifications',
            label: Text('Live Alerts', style: TextStyle(fontSize: 11)),
            icon: Icon(Icons.notifications, size: 15),
          ),
        ],
        selected: {activeSubTab},
        onSelectionChanged: (newSelection) {
          ref.read(currentViewProvider.notifier).state = newSelection.first;
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A2E),
          selectedBackgroundColor: const Color(0xFF7C3AED),
          selectedForegroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildNotificationPermissionBanner() {
    return Container(
      color: Colors.blue.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.notification_important,
            color: Colors.blue,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Notification Access disabled',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(dashboardPlatformProvider)
                .invokeMethod('openNotificationListenerSettings'),
            child: const Text('ENABLE', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(int bottomIndex) {
    final subtitle = switch (bottomIndex) {
      0 => 'Simulation Lab',
      1 => 'Firestore Bookings & Schedule',
      _ => 'WhatsApp & Teams Channels',
    };
    final isSyncing = ref.watch(isSyncingCloudProvider);
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      title: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Image.asset('assets/twiny.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Twiny',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: isSyncing
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF06D6A0),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Sync all chats to Firebase Cloud',
                  icon: const Icon(
                    Icons.cloud_sync_rounded,
                    color: Color(0xFF06D6A0),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref
                        .read(dashboardNotifierProvider)
                        .syncAllChatsToCloud();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'All chats synced to Firebase Cloud!'
                              : 'Some chats failed to sync to Firebase Cloud',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOnDeviceAiBanner() {
    final aiStatus = ref.watch(onDeviceAiStatusProvider);
    final downloadProgress = ref.watch(modelDownloadProgressProvider);

    final (
      IconData icon,
      Color color,
      String label,
      bool showDownloadBtn,
    ) = switch (aiStatus.status) {
      OnDeviceAiStatus.available => (
        Icons.memory_rounded,
        const Color(0xFF06D6A0),
        'On-Device Ready: ${aiStatus.modelName}',
        false,
      ),
      OnDeviceAiStatus.downloadable => (
        Icons.download_for_offline_outlined,
        const Color(0xFF7C3AED),
        'Gemini Nano v4 not downloaded — Tap DOWNLOAD to install',
        true,
      ),
      OnDeviceAiStatus.downloading => (
        Icons.downloading_rounded,
        const Color(0xFF3BFFFF),
        _formatDownloadLabel(downloadProgress),
        false,
      ),
      OnDeviceAiStatus.firebaseNotConfigured => (
        Icons.cloud_off_rounded,
        Colors.amber,
        'Add android/app/google-services.json to enable Firebase On-Device AI',
        false,
      ),
      OnDeviceAiStatus.unavailable => (
        Icons.error_outline_rounded,
        Colors.redAccent,
        'On-Device Gemini Nano Error / Unsupported: ${aiStatus.modelName}',
        false,
      ),
      OnDeviceAiStatus.unknown => (
        Icons.auto_awesome,
        Colors.grey,
        'Checking Firebase On-Device AI...',
        false,
      ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showDownloadBtn)
            TextButton(
              onPressed: () =>
                  ref.read(dashboardNotifierProvider).downloadOnDeviceModel(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'DOWNLOAD',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (aiStatus.status == OnDeviceAiStatus.downloading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh, color: color, size: 16),
              tooltip: 'Refresh On-Device AI status',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  ref.read(dashboardNotifierProvider).fetchOnDeviceAiStatus(),
            ),
        ],
      ),
    );
  }

  String _formatDownloadLabel(Map<String, dynamic>? progress) {
    if (progress == null) return 'Downloading Gemini Nano...';
    final downloaded = (progress['bytesDownloaded'] as num?)?.toDouble() ?? 0;
    final total = (progress['totalBytes'] as num?)?.toDouble() ?? 0;
    if (total > 0) {
      final pct = ((downloaded / total) * 100).clamp(0, 100).toStringAsFixed(0);
      return 'Downloading Gemini Nano... $pct%';
    }
    return 'Downloading Gemini Nano...';
  }

  Widget _buildPermissionBanner() {
    return Container(
      color: Colors.orange.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Accessibility Service disabled',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(dashboardPlatformProvider)
                .invokeMethod('openAccessibilitySettings'),
            child: const Text('ENABLE', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    final researchMode = ref.watch(researchModeProvider);
    final accessibilityEnabled = ref.watch(accessibilityEnabledProvider);
    final appCounts = ref.watch(appCountsProvider);

    final totalCount = appCounts.values.fold(0, (a, b) => a + b);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Status dot
          AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: researchMode ? const Color(0xFF06D6A0) : Colors.grey,
                  boxShadow: researchMode
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF06D6A0,
                            ).withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              )
              .animate(target: researchMode ? 1 : 0)
              .shimmer(duration: 2.seconds)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  researchMode ? 'Capturing...' : 'Capture Paused',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: researchMode ? const Color(0xFF06D6A0) : Colors.grey,
                  ),
                ),
                Text(
                  '$totalCount messages collected',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniCounter(tab: _kAppTabs[0], count: appCounts['whatsapp'] ?? 0),
          const SizedBox(width: 8),
          _MiniCounter(tab: _kAppTabs[1], count: appCounts['teams'] ?? 0),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: researchMode,
            onChanged: (value) async {
              if (value && !accessibilityEnabled) {
                _showPermissionDialog();
                return;
              }
              if (value) await Permission.contacts.request();
              await ref
                  .read(dashboardNotifierProvider)
                  .toggleResearchMode(value);
            },
            activeTrackColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-app message list
// ─────────────────────────────────────────────────────────────────────────────

class _AppMessageList extends StatelessWidget {
  final _AppTab tab;
  final List<dynamic> messages;

  const _AppMessageList({required this.tab, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 52, color: tab.color.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No ${tab.label} messages yet',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enable capture and open the app',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Group by chat_name
    final Map<String, List<dynamic>> grouped = {};
    for (final msg in messages) {
      final chat = msg['chat_name'] as String? ?? 'Unknown';
      grouped.putIfAbsent(chat, () => []).add(msg);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final chatName = grouped.keys.elementAt(index);
        final chatMsgs = grouped[chatName]!;
        return _ConversationCard(
          tab: tab,
          chatName: chatName,
          messages: chatMsgs,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation card
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationCard extends ConsumerStatefulWidget {
  final _AppTab tab;
  final String chatName;
  final List<dynamic> messages;

  const _ConversationCard({
    required this.tab,
    required this.chatName,
    required this.messages,
  });

  @override
  ConsumerState<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends ConsumerState<_ConversationCard> {
  bool _expanded = false;
  bool _isUploading = false;

  Future<void> _uploadIndividualChat() async {
    setState(() => _isUploading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final success = await ref
          .read(dashboardNotifierProvider)
          .uploadIndividualChat(
            widget.tab.key,
            widget.chatName,
            widget.messages,
          );

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Chat synced to Firebase Cloud!')),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Firebase Cloud sync failed')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Upload Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearIndividualDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clear or Delete Chat?'),
        content: Text('Would you like to clear local messages for "${widget.chatName}" or delete all data from Firebase Cloud?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(dashboardNotifierProvider)
                  .clearMessagesForChat(widget.tab.key, widget.chatName);
            },
            child: const Text(
              'CLEAR LOCAL',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(dashboardNotifierProvider)
                  .deletePerson(widget.chatName);
              if (success) {
                ref
                    .read(dashboardNotifierProvider)
                    .clearMessagesForChat(widget.tab.key, widget.chatName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deleted from Firebase Cloud successfully')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete from Firebase Cloud')),
                  );
                }
              }
            },
            child: const Text('DELETE CLOUD', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showBrainSyncBottomSheet(
    BuildContext context,
    String chatName, {
    VoidCallback? onActivated,
  }) {
    if (!mounted) return;
    showBrainSyncModal(
      context: context,
      ref: ref,
      chatName: chatName,
      onActivated: onActivated,
    );
  }

  Widget _buildStageContent(
    BuildContext context,
    _BrainSyncStage stage,
    TextEditingController architectController,
    List<String> questions,
    Map<int, TextEditingController> answerControllers,
    String rulebook,
    bool isLoading,
    void Function(_BrainSyncStage, [List<String>?, String?]) onNext,
    void Function(bool) setLoading,
    void Function(String?) setError,
    String chatName,
    dynamic dashNotifier,
  ) {
    if (stage == _BrainSyncStage.architect) {
      return Column(
        key: const ValueKey('architect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Architect: Discovery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Describe the current situation (e.g. "I am in a meeting, pretend I am finishing the demo").',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: architectController,
            maxLines: 3,
            autofocus: true,
            decoration: _inputDecoration('e.g. I am going to a cafe...'),
          ),
          const SizedBox(height: 24),
          _actionButton(
            'START DISCOVERY',
            isLoading,
            () async {
              final text = architectController.text.trim();
              if (text.isEmpty) return;
              setLoading(true);
              final fetchedQuestions = await dashNotifier.getBrainSyncQuestions(text);
              setLoading(false);
              if (fetchedQuestions != null) {
                onNext(_BrainSyncStage.legislator, fetchedQuestions);
              } else {
                setError('Failed to start discovery. Check Firebase AI setup & connection.');
              }
            },
          ),
        ],
      );
    } else if (stage == _BrainSyncStage.legislator) {
      return Column(
        key: const ValueKey('legislator'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Legislator: Rules Generation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Answer these discovery questions to tailor your agent response style.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...List.generate(questions.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q: ${questions[index]}',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: answerControllers[index],
                    decoration: _inputDecoration('Your answer...'),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          _actionButton(
            'GENERATE RULEBOOK',
            isLoading,
            () async {
              String combinedAnswers = '';
              for (int i = 0; i < questions.length; i++) {
                combinedAnswers += 'Q: ${questions[i]} A: ${answerControllers[i]?.text}\n';
              }
              setLoading(true);
              final fetchedRulebook = await dashNotifier.finalizeBrainSync(
                    architectController.text.trim(),
                    combinedAnswers,
                  );
              setLoading(false);
              if (fetchedRulebook != null) {
                onNext(_BrainSyncStage.activation, null, fetchedRulebook);
              } else {
                setError('Failed to generate rules.');
              }
            },
          ),
        ],
      );
    } else {
      return Column(
        key: const ValueKey('activation'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activation: Confirm Brain State',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: rulebook,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white70, fontSize: 13),
                  h1: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Color(0xFF7C3AED)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _actionButton(
            'ACTIVATE AGENT',
            isLoading,
            () async {
              setLoading(true);
              final success = await dashNotifier.brainSync(chatName, rulebook);
              setLoading(false);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manage Mode Activated'), backgroundColor: Colors.green),
                );
              } else {
                setError('Activation failed.');
              }
            },
          ),
        ],
      );
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1)),
    );
  }

  Widget _actionButton(String label, bool isLoading, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.messages.last;
    final previewText = preview['text'] as String? ?? '';
    final isContact = preview['contact_match'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isContact
              ? widget.tab.color.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          // Header row (always visible)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.tab.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.chatName.isNotEmpty
                            ? widget.chatName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: widget.tab.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.chatName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Auto Reply Toggle
                            Column(
                              children: [
                                const Text(
                                  'Auto',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.6,
                                  child: Switch(
                                    value: ref.watch(autoReplySettingsProvider)[widget.chatName] ?? false,
                                    onChanged: (val) {
                                      ref
                                          .read(
                                            autoReplySettingsProvider.notifier,
                                          )
                                          .toggle(widget.chatName, val);
                                    },
                                    activeThumbColor: const Color(0xFF06D6A0),
                                  ),
                                ),
                              ],
                            ),
                            // Brain Sync Icon
                            IconButton(
                              icon: const Icon(
                                Icons.psychology_outlined,
                                size: 20,
                                color: Color(0xFF7C3AED),
                              ),
                              tooltip: 'Brain Sync',
                              onPressed: () => _showBrainSyncBottomSheet(
                                context,
                                widget.chatName,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (isContact)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF06D6A0,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '✓ contact',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF06D6A0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          previewText,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Count + actions
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              if (_isUploading)
                                const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 22,
                                    color: Colors.blueAccent,
                                  ),
                                  tooltip: 'Upload this chat',
                                  onPressed: _uploadIndividualChat,
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 22,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Clear this chat',
                                onPressed: _clearIndividualDialog,
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.tab.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.messages.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.tab.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            ...(() {
              final List<dynamic> sorted = List.from(widget.messages);
              sorted.sort((a, b) {
                final int tsA = a['timestamp'] ?? 0;
                final int tsB = b['timestamp'] ?? 0;
                return tsA.compareTo(tsB);
              });
              return sorted;
            }()).map(
              (msg) =>
                  _MessageBubbleRow(msg: msg, accentColor: widget.tab.color),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

void showBrainSyncModal({
  required BuildContext context,
  required WidgetRef ref,
  required String chatName,
  VoidCallback? onActivated,
}) {
  final dashNotifier = ref.read(dashboardNotifierProvider);
  _BrainSyncStage stage = _BrainSyncStage.architect;
  final architectController = TextEditingController();
  List<String> questions = [];
  final Map<int, TextEditingController> answerControllers = {};
  String rulebook = '';
  bool isLoading = false;
  String? errorMessage;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (modalContext, setState) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF7C3AED), width: 2)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage == _BrainSyncStage.architect
                              ? 'Stage 1: The Architect'
                              : stage == _BrainSyncStage.legislator
                              ? 'Stage 2: The Legislator'
                              : 'Stage 3: Activation',
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          chatName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: 800.ms,
                  switchInCurve: Curves.easeOutBack,
                  child: _buildBrainSyncStageContent(
                    modalContext,
                    stage,
                    architectController,
                    questions,
                    answerControllers,
                    rulebook,
                    isLoading,
                    (newStage, [newQuestions, newRulebook]) {
                      setState(() {
                        stage = newStage;
                        if (newQuestions != null) {
                          questions = newQuestions;
                          for (final c in answerControllers.values) {
                            c.dispose();
                          }
                          answerControllers.clear();
                          for (int i = 0; i < questions.length; i++) {
                            answerControllers[i] = TextEditingController();
                          }
                        }
                        if (newRulebook != null) rulebook = newRulebook;
                        errorMessage = null;
                      });
                    },
                    (loading) => setState(() => isLoading = loading),
                    (err) => setState(() => errorMessage = err),
                    chatName,
                    dashNotifier,
                    onActivated,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    architectController.dispose();
    for (final c in answerControllers.values) {
      c.dispose();
    }
  });
}

Widget _buildBrainSyncStageContent(
  BuildContext context,
  _BrainSyncStage stage,
  TextEditingController architectController,
  List<String> questions,
  Map<int, TextEditingController> answerControllers,
  String rulebook,
  bool isLoading,
  void Function(_BrainSyncStage, [List<String>?, String?]) onNext,
  void Function(bool) setLoading,
  void Function(String?) setError,
  String chatName,
  DashboardNotifier dashNotifier,
  VoidCallback? onActivated,
) {
  if (stage == _BrainSyncStage.architect) {
    return Column(
      key: const ValueKey('architect'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Architect: Discovery',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'Describe your scheduling & booking context (e.g. "I offer 30-min consultations Mon-Fri 10am-6pm, \$50/session").',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: architectController,
          maxLines: 3,
          autofocus: true,
          decoration: _brainSyncInputDecoration(
            'e.g. Haircut & Beard studio open Tue-Sun 11am-8pm...',
          ),
        ),
        const SizedBox(height: 24),
        _brainSyncActionButton(
          'START DISCOVERY (GEMINI NANO)',
          isLoading,
          () async {
            final text = architectController.text.trim();
            if (text.isEmpty) return;
            setLoading(true);
            try {
              final fetchedQuestions = await dashNotifier.getBrainSyncQuestions(
                text,
              );
              setLoading(false);
              onNext(_BrainSyncStage.legislator, fetchedQuestions);
            } catch (e) {
              setLoading(false);
              setError('$e');
            }
          },
        ),
      ],
    );
  } else if (stage == _BrainSyncStage.legislator) {
    return Column(
      key: const ValueKey('legislator'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Legislator: Rules Generation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'Answer these discovery questions to tailor your agent response style.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...List.generate(questions.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q: ${questions[index]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: answerControllers[index],
                  decoration: _brainSyncInputDecoration('Your answer...'),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        _brainSyncActionButton('GENERATE RULEBOOK', isLoading, () async {
          String combinedAnswers = '';
          for (int i = 0; i < questions.length; i++) {
            combinedAnswers +=
                'Q: ${questions[i]} A: ${answerControllers[i]?.text}\n';
          }
          setLoading(true);
          try {
            final fetchedRulebook = await dashNotifier.finalizeBrainSync(
              architectController.text.trim(),
              combinedAnswers,
            );
            setLoading(false);
            onNext(_BrainSyncStage.activation, null, fetchedRulebook);
          } catch (e) {
            setLoading(false);
            setError('$e');
          }
        }),
      ],
    );
  } else {
    return Column(
      key: const ValueKey('activation'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activation: Confirm Brain State',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: rulebook,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white70, fontSize: 13),
                h1: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                h2: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                listBullet: const TextStyle(color: Color(0xFF7C3AED)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _brainSyncActionButton('ACTIVATE AGENT', isLoading, () async {
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          setLoading(true);
          final success = await dashNotifier.brainSync(chatName, rulebook);
          setLoading(false);
          if (success) {
            onActivated?.call();
            navigator.pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text('Brain Sync Rulebook activated for $chatName'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            setError('Activation failed.');
          }
        }),
      ],
    );
  }
}

InputDecoration _brainSyncInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1),
    ),
  );
}

Widget _brainSyncActionButton(
  String label,
  bool isLoading,
  VoidCallback onPressed,
) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual message bubble row
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubbleRow extends StatelessWidget {
  final dynamic msg;
  final Color accentColor;

  const _MessageBubbleRow({required this.msg, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final bool isMe = (msg['sender'] as String?) == 'me';
    final text = msg['text'] as String? ?? '';
    final source = msg['source'] as String?;
    final ts = msg['timestamp'];
    final time = ts != null ? _formatTime((ts as int) * 1000) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: Icon(Icons.person, size: 14, color: accentColor),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isMe ? 12 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 12),
                ),
                border: Border.all(
                  color: isMe
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(text, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (source != null && source.isNotEmpty) ...[
                        Text(
                          source.startsWith('ON_DEVICE')
                              ? '⚡ $source'
                              : '☁️ $source',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: source.startsWith('ON_DEVICE')
                                ? const Color(0xFF06D6A0)
                                : Colors.lightBlueAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              child: const Icon(
                Icons.person,
                size: 14,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification List
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final List<dynamic> notifications;

  const _NotificationList({required this.notifications});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 52, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Teams notifications yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _NotificationTile(note: notifications[index]);
      },
    );
  }
}

class _NotificationTile extends ConsumerStatefulWidget {
  final dynamic note;
  const _NotificationTile({required this.note});

  @override
  ConsumerState<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends ConsumerState<_NotificationTile> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final key = widget.note['key'];
      final success = await ref.read(dashboardPlatformProvider).invokeMethod(
        'sendNotificationReply',
        {'key': key, 'message': text},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success == true
                  ? 'Reply sent!'
                  : 'Failed to send reply (Notification might be gone)',
            ),
          ),
        );
        if (success == true) {
          _controller.clear();
          // Sync manual reply to server
          ref
              .read(dashboardNotifierProvider)
              .updateMessage(
                widget.note['title'] as String? ?? 'Unknown',
                'me',
                text,
              );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.note['title'] as String? ?? '';
    final body = widget.note['text'] as String? ?? '';
    final ts = widget.note['timestamp'] as int? ?? 0;
    final time = DateTime.fromMillisecondsSinceEpoch(
      ts,
    ).toLocal().toString().split('.').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                size: 16,
                color: Color(0xFF6264A7),
              ),
              const SizedBox(width: 8),
              const Text(
                'Teams',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type a reply...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _sending ? null : _sendReply,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Color(0xFF7C3AED)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini counter badge (control bar)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniCounter extends StatelessWidget {
  final _AppTab tab;
  final int count;

  const _MiniCounter({required this.tab, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${tab.label}: $count messages',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 14, color: tab.color),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              color: tab.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulation Environment (WhatsApp / Teams + Booking Rulebook Sandbox)
// ─────────────────────────────────────────────────────────────────────────────

class _SimScenario {
  final String label;
  final String message;
  final bool isNoise;

  const _SimScenario({
    required this.label,
    required this.message,
    this.isNoise = false,
  });
}

const List<_SimScenario> _kSimScenarios = [
  _SimScenario(
    label: '📅 Book tomorrow 4pm',
    message: 'Hey! Can I book an appointment tomorrow at 4:00 PM?',
  ),
  _SimScenario(
    label: '🕒 Check availability',
    message: 'What slots do you have open this Thursday or Friday afternoon?',
  ),
  _SimScenario(
    label: '🔄 Reschedule slot',
    message:
        'Something came up — can we reschedule my booking to tomorrow at 5:00 PM?',
  ),
  _SimScenario(
    label: '❌ Cancel booking',
    message: 'Hi, please cancel my upcoming booking.',
  ),
  _SimScenario(
    label: '💰 Pricing & duration',
    message: 'How much do you charge for a session and how long does it take?',
  ),
  _SimScenario(
    label: '🔇 Noise: typing...',
    message: 'typing...',
    isNoise: true,
  ),
  _SimScenario(
    label: '❤️ Noise: Reaction',
    message: 'Reacted ❤️ to "See you at 4 PM"',
    isNoise: true,
  ),
];

class _SimulationView extends ConsumerStatefulWidget {
  const _SimulationView();

  @override
  ConsumerState<_SimulationView> createState() => _SimulationViewState();
}

class _SimulationViewState extends ConsumerState<_SimulationView> {
  final List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _chatNameController = TextEditingController(text: 'Alex Rivera');
  final _scrollController = ScrollController();

  String _selectedPlatform = 'whatsapp'; // 'whatsapp' | 'teams'
  String _activeRulebook = '';
  bool _showRulebookPanel = false;
  bool _enforceAutoReplyToggle = false;
  bool _alsoLogToNotificationsTab = true;
  bool _isLoading = false;
  Map<String, dynamic>? _lastTrace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRulebookForCurrentContact();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color get _platformColor => _selectedPlatform == 'whatsapp'
      ? const Color(0xFF25D366)
      : const Color(0xFF5B5FC7);

  String get _platformLabel =>
      _selectedPlatform == 'whatsapp' ? 'WhatsApp' : 'Teams';

  Future<void> _loadRulebookForCurrentContact() async {
    final chatName = _chatNameController.text.trim();
    if (chatName.isEmpty) return;
    final hybridAi = ref.read(hybridAiServiceProvider);
    final loaded = await hybridAi.getBrainRulebook(chatName);
    if (mounted) {
      setState(() => _activeRulebook = loaded);
    }
  }

  void _openBrainSyncForCurrentContact() {
    final targetName = _chatNameController.text.trim().isEmpty
        ? 'Customer'
        : _chatNameController.text.trim();
    showBrainSyncModal(
      context: context,
      ref: ref,
      chatName: targetName,
      onActivated: _loadRulebookForCurrentContact,
    );
  }

  void _addMessage({
    required String text,
    required String sender, // 'customer' | 'me' | 'system'
    String? source,
    int? latencyMs,
  }) {
    setState(() {
      _messages.add({
        'sender': sender,
        'text': text,
        'source': ?source,
        'latencyMs': ?latencyMs,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _simulateIncomingMessage([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    final chatName = _chatNameController.text.trim();
    if (text.isEmpty || chatName.isEmpty || _isLoading) return;

    if (presetText == null) {
      _messageController.clear();
    }

    // 1. Add incoming customer message (left bubble)
    _addMessage(text: text, sender: 'customer');

    final hybridAi = ref.read(hybridAiServiceProvider);

    // Send directly to on-device LLM.
    setState(() => _isLoading = true);
    final sw = Stopwatch()..start();
    try {
      final reply = await ref
          .read(dashboardNotifierProvider)
          .generateSimulatedReply(chatName, text);

      if (reply != null && reply.isNotEmpty) {
        _addMessage(reply, false);
      } else {
        _addMessage('No reply from Firebase AI', false);
      }
    } catch (e) {
      _addMessage('Firebase AI error: $e', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _knownContactNames() {
    final appMessages = ref.watch(appMessagesProvider);
    final all = [
      ...(appMessages['whatsapp'] ?? []),
      ...(appMessages['teams'] ?? []),
    ];
    final names = <String>{'Alex Rivera'};
    for (final m in all) {
      final name = (m['chat_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSimulatorControlPanel(),
        if (_showRulebookPanel) _buildRulebookDrawer(),
        if (_lastTrace != null) _buildPipelineTraceStrip(),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    if (msg['sender'] == 'system') {
                      return _buildSystemNoticeRow(
                        msg['text'] as String? ?? '',
                      );
                    }
                    return _MessageBubbleRow(
                      msg: msg,
                      accentColor: _platformColor,
                    );
                  },
                ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF06D6A0),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Twiny (Gemini Nano) is drafting $_platformLabel reply...',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF06D6A0),
                  ),
                ),
              ],
            ),
          ),
        _buildScenarioChipsBar(),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildSimulatorControlPanel() {
    final chatName = _chatNameController.text.trim();
    final isAutoOn = ref.watch(autoReplySettingsProvider)[chatName] ?? false;
    final hasRulebook = _activeRulebook.trim().isNotEmpty;
    final contacts = _knownContactNames();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _selectedPlatform = _selectedPlatform == 'whatsapp'
                        ? 'teams'
                        : 'whatsapp';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _platformColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _platformColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedPlatform == 'whatsapp'
                            ? Icons.chat_rounded
                            : Icons.groups_rounded,
                        size: 14,
                        color: _platformColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _platformLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _platformColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _chatNameController,
                  onChanged: (_) => _loadRulebookForCurrentContact(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Customer Name',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Auto',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Transform.scale(
                    scale: 0.65,
                    child: Switch(
                      value: isAutoOn,
                      activeThumbColor: const Color(0xFF06D6A0),
                      onChanged: (val) {
                        if (chatName.isNotEmpty) {
                          ref
                              .read(autoReplySettingsProvider.notifier)
                              .toggle(chatName, val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.psychology_rounded,
                  size: 20,
                  color: Color(0xFF7C3AED),
                ),
                tooltip: 'Run Brain Sync for this contact',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  final targetName = chatName.isEmpty
                      ? 'Alex Rivera'
                      : chatName;
                  showBrainSyncModal(
                    context: context,
                    ref: ref,
                    chatName: targetName,
                    onActivated: _loadRulebookForCurrentContact,
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 19,
                  color: Colors.grey,
                ),
                tooltip: 'Clear simulation chat',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _lastTrace = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      setState(() => _showRulebookPanel = !_showRulebookPanel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasRulebook
                          ? const Color(0xFF06D6A0).withValues(alpha: 0.14)
                          : Colors.orange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasRulebook
                            ? const Color(0xFF06D6A0).withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasRulebook
                              ? Icons.rule_folder_rounded
                              : Icons.info_outline_rounded,
                          size: 13,
                          color: hasRulebook
                              ? const Color(0xFF06D6A0)
                              : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasRulebook
                              ? 'Rulebook Active (View)'
                              : 'No Rulebook (Using Default)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasRulebook
                                ? const Color(0xFF06D6A0)
                                : Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _showRulebookPanel
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 14,
                          color: hasRulebook
                              ? const Color(0xFF06D6A0)
                              : Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openBrainSyncForCurrentContact,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          size: 13,
                          color: Color(0xFF7C3AED),
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Generate Rules with LLM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text(
                    'Strict Auto-Toggle Gate',
                    style: TextStyle(fontSize: 10),
                  ),
                  selected: _enforceAutoReplyToggle,
                  onSelected: (v) =>
                      setState(() => _enforceAutoReplyToggle = v),
                  visualDensity: VisualDensity.compact,
                  selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text(
                    'Log to Notifications Tab',
                    style: TextStyle(fontSize: 10),
                  ),
                  selected: _alsoLogToNotificationsTab,
                  onSelected: (v) =>
                      setState(() => _alsoLogToNotificationsTab = v),
                  visualDensity: VisualDensity.compact,
                  selectedColor: const Color(
                    0xFF06D6A0,
                  ).withValues(alpha: 0.25),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
                if (contacts.length > 1) ...[
                  const SizedBox(width: 8),
                  ...contacts.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(c, style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                        onPressed: () {
                          _chatNameController.text = c;
                          _loadRulebookForCurrentContact();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulebookDrawer() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 165),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: _activeRulebook.trim().isEmpty
          ? Row(
              children: [
                const Expanded(
                  child: Text(
                    'No Brain Sync rulebook saved for this contact yet. Run Brain Sync (🧠) to generate rules with the LLM.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _openBrainSyncForCurrentContact,
                  child: const Text(
                    'BRAIN SYNC',
                    style: TextStyle(color: Color(0xFF06D6A0), fontSize: 11),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: MarkdownBody(
                data: _activeRulebook,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white70, fontSize: 12),
                  h1: const TextStyle(
                    color: Color(0xFF06D6A0),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPipelineTraceStrip() {
    final trace = _lastTrace!;
    final isBlocked =
        trace['noise'] == 'BLOCKED' ||
        (trace['autoToggle'] as String).contains('Blocked');
    final accent = isBlocked ? Colors.orangeAccent : const Color(0xFF06D6A0);
    final intent = trace['intent'] as String? ?? 'N/A';
    final seq = trace['sequence'] as String? ?? '';
    final dbRes = trace['dbResult'] as String? ?? 'NONE';
    final dumpJson = trace['contextDumpJson'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBlocked ? Icons.shield_outlined : Icons.account_tree_rounded,
                size: 13,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isBlocked
                      ? 'Guardrail: Noise[${trace['noise']}] → Auto[${trace['autoToggle']}] → ${trace['status']}'
                      : 'Stage 1 [$intent]: $seq',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: accent,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dumpJson != null && dumpJson.isNotEmpty && dumpJson != '{}')
                InkWell(
                  onTap: () => _showContextDumpModal(dumpJson),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'VIEW DB DUMP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!isBlocked) ...[
            const SizedBox(height: 2),
            Text(
              'Stage 2 [Firestore DB]: $dbRes  •  Stage 3 [Firebase AI]: ${trace['status']}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showContextDumpModal(String dumpJson) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stage 2 → Stage 3 Firebase AI Data Dump',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF06D6A0),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Text(
              'Exact matched entities & Firestore DB state dumped into Firebase AI:',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    dumpJson,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemNoticeRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science_outlined,
              size: 54,
              color: _platformColor.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              '$_platformLabel Auto-Reply Simulator',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Simulate incoming customer messages on the left and watch Twiny (On-Device Gemini Nano) reply on the right using your Brain Sync booking rules.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_activeRulebook.isEmpty)
              OutlinedButton.icon(
                onPressed: _openBrainSyncForCurrentContact,
                icon: const Icon(
                  Icons.psychology_rounded,
                  size: 16,
                  color: Color(0xFF06D6A0),
                ),
                label: const Text(
                  'Configure Booking Rules (Brain Sync LLM)',
                  style: TextStyle(
                    color: Color(0xFF06D6A0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF06D6A0)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioChipsBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kSimScenarios.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final s = _kSimScenarios[index];
          return ActionChip(
            label: Text(
              s.label,
              style: TextStyle(
                fontSize: 11,
                color: s.isNoise ? Colors.orangeAccent : Colors.white,
              ),
            ),
            visualDensity: VisualDensity.compact,
            backgroundColor: s.isNoise
                ? Colors.orange.withValues(alpha: 0.12)
                : const Color(0xFF1A1A2E),
            side: BorderSide(
              color: s.isNoise
                  ? Colors.orange.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            onPressed: _isLoading
                ? null
                : () => _simulateIncomingMessage(s.message),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _simulateIncomingMessage(),
              decoration: InputDecoration(
                hintText:
                    'Simulate incoming $_platformLabel message from customer...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _platformColor,
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 19,
              ),
              tooltip: 'Send simulated customer message',
              onPressed: _isLoading ? null : () => _simulateIncomingMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookings & Scheduling Manager View (Firebase Firestore + Local Mirror)
// ─────────────────────────────────────────────────────────────────────────────

class _BookingsView extends ConsumerStatefulWidget {
  const _BookingsView();

  @override
  ConsumerState<_BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends ConsumerState<_BookingsView> {
  static const List<String> _kStandardSlots = [
    '10:00',
    '11:00',
    '12:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  late String _selectedScheduleDate;

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _selectedScheduleDate = _fmtDate(
      DateTime.now().add(const Duration(days: 1)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardNotifierProvider).fetchBookings(seedIfEmpty: true);
      ref
          .read(dashboardNotifierProvider)
          .fetchDaySchedule(_selectedScheduleDate);
    });
  }

  void _showFirestoreSchemaModal() {
    final daySchedule = ref.read(dayScheduleProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Normalized Firestore Schema (v2.0)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF06D6A0),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Multi-collection workspace hierarchy under workspaces/ws_default:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141724),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const SelectableText(
                  '''workspaces/{workspaceId}
 ├── services/{serviceId}
 │    └── id, name, category, durationMins, bufferAfterMins, price, currency, keywords[]
 ├── schedules/{YYYY-MM-DD}   (O(1) Single-Read Day Availability & Slot Locks)
 │    └── date, openTime, closeTime, slots.{HH:mm}: { status, bookingId, customerId, serviceId }
 ├── customers/{customerId}   (CRM & Per-Contact AI Rules)
 │    └── customerId, displayName, channel, activeBookingIds[], lastInteractionAt
 └── bookings/{bookingId}     (Appointment Lifecycle & Audit Trail)
      └── bookingId, workspaceId, customerId, customerName, serviceId, date,
          startTime, endTime, slotKey, status, rescheduleCount, previousSlots[]''',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
              if (daySchedule != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Live Document: ${daySchedule['documentPath'] ?? 'schedules/$_selectedScheduleDate'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3BFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141724),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    daySchedule.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRescheduleSheet(Map<String, dynamic> booking) {
    final bookingId = booking['bookingId'] as String? ?? '';
    final customerName = booking['customerName'] as String? ?? 'Customer';
    final currentDate = booking['date'] as String? ?? '';
    final currentTime = booking['time'] as String? ?? '14:00';

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dayAfter = DateTime.now().add(const Duration(days: 2));
    final in3Days = DateTime.now().add(const Duration(days: 3));
    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final dateOptions = <String>{
      if (currentDate.isNotEmpty) currentDate,
      fmtDate(tomorrow),
      fmtDate(dayAfter),
      fmtDate(in3Days),
    }.toList();

    String selectedDate = dateOptions.first;
    String selectedTime = _kStandardSlots.contains(currentTime)
        ? currentTime
        : _kStandardSlots[3];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reschedule #$bookingId ($customerName)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Current slot: $currentDate at $currentTime',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select New Date:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: dateOptions.map((d) {
                  final isSel = d == selectedDate;
                  return ChoiceChip(
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    selected: isSel,
                    selectedColor: const Color(0xFF7C3AED),
                    onSelected: (_) => setModalState(() => selectedDate = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select New Time Slot:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kStandardSlots.map((t) {
                  final isSel = t == selectedTime;
                  return ChoiceChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    selected: isSel,
                    selectedColor: const Color(
                      0xFF06D6A0,
                    ).withValues(alpha: 0.35),
                    onSelected: (_) => setModalState(() => selectedTime = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.update_rounded, size: 18),
                  label: Text(
                    'CONFIRM RESCHEDULE ($selectedDate · $selectedTime)',
                  ),
                  onPressed: () async {
                    final nav = Navigator.of(modalCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref
                        .read(dashboardNotifierProvider)
                        .rescheduleBooking(
                          bookingId: bookingId,
                          newDate: selectedDate,
                          newTime: selectedTime,
                        );
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Rescheduled #$bookingId to $selectedDate at $selectedTime'
                              : 'Failed to reschedule booking',
                        ),
                        backgroundColor: ok
                            ? const Color(0xFF06D6A0)
                            : Colors.redAccent,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider);
    final daySchedule = ref.watch(dayScheduleProvider);
    final confirmedCount = bookings
        .where((b) => b['status'] == 'CONFIRMED')
        .length;
    final rescheduledCount = bookings
        .where((b) => b['status'] == 'RESCHEDULED')
        .length;
    final cancelledCount = bookings
        .where((b) => b['status'] == 'CANCELLED')
        .length;

    final dateChoices = [
      _fmtDate(DateTime.now().add(const Duration(days: 1))),
      _fmtDate(DateTime.now().add(const Duration(days: 2))),
      _fmtDate(DateTime.now().add(const Duration(days: 3))),
    ];

    final Map<String, dynamic> slotsMap = (daySchedule?['slots'] is Map)
        ? Map<String, dynamic>.from(daySchedule!['slots'] as Map)
        : {};

    return Column(
      children: [
        // Summary Stats Bar + Schema Button
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statBadge('Confirmed', confirmedCount, const Color(0xFF06D6A0)),
              _statBadge(
                'Rescheduled',
                rescheduledCount,
                const Color(0xFF3BFFFF),
              ),
              _statBadge('Cancelled', cancelledCount, Colors.redAccent),
              TextButton.icon(
                onPressed: _showFirestoreSchemaModal,
                icon: const Icon(
                  Icons.schema_rounded,
                  size: 14,
                  color: Color(0xFF3BFFFF),
                ),
                label: const Text(
                  'DB SCHEMA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3BFFFF),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  backgroundColor: const Color(
                    0xFF3BFFFF,
                  ).withValues(alpha: 0.1),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                tooltip: 'Refresh Firestore bookings',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ref
                      .read(dashboardNotifierProvider)
                      .fetchBookings(seedIfEmpty: false);
                  ref
                      .read(dashboardNotifierProvider)
                      .fetchDaySchedule(_selectedScheduleDate);
                },
              ),
            ],
          ),
        ),
        // O(1) Day Schedule Grid (`workspaces/ws_default/schedules/{YYYY-MM-DD}`)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    size: 14,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'schedules/$_selectedScheduleDate',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  ...dateChoices.map((d) {
                    final isSel = d == _selectedScheduleDate;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedScheduleDate = d);
                          ref
                              .read(dashboardNotifierProvider)
                              .fetchDaySchedule(d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF7C3AED)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d.substring(5), // MM-DD
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _kStandardSlots.map((slot) {
                    final slotObj = slotsMap[slot] is Map
                        ? Map<String, dynamic>.from(slotsMap[slot] as Map)
                        : <String, dynamic>{};
                    final isBooked =
                        (slotObj['status'] as String? ?? 'AVAILABLE') ==
                        'BOOKED';
                    final cust = slotObj['customerName'] as String?;
                    final color = isBooked
                        ? Colors.orangeAccent
                        : const Color(0xFF06D6A0);
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$slot • ${isBooked ? "BOOKED" : "FREE"}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          if (isBooked && cust != null)
                            Text(
                              cust,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: bookings.isEmpty
              ? const Center(
                  child: Text(
                    'No bookings yet. Use the Simulate tab to book or reschedule appointments!',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    return _buildBookingCard(b);
                  },
                ),
        ),
      ],
    );
  }

  Widget _statBadge(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final bookingId = b['bookingId'] as String? ?? 'BK-0000';
    final customerId = b['customerId'] as String? ?? '';
    final customerName = b['customerName'] as String? ?? 'Customer';
    final serviceName = b['serviceName'] as String? ?? 'Consultation';
    final durationMins = b['durationMins'] as int? ?? 30;
    final price = b['price'] as int? ?? 40;
    final date = b['date'] as String? ?? '';
    final startTime = b['startTime'] as String? ?? (b['time'] as String? ?? '');
    final endTime = b['endTime'] as String? ?? '';
    final timeRange = endTime.isNotEmpty ? '$startTime – $endTime' : startTime;
    final rescheduleCount = b['rescheduleCount'] as int? ?? 0;
    final status = (b['status'] as String? ?? 'CONFIRMED').toUpperCase();
    final channel = (b['channel'] as String? ?? 'whatsapp').toLowerCase();
    final notes = b['notes'] as String? ?? '';

    final Color statusColor = switch (status) {
      'CONFIRMED' => const Color(0xFF06D6A0),
      'RESCHEDULED' => const Color(0xFF3BFFFF),
      'CANCELLED' => Colors.redAccent,
      _ => Colors.grey,
    };

    final Color channelColor = channel == 'teams'
        ? const Color(0xFF5B5FC7)
        : const Color(0xFF25D366);
    final bool isCancelled = status == 'CANCELLED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$status • #$bookingId',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: channelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  channel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: channelColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '\$$price (${durationMins}m)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$serviceName${customerId.isNotEmpty ? " • $customerId" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (rescheduleCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Rescheduled $rescheduleCount× ${notes.isNotEmpty ? "• $notes" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3BFFFF),
                        ),
                      ),
                    ] else if (notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        size: 14,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF06D6A0),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeRange,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06D6A0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (!isCancelled) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showRescheduleSheet(b),
                  icon: const Icon(
                    Icons.edit_calendar_rounded,
                    size: 15,
                    color: Color(0xFF3BFFFF),
                  ),
                  label: const Text(
                    'RESCHEDULE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3BFFFF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref
                        .read(dashboardNotifierProvider)
                        .cancelBooking(bookingId);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Cancelled booking #$bookingId'
                              : 'Failed to cancel',
                        ),
                        backgroundColor: ok ? Colors.orange : Colors.redAccent,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 15,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'CANCEL SLOT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
