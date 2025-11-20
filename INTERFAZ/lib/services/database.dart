import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/session.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sessions.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,   // 🔥 Incrementar versión para aplicar migración
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ---------------------------------------------------------------
  // CREAR LA TABLA COMPLETA (se usa la primera vez)
  // ---------------------------------------------------------------
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        duration INTEGER,
        avgHR INTEGER,
        focusLevel REAL,
        focusTimelineJson TEXT   -- 🔥 columna agregada
      )
    ''');
  }

  // ---------------------------------------------------------------
  // MIGRAR BASE DE DATOS (cuando ya existía tabla anterior)
  // ---------------------------------------------------------------
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE sessions ADD COLUMN focusTimelineJson TEXT;
      ''');
    }
  }

  // ---------------------------------------------------------------
  // INSERTAR SESIÓN
  // ---------------------------------------------------------------
  Future<int> insertSession(SessionModel session) async {
    final db = await instance.database;
    return await db.insert('sessions', session.toMap());
  }

  // ---------------------------------------------------------------
  // OBTENER TODAS LAS SESIONES
  // ---------------------------------------------------------------
  Future<List<SessionModel>> getSessions() async {
    final db = await instance.database;
    final result = await db.query('sessions');
    return result.map((map) => SessionModel.fromMap(map)).toList();
  }

  // ---------------------------------------------------------------
  // BORRAR SESIÓN
  // ---------------------------------------------------------------
  Future<int> deleteSession(int id) async {
    final db = await instance.database;
    return await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }
}
