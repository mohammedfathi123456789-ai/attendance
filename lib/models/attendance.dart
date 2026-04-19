class Attendance {
  final int? id;
  final int personId;
  final String type; // 'student' or 'teacher'
  final String date; // Format: YYYY-MM-DD
  final String status; // 'present', 'absent', 'excused'

  Attendance({
    this.id,
    required this.personId,
    required this.type,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'type': type,
      'date': date,
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      personId: map['person_id'],
      type: map['type'],
      date: map['date'],
      status: map['status'],
    );
  }

  Attendance copyWith({
    int? id,
    int? personId,
    String? type,
    String? date,
    String? status,
  }) {
    return Attendance(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }
}
