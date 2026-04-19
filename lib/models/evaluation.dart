class Evaluation {
  final int? id;
  final int studentId;
  final String memorization;
  final String recitation;
  final String commitment;
  final String? notes;

  Evaluation({
    this.id,
    required this.studentId,
    required this.memorization,
    required this.recitation,
    required this.commitment,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'memorization': memorization,
      'recitation': recitation,
      'commitment': commitment,
      'notes': notes,
    };
  }

  factory Evaluation.fromMap(Map<String, dynamic> map) {
    return Evaluation(
      id: map['id'],
      studentId: map['student_id'],
      memorization: map['memorization'],
      recitation: map['recitation'],
      commitment: map['commitment'],
      notes: map['notes'],
    );
  }

  Evaluation copyWith({
    int? id,
    int? studentId,
    String? memorization,
    String? recitation,
    String? commitment,
    String? notes,
  }) {
    return Evaluation(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      memorization: memorization ?? this.memorization,
      recitation: recitation ?? this.recitation,
      commitment: commitment ?? this.commitment,
      notes: notes ?? this.notes,
    );
  }
}
