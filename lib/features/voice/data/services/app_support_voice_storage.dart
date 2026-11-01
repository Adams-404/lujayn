import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/services/voice_pack_installer.dart';

/// Stores voice packs in the app's private support directory.
///
/// Deliberately not the cache directory: Android may clear the cache whenever
/// it wants, and a 100 MB voice disappearing because the phone was low on space
/// would look like the app forgot a setting the user paid data for.
class AppSupportVoiceStorage implements VoiceStorage {
  @override
  Future<String> rootPath() async {
    final support = await getApplicationSupportDirectory();
    final voices = Directory(p.join(support.path, 'voices'));
    if (!await voices.exists()) {
      await voices.create(recursive: true);
    }
    return voices.path;
  }
}
