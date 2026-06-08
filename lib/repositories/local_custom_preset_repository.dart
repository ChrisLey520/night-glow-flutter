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
    final dir = await _dir();
    final list = jsonDecode(raw) as List<dynamic>;

    bool needsMigration = false;
    final presets = list.map((e) {
      final map = e as Map<String, dynamic>;
      String stored = map['localPath'] as String;

      // Migrate old absolute paths → filename-only.
      // Absolute paths break across app reinstalls because the
      // app container UUID changes, making the path stale.
      if (stored.contains('/')) {
        stored = stored.split('/').last;
        needsMigration = true;
      }

      return CustomImagePreset(
        id: map['id'] as String,
        name: map['name'] as String,
        localPath: '${dir.path}/$stored',
      );
    }).toList();

    if (needsMigration) {
      // Persist filename-only form so the migration runs only once.
      await _saveAll(presets, dir: dir);
    }

    return presets;
  }

  @override
  Future<CustomImagePreset> add({
    required String name,
    required File sourceFile,
  }) async {
    final id = CustomImagePreset.generateId();
    final dir = await _dir();
    final ext = sourceFile.path.split('.').last.toLowerCase();
    final filename = '$id.$ext';
    final localPath = '${dir.path}/$filename';

    await sourceFile.copy(localPath);

    final preset = CustomImagePreset(id: id, name: name, localPath: localPath);
    final all = await loadAll();
    await _saveAll([...all, preset], dir: dir);
    return preset;
  }

  @override
  Future<void> remove(String id) async {
    final all = await loadAll();
    final preset = all.where((p) => p.id == id).firstOrNull;
    if (preset == null) return;

    final file = File(preset.localPath);
    if (await file.exists()) await file.delete();

    final dir = await _dir();
    await _saveAll(all.where((p) => p.id != id).toList(), dir: dir);
  }

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/custom_presets');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Saves presets storing only the filename (not the full absolute path).
  Future<void> _saveAll(List<CustomImagePreset> presets,
      {required Directory dir}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = presets.map((p) {
      final filename = p.localPath.split('/').last;
      return {'id': p.id, 'name': p.name, 'localPath': filename};
    }).toList();
    await prefs.setString(_prefsKey, jsonEncode(json));
  }
}
