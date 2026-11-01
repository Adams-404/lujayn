/// Predefined caller persona presets for incoming call simulation.
///
/// Keeps domain models pure and free of Flutter widget dependencies.
class CallerPersonaPreset {
  const CallerPersonaPreset({
    required this.id,
    required this.label,
    required this.defaultName,
    required this.defaultNumber,
  });

  final String id;
  final String label;
  final String defaultName;
  final String defaultNumber;

  static const List<CallerPersonaPreset> presets = [
    CallerPersonaPreset(
      id: 'family',
      label: 'Family / Mom',
      defaultName: 'Mom ❤️',
      defaultNumber: 'Mobile',
    ),
    CallerPersonaPreset(
      id: 'medical',
      label: 'Doctor / Clinic',
      defaultName: 'Dr. Collins',
      defaultNumber: 'Clinic',
    ),
    CallerPersonaPreset(
      id: 'work',
      label: 'Work',
      defaultName: 'Office',
      defaultNumber: 'Work',
    ),
    CallerPersonaPreset(
      id: 'friend',
      label: 'Friend',
      defaultName: 'Friend',
      defaultNumber: 'Mobile',
    ),
    CallerPersonaPreset(
      id: 'custom',
      label: 'Custom',
      defaultName: 'Personal Caller',
      defaultNumber: 'Incoming call',
    ),
  ];

  static CallerPersonaPreset? findById(String? id) {
    if (id == null) return null;
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
