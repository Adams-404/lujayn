import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/reminders/domain/services/reminder_call_bridge.dart';
import '../features/reminders/presentation/controllers/reminder_providers.dart';
import '../features/reminders/presentation/screens/reminder_call_screen.dart';
import '../features/settings/presentation/controllers/settings_providers.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_choice.dart';

/// The root application widget for Lujayn.
///
/// It also presents the call-style reminder surface when an alarm opens or
/// wakes the app. Android decides whether that arrives as a full-screen intent
/// or a notification tap, so both paths are handled the same way.
class LujaynApp extends ConsumerStatefulWidget {
  const LujaynApp({super.key});

  @override
  ConsumerState<LujaynApp> createState() => _LujaynAppState();
}

class _LujaynAppState extends ConsumerState<LujaynApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<ReminderCallRequest>? _callSubscription;
  String? _visibleReminderId;
  int _pendingRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final bridge = ref.read(reminderCallBridgeProvider);
    _callSubscription = bridge.requests.listen(_presentReminderCall);
    unawaited(_presentLaunchReminderCall(bridge));
    unawaited(_dismissDeclinedReminders(bridge));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _dismissDeclinedReminders(ref.read(reminderCallBridgeProvider)),
      );
    }
  }

  /// A decline tapped on the call notification happens outside Flutter. The
  /// native side records it, and the app applies it the next time it is alive
  /// so a declined reminder is not still waiting in the list.
  Future<void> _dismissDeclinedReminders(ReminderCallBridge bridge) async {
    try {
      final ids = await bridge.takeDeclinedReminderIds();
      if (ids.isEmpty || !mounted) return;
      final actions = ref.read(reminderActionControllerProvider);
      for (final id in ids) {
        await actions.dismissOccurrence(id);
      }
    } on Object {
      // Reconcile is best-effort; it must never stop the app from opening.
    }
  }

  Future<void> _presentLaunchReminderCall(ReminderCallBridge bridge) async {
    final request = await bridge.takeLaunchRequest();
    if (request != null) _presentReminderCall(request);
  }

  void _presentReminderCall(ReminderCallRequest request) {
    if (!mounted) return;
    if (_visibleReminderId == request.reminderId) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      // A launch request arrives before the first frame has built the
      // navigator. Retry after that frame instead of dropping the alert.
      if (_pendingRetries >= 3) return;
      _pendingRetries++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentReminderCall(request);
      });
      return;
    }
    _pendingRetries = 0;

    _visibleReminderId = request.reminderId;
    navigator
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ReminderCallScreen(reminderId: request.reminderId),
          ),
        )
        .whenComplete(() => _visibleReminderId = null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTheme =
        ref.watch(themeChoiceProvider).asData?.value ?? AppThemeChoice.system;
    final followsSystem = selectedTheme == AppThemeChoice.system;

    return MaterialApp(
      title: 'Lujayn',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: followsSystem
          ? AppTheme.forChoice(AppThemeChoice.silver)
          : AppTheme.forChoice(selectedTheme),
      darkTheme: followsSystem
          ? AppTheme.forChoice(AppThemeChoice.dusk)
          : AppTheme.forChoice(selectedTheme),
      themeMode: followsSystem ? ThemeMode.system : ThemeMode.light,
      home: const AppShell(),
    );
  }
}
