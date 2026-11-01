import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/caller_image_service.dart';

/// App-private storage and picking service for caller profile photos.
///
/// Images are copied into `<app support>/caller_images/` so the OS cache
/// cleaner never purges them unexpectedly.
class AppSupportCallerImageService implements CallerImageService {
  AppSupportCallerImageService({
    Future<Directory> Function()? baseDirectoryResolver,
    ImagePicker? imagePicker,
  }) : _baseDirectoryResolver =
           baseDirectoryResolver ?? getApplicationSupportDirectory,
       _imagePicker = imagePicker ?? ImagePicker();

  final Future<Directory> Function() _baseDirectoryResolver;
  final ImagePicker _imagePicker;
  static const _uuid = Uuid();

  Future<String> getImagesDirectory() async {
    final base = await _baseDirectoryResolver();
    final dir = Directory(p.join(base.path, 'caller_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<String?> pickAndStoreImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final dir = await getImagesDirectory();
      final ext = p.extension(picked.path).isNotEmpty
          ? p.extension(picked.path)
          : '.jpg';
      final fileName = 'caller_${_uuid.v4()}$ext';
      final destinationPath = p.join(dir, fileName);
      await File(picked.path).copy(destinationPath);
      return fileName;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> resolvePath(String fileNameOrPath) async {
    if (p.isAbsolute(fileNameOrPath)) return fileNameOrPath;
    final dir = await getImagesDirectory();
    return p.join(dir, p.basename(fileNameOrPath));
  }

  @override
  Future<void> deleteImage(String fileNameOrPath) async {
    try {
      final fullPath = await resolvePath(fileNameOrPath);
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort deletion
    }
  }

  @override
  Future<void> clearAllImages() async {
    try {
      final dirPath = await getImagesDirectory();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort
    }
  }
}
