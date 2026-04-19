import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/mosque_settings.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/attendance.dart';
import '../models/evaluation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static String _dbName = 'app_database.db';

  static void setDatabaseName(String username) {
    final newName = 'app_database_$username.db';
    if (_dbName != newName) {
      _database?.close();
      _database = null;
      _dbName = newName;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE teachers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          person_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE students ADD COLUMN student_id TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN halaqa TEXT');
      await db.execute('ALTER TABLE students ADD COLUMN photo_path TEXT');
      
      // Auto-assign unique ID starting from A100 for existing students
      final students = await db.query('students');
      for (var s in students) {
        final id = s['id'] as int;
        final generatedId = 'A${100 + id}';
        await db.update('students', {'student_id': generatedId}, where: 'id = ?', whereArgs: [id]);
      }
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE teachers ADD COLUMN halaqa TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE teachers ADD COLUMN teacher_id TEXT');
      final teachers = await db.query('teachers');
      for (var t in teachers) {
        final id = t['id'] as int;
        final generatedId = 'T${199 + id}';
        await db.update('teachers', {'teacher_id': generatedId}, where: 'id = ?', whereArgs: [id]);
      }
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE evaluations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          memorization TEXT NOT NULL,
          recitation TEXT NOT NULL,
          commitment TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        logo_path TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        student_id TEXT,
        halaqa TEXT,
        photo_path TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        halaqa TEXT,
        teacher_id TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE evaluations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        memorization TEXT NOT NULL,
        recitation TEXT NOT NULL,
        commitment TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<MosqueSettings> saveSettings(MosqueSettings settings) async {
    final db = await instance.database;
    await db.delete('settings');
    final id = await db.insert('settings', settings.toMap());
    return MosqueSettings(id: id, name: settings.name, logoPath: settings.logoPath);
  }

  Future<MosqueSettings?> getSettings() async {
    final db = await instance.database;
    final maps = await db.query('settings');

    if (maps.isNotEmpty) {
      return MosqueSettings.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // --- Students CRUD ---

  Future<Student> createStudent(Student student) async {
    final db = await instance.database;
    final map = student.toMap();
    final bool needsAutoId = map['student_id'] == null || (map['student_id'] as String).isEmpty;
    
    final id = await db.insert('students', map);
    
    String? finalStudentId = map['student_id'];
    if (needsAutoId) {
      finalStudentId = 'A${99 + id}';
      await db.update('students', {'student_id': finalStudentId}, where: 'id = ?', whereArgs: [id]);
    }
    
    return student.copyWith(id: id, studentId: finalStudentId);
  }

  Future<List<Student>> readAllStudents() async {
    final db = await instance.database;
    final orderBy = 'name ASC';
    final result = await db.query('students', orderBy: orderBy);

    return result.map((json) => Student.fromMap(json)).toList();
  }

  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Teachers CRUD ---

  Future<Teacher> createTeacher(Teacher teacher) async {
    final db = await instance.database;
    final map = teacher.toMap();
    final bool needsAutoId = map['teacher_id'] == null || (map['teacher_id'] as String).isEmpty;

    final id = await db.insert('teachers', map);

    String? finalTeacherId = map['teacher_id'];
    if (needsAutoId) {
      finalTeacherId = 'T${199 + id}';
      await db.update('teachers', {'teacher_id': finalTeacherId}, where: 'id = ?', whereArgs: [id]);
    }

    return teacher.copyWith(id: id, teacherId: finalTeacherId);
  }

  Future<List<Teacher>> readAllTeachers() async {
    final db = await instance.database;
    final orderBy = 'name ASC';
    final result = await db.query('teachers', orderBy: orderBy);

    return result.map((json) => Teacher.fromMap(json)).toList();
  }

  Future<int> updateTeacher(Teacher teacher) async {
    final db = await instance.database;
    return db.update(
      'teachers',
      teacher.toMap(),
      where: 'id = ?',
      whereArgs: [teacher.id],
    );
  }

  Future<int> deleteTeacher(int id) async {
    final db = await instance.database;
    return await db.delete(
      'teachers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Attendance CRUD ---

  Future<Attendance> createAttendance(Attendance attendance) async {
    final db = await instance.database;
    final id = await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return attendance.copyWith(id: id);
  }

  Future<List<Attendance>> readAttendanceByDateAndType(String date, String type) async {
    final db = await instance.database;
    final result = await db.query(
      'attendance',
      where: 'date = ? AND type = ?',
      whereArgs: [date, type],
    );

    return result.map((json) => Attendance.fromMap(json)).toList();
  }

  Future<List<Attendance>> readAttendanceByDate(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );

    return result.map((json) => Attendance.fromMap(json)).toList();
  }

  Future<List<Attendance>> readAttendanceByDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    final result = await db.query(
      'attendance',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );

    return result.map((json) => Attendance.fromMap(json)).toList();
  }

  Future<void> saveDailyAttendance(List<Attendance> attendances) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (var record in attendances) {
        // Delete existing record for this person, type and date
        await txn.delete(
          'attendance',
          where: 'person_id = ? AND type = ? AND date = ?',
          whereArgs: [record.personId, record.type, record.date],
        );
        // Insert new record
        await txn.insert('attendance', record.toMap());
      }
    });
  }

  Future<int> updateAttendance(Attendance attendance) async {
    final db = await instance.database;
    return db.update(
      'attendance',
      attendance.toMap(),
      where: 'id = ?',
      whereArgs: [attendance.id],
    );
  }

  Future<int> deleteAttendance(int id) async {
    final db = await instance.database;
    return await db.delete(
      'attendance',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Evaluations CRUD ---
  
  Future<Evaluation> saveEvaluation(Evaluation evaluation) async {
    final db = await instance.database;
    // Check if evaluation for student already exists
    final existing = await db.query('evaluations', where: 'student_id = ?', whereArgs: [evaluation.studentId]);
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update('evaluations', evaluation.toMap(), where: 'id = ?', whereArgs: [existingId]);
      return evaluation.copyWith(id: existingId);
    } else {
      final id = await db.insert('evaluations', evaluation.toMap());
      return evaluation.copyWith(id: id);
    }
  }

  Future<Evaluation?> getEvaluationByStudent(int studentId) async {
    final db = await instance.database;
    final result = await db.query('evaluations', where: 'student_id = ?', whereArgs: [studentId]);
    if (result.isNotEmpty) {
      return Evaluation.fromMap(result.first);
    }
    return null;
  }
}
