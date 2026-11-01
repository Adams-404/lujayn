import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/caller_persona.dart';

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

/// A calm, accessible surface allowing users to select or customize a caller persona
/// for an incoming reminder call simulation.
class CallerPersonaSelector extends StatefulWidget {
  const CallerPersonaSelector({
    super.key,
    required this.initialName,
    required this.initialNumber,
    required this.initialIcon,
    required this.onChanged,
  });

  final String? initialName;
  final String? initialNumber;
  final String? initialIcon;
  final void Function({
    String? callerName,
    String? callerNumber,
    String? callerIcon,
  })
  onChanged;

  @override
  State<CallerPersonaSelector> createState() => _CallerPersonaSelectorState();
}

class _CallerPersonaSelectorState extends State<CallerPersonaSelector> {
  late TextEditingController _nameController;
  late TextEditingController _numberController;
  String? _selectedIcon;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialName != null && widget.initialName!.isNotEmpty;
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _numberController = TextEditingController(text: widget.initialNumber ?? '');
    _selectedIcon = widget.initialIcon;
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
      _nameController.clear();
      _numberController.clear();
    });
    widget.onChanged(callerName: null, callerNumber: null, callerIcon: null);
  }

  void _notify() {
    if (!_enabled) {
      widget.onChanged(callerName: null, callerNumber: null, callerIcon: null);
      return;
    }
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();
    widget.onChanged(
      callerName: name.isEmpty ? null : name,
      callerNumber: number.isEmpty ? null : number,
      callerIcon: _selectedIcon ?? 'custom',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
