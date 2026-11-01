/// User-selectable appearance for the whole app.
enum AppThemeChoice { system, silver, paper, sage, dusk, amoled }

extension AppThemeChoiceLabel on AppThemeChoice {
  String get label => switch (this) {
    AppThemeChoice.system => 'Use device setting',
    AppThemeChoice.silver => 'Silver',
    AppThemeChoice.paper => 'Paper',
    AppThemeChoice.sage => 'Sage',
    AppThemeChoice.dusk => 'Dusk',
    AppThemeChoice.amoled => 'AMOLED',
  };

  String get description => switch (this) {
    AppThemeChoice.system => 'Silver by day, Dusk at night',
    AppThemeChoice.silver => 'Lujayn’s signature cool, mineral light palette',
    AppThemeChoice.paper => 'Warm ivory and soft ink',
    AppThemeChoice.sage => 'Quiet greens and natural neutrals',
    AppThemeChoice.dusk => 'Deep charcoal with soft silver accents',
    AppThemeChoice.amoled => 'True black surfaces for OLED displays',
  };

  bool get isDark =>
      this == AppThemeChoice.dusk || this == AppThemeChoice.amoled;
}
