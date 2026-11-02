import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/services/reminder_ringtone_service.dart';
import '../controllers/reminder_providers.dart';

/// Lets the user choose how a reminder call rings, and hear it first.
class RingtoneSettingsScreen extends ConsumerStatefulWidget {
  const RingtoneSettingsScreen({super.key});

  @override
  ConsumerState<RingtoneSettingsScreen> createState() =>
      _RingtoneSettingsScreenState();
}

class _RingtoneSettingsScreenState
    extends ConsumerState<RingtoneSettingsScreen> {
  ReminderRingtoneService? _service;
  bool _loading = true;
  bool _available = false;
  List<RingtoneOption> _options = const [];
  String? _selectedId;
  String? _previewingId;
  bool _previewing = false;
  String? _error;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _service = ref.read(reminderRingtoneServiceProvider);
    unawaited(_load());
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _service?.stopPreview();
    super.dispose();
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    try {
      final available = await service.isAvailable();
      final options = available
          ? await service.availableRingtones()
          : const <RingtoneOption>[];
      final selected = await service.selectedRingtoneId();
      if (!mounted) return;
      setState(() {
        _available = available;
        _options = options;
        _selectedId = selected;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Lujayn could not read this phone’s ringtones.';
      });
    }
  }

  Future<void> _select(String? id) async {
    HapticFeedback.selectionClick();
    await _service?.selectRingtone(id);
    if (!mounted) return;
    setState(() => _selectedId = id);
  }

  Future<void> _togglePreview(String? id) async {
    HapticFeedback.selectionClick();
    if (_previewing && _previewingId == id) {
      await _stopPreview();
      return;
    }
    _previewTimer?.cancel();
    await _service?.previewRingtone(id);
    if (!mounted) return;
    setState(() {
      _previewingId = id;
      _previewing = true;
    });
    // The native preview is short; this keeps the button honest even if the
    // platform never reports completion.
    _previewTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _previewing && _previewingId == id) {
        setState(() {
          _previewing = false;
          _previewingId = null;
        });
      }
    });
  }

  Future<void> _stopPreview() async {
    _previewTimer?.cancel();
    await _service?.stopPreview();
    if (mounted) {
      setState(() {
        _previewing = false;
        _previewingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder ringtone')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (!_available || _error != null)
          ? EmptyStateView(
              icon: Icons.ring_volume_outlined,
              title: 'Ringtones aren’t available',
              description:
                  _error ??
                  'This device does not let Lujayn choose a ringtone. '
                      'Reminders will still arrive with the phone’s normal '
                      'notification sound.',
              actionLabel: 'Try again',
              actionIcon: Icons.refresh_rounded,
              onAction: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                unawaited(_load());
              },
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'A reminder rings like a phone call until you answer, decline '
                  'or hang up. Choose the sound you will recognise.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _RingtoneRow(
                        title: 'Phone default',
                        subtitle:
                            'Use the ringtone selected in Android settings',
                        selected: _selectedId == null,
                        previewing: _previewing && _previewingId == null,
                        onSelect: () => _select(null),
                        onPreview: () => _togglePreview(null),
                      ),
                      for (final option in _options) ...[
                        const Divider(height: 1),
                        _RingtoneRow(
                          title: option.title,
                          subtitle: option.isDefault
                              ? 'Current Android default'
                              : null,
                          selected: _selectedId == option.id,
                          previewing: _previewing && _previewingId == option.id,
                          onSelect: () => _select(option.id),
                          onPreview: () => _togglePreview(option.id),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Android may silence Lujayn in Do Not Disturb, silent mode, '
                  'or when a manufacturer restricts background sound. Lujayn '
                  'cannot override those settings.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}

class _RingtoneRow extends StatelessWidget {
  const _RingtoneRow({
    required this.title,
    required this.selected,
    required this.previewing,
    required this.onSelect,
    required this.onPreview,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool previewing;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onSelect,
      selected: selected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.35),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? colors.primary : colors.outline,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: IconButton(
        onPressed: onPreview,
        tooltip: previewing ? 'Stop preview' : 'Preview $title',
        icon: Icon(
          previewing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
        ),
      ),
    );
  }
}
