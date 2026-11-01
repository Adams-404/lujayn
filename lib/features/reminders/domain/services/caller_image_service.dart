/// Domain abstraction for managing caller profile photos on-device.
///
/// Keeps presentation and domain layers independent of platform image pickers
/// and local storage paths.
abstract interface class CallerImageService {
  /// Prompts the user to select an image from the local gallery, copies it to
  /// safe app-private storage, and returns the stored relative file name.
  ///
  /// Returns null if the user cancels or an error occurs.
  Future<String?> pickAndStoreImage();

  /// Resolves a stored relative image name or path to an absolute filesystem path.
  Future<String> resolvePath(String fileNameOrPath);

  /// Deletes a caller profile image from disk.
  Future<void> deleteImage(String fileNameOrPath);

  /// Clears all stored caller profile images.
  Future<void> clearAllImages();
}
