class Student {
  final int? id;
  final String name;
  final String? studentId;
  final String? halaqa;
  final String? photoPath;

  Student({
    this.id,
    required this.name,
    this.studentId,
    this.halaqa,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'student_id': studentId,
      'halaqa': halaqa,
      'photo_path': photoPath,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      name: map['name'],
      studentId: map['student_id'],
      halaqa: map['halaqa'],
      photoPath: map['photo_path'],
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? studentId,
    String? halaqa,
    String? photoPath,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      halaqa: halaqa ?? this.halaqa,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
