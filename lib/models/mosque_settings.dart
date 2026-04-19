class MosqueSettings {
  final int? id;
  final String name;
  final String logoPath;

  MosqueSettings({
    this.id,
    required this.name,
    required this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logo_path': logoPath,
    };
  }

  factory MosqueSettings.fromMap(Map<String, dynamic> map) {
    return MosqueSettings(
      id: map['id'],
      name: map['name'],
      logoPath: map['logo_path'],
    );
  }
}
