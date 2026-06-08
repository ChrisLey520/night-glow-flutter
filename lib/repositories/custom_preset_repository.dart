import 'dart:io';
import '../models/custom_image_preset.dart';

/// Abstract repository for custom image presets.
/// Swap [LocalCustomPresetRepository] for a remote implementation
/// when backend storage is needed.
abstract class CustomPresetRepository {
  Future<List<CustomImagePreset>> loadAll();

  /// Copies [sourceFile] into managed storage, persists metadata, returns preset.
  /// The [sourceFile] (e.g. from image_picker temp dir) is NEVER deleted.
  Future<CustomImagePreset> add({
    required String name,
    required File sourceFile,
  });

  /// Deletes the local copy and removes metadata.
  /// The original file the user picked is NEVER touched.
  Future<void> remove(String id);
}
