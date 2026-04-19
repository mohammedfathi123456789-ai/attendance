class Teacher {
  final int? id;
  final String name;
  final String? halaqa;
  final String? teacherId;

  Teacher({
    this.id,
    required this.name,
    this.halaqa,
    this.teacherId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'halaqa': halaqa,
      'teacher_id': teacherId,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'],
      name: map['name'],
      halaqa: map['halaqa'],
      teacherId: map['teacher_id'],
    );
  }

  Teacher copyWith({
    int? id,
    String? name,
    String? halaqa,
    String? teacherId,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      halaqa: halaqa ?? this.halaqa,
      teacherId: teacherId ?? this.teacherId,
    );
  }
}
