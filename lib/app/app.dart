import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/presentation/controllers/settings_providers.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_choice.dart';

/// The root application widget for Lujayn.
class LujaynApp extends ConsumerWidget {
  const LujaynApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme =
        ref.watch(themeChoiceProvider).asData?.value ?? AppThemeChoice.system;
    final followsSystem = selectedTheme == AppThemeChoice.system;

    return MaterialApp(
      title: 'Lujayn',
      debugShowCheckedModeBanner: false,
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
