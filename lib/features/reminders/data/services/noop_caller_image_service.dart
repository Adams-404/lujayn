import '../../domain/services/caller_image_service.dart';

/// Test fallback and noop service for caller image handling.
class NoopCallerImageService implements CallerImageService {
  const NoopCallerImageService({this.stubImagePath});

  final String? stubImagePath;

  @override
  Future<String?> pickAndStoreImage() async => stubImagePath;

  @override
  Future<String> resolvePath(String fileNameOrPath) async => fileNameOrPath;

  @override
  Future<void> deleteImage(String fileNameOrPath) async {}

  @override
  Future<void> clearAllImages() async {}
}
