import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/caller_persona.dart';
import '../controllers/reminder_providers.dart';

/// Maps persona icon identifiers to Material icons.
IconData iconForCallerIcon(String? iconId) {
  switch (iconId) {
    case 'family':
      return Icons.favorite_rounded;
    case 'medical':
      return Icons.medical_services_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'friend':
      return Icons.sentiment_satisfied_alt_rounded;
    case 'custom':
      return Icons.person_rounded;
    default:
      return Icons.call_rounded;
  }
}

/// A calm, accessible surface allowing users to select or customize a caller persona,
/// including custom name, number/label, and on-device profile photo.
class CallerPersonaSelector extends ConsumerStatefulWidget {
  const CallerPersonaSelector({
    super.key,
    required this.initialName,
    required this.initialNumber,
    required this.initialIcon,
    this.initialImagePath,
    required this.onChanged,
  });

  final String? initialName;
  final String? initialNumber;
  final String? initialIcon;
  final String? initialImagePath;
  final void Function({
    String? callerName,
    String? callerNumber,
    String? callerIcon,
    String? callerImagePath,
  })
  onChanged;

  @override
  ConsumerState<CallerPersonaSelector> createState() =>
      _CallerPersonaSelectorState();
}

class _CallerPersonaSelectorState extends ConsumerState<CallerPersonaSelector> {
  late TextEditingController _nameController;
  late TextEditingController _numberController;
  String? _selectedIcon;
  String? _imagePath;
  String? _resolvedImagePath;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _enabled =
        (widget.initialName != null && widget.initialName!.isNotEmpty) ||
        (widget.initialImagePath != null &&
            widget.initialImagePath!.isNotEmpty);
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _numberController = TextEditingController(text: widget.initialNumber ?? '');
    _selectedIcon = widget.initialIcon;
    _imagePath = widget.initialImagePath;
    if (_imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _resolveInitialImage(),
      );
    }
  }

  Future<void> _resolveInitialImage() async {
    if (_imagePath == null) return;
    final imageService = ref.read(callerImageServiceProvider);
    final resolved = await imageService.resolvePath(_imagePath!);
    if (mounted) {
      setState(() => _resolvedImagePath = resolved);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  void _applyPreset(CallerPersonaPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _enabled = true;
      _selectedIcon = preset.id;
      _nameController.text = preset.defaultName;
      _numberController.text = preset.defaultNumber;
    });
    _notify();
  }

  void _clearPersona() {
    HapticFeedback.selectionClick();
    setState(() {
      _enabled = false;
      _selectedIcon = null;
      _imagePath = null;
      _resolvedImagePath = null;
      _nameController.clear();
      _numberController.clear();
    });
    widget.onChanged(
      callerName: null,
      callerNumber: null,
      callerIcon: null,
      callerImagePath: null,
    );
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final imageService = ref.read(callerImageServiceProvider);
    final storedName = await imageService.pickAndStoreImage();
    if (storedName == null || !mounted) return;

    final resolved = await imageService.resolvePath(storedName);
    if (!mounted) return;

    setState(() {
      _imagePath = storedName;
      _resolvedImagePath = resolved;
    });
    _notify();
  }

  void _removeImage() {
    HapticFeedback.selectionClick();
    setState(() {
      _imagePath = null;
      _resolvedImagePath = null;
    });
    _notify();
  }

  void _notify() {
    if (!_enabled) {
      widget.onChanged(
        callerName: null,
        callerNumber: null,
        callerIcon: null,
        callerImagePath: null,
      );
      return;
    }
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();
    widget.onChanged(
      callerName: name.isEmpty ? null : name,
      callerNumber: number.isEmpty ? null : number,
      callerIcon: _selectedIcon ?? 'custom',
      callerImagePath: _imagePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final file = _resolvedImagePath != null ? File(_resolvedImagePath!) : null;
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    final canDisplayFile = file != null && file.existsSync();

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.surface),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _enabled
                      ? iconForCallerIcon(_selectedIcon)
                      : Icons.perm_identity_rounded,
                  color: _enabled ? colors.primary : colors.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simulated Caller',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _enabled
                            ? 'Simulates a phone call from ${_nameController.text.isEmpty ? "this person" : _nameController.text}'
                            : 'Default call-style screen using reminder title',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_enabled)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Remove caller persona',
                    onPressed: _clearPersona,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: !_enabled,
                  onSelected: (selected) {
                    if (selected) _clearPersona();
                  },
                ),
                ...CallerPersonaPreset.presets.map((preset) {
                  final isSelected = _enabled && _selectedIcon == preset.id;
                  return ChoiceChip(
                    avatar: Icon(
                      iconForCallerIcon(preset.id),
                      size: 16,
                      color: isSelected
                          ? colors.onSecondaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _applyPreset(preset);
                      }
                    },
                  );
                }),
              ],
            ),
            if (_enabled) ...[
              const SizedBox(height: AppSpacing.md),
              // Profile Photo Affordance
              Row(
                children: [
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          backgroundImage: canDisplayFile
                              ? FileImage(file)
                              : null,
                          child: !canDisplayFile
                              ? Icon(iconForCallerIcon(_selectedIcon), size: 28)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasImage ? 'Profile photo added' : 'Caller photo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shows during incoming and active calls.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 14,
                              ),
                              label: Text(
                                hasImage ? 'Change photo' : 'Choose photo',
                              ),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ),
                            if (hasImage) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _removeImage,
                                child: Text(
                                  'Remove',
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Caller Name',
                  hintText: 'e.g. Mom ❤️, Dr. Adams, Coach',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                onChanged: (_) => _notify(),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _numberController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Label or Phone Number',
                  hintText: 'e.g. Mobile, (555) 234-5678, Clinic',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                onChanged: (_) => _notify(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
