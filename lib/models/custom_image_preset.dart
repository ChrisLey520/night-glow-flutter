import 'dart:math';

class CustomImagePreset {
  final String id;
  final String name;
  // Path to the LOCAL COPY in app documents — never the original source file.
  final String localPath;

  const CustomImagePreset({
    required this.id,
    required this.name,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localPath': localPath,
      };

  factory CustomImagePreset.fromJson(Map<String, dynamic> json) =>
      CustomImagePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        localPath: json['localPath'] as String,
      );

  static String generateId() {
    final rng = Random.secure();
    final b = List.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(List<int> s) =>
        s.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(b.sublist(0, 4))}-${hex(b.sublist(4, 6))}'
        '-${hex(b.sublist(6, 8))}-${hex(b.sublist(8, 10))}'
        '-${hex(b.sublist(10, 16))}';
  }
}
