import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_image_preset.dart';
import 'custom_preset_repository.dart';

class LocalCustomPresetRepository implements CustomPresetRepository {
  static const _prefsKey = 'custom_image_presets_v1';

  @override
  Future<List<CustomImagePreset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CustomImagePreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CustomImagePreset> add({
    required String name,
    required File sourceFile,
  }) async {
    final id = CustomImagePreset.generateId();
    final dir = await _dir();
    final ext = sourceFile.path.split('.').last.toLowerCase();
    final localPath = '${dir.path}/$id.$ext';

    // Copy into managed storage — sourceFile (temp) is left untouched.
    await sourceFile.copy(localPath);

    final preset = CustomImagePreset(id: id, name: name, localPath: localPath);
    final all = await loadAll();
    await _saveAll([...all, preset]);
    return preset;
  }

  @override
  Future<void> remove(String id) async {
    final all = await loadAll();
    final preset = all.where((p) => p.id == id).firstOrNull;
    if (preset == null) return;

    // Delete only the managed COPY. The original image is never touched.
    final file = File(preset.localPath);
    if (await file.exists()) await file.delete();

    await _saveAll(all.where((p) => p.id != id).toList());
  }

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/custom_presets');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _saveAll(List<CustomImagePreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }
}
