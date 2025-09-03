import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Semplice data model utente per l'autenticazione.
class User {
  final int? id;
  final String username;
  final String password; // Per prototipo: plain-text. Passeremo a hash.
  final String role; // 'boss' | 'employee'

  const User({this.id, required this.username, required this.password, required this.role});

  User copyWith({int? id, String? username, String? password, String? role}) => User(
        id: id ?? this.id,
        username: username ?? this.username,
        password: password ?? this.password,
        role: role ?? this.role,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'username': username,
        'password': password,
        'role': role,
      };

  static User fromMap(Map<String, Object?> map) => User(
        id: map['id'] as int?,
        username: map['username'] as String,
        password: map['password'] as String,
        role: map['role'] as String,
      );
}

/// Data Access Object per la tabella `users` su SQLite.
class AuthDao {
  AuthDao._internal();
  static final AuthDao instance = AuthDao._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final basePath = await getDatabasesPath();
    final fullPath = p.join(basePath, 'turni_auth.db');
    return openDatabase(
      fullPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('boss','employee'))
          );
        ''');
        // Seed iniziale
        await db.insert('users', const User(username: 'boss', password: 'admin', role: 'boss').toMap());
        await db.insert('users', const User(username: 'mario', password: '1234', role: 'employee').toMap());
        await db.insert('users', const User(username: 'anna', password: 'abcd', role: 'employee').toMap());
      },
    );
  }

  Future<User?> findByUsername(String username) async {
    final database = await db;
    final rows = await database.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> verifyLogin(String username, String password) async {
    final u = await findByUsername(username);
    if (u == null) return null;
    if (u.password != password) return null;
    return u;
  }

  Future<int> insertUser(User user) async {
    final database = await db;
    return database.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> upsertUser(User user) async {
    final database = await db;
    final existing = await findByUsername(user.username);
    if (existing == null) {
      return insertUser(user);
    } else {
      await database.update(
        'users',
        user.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
  }

  Future<int> deleteUserByUsername(String username) async {
    final database = await db;
    return database.delete(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [username.trim().toLowerCase()],
    );
  }

  Future<int> countUsers() async {
    final database = await db;
    final res = await database.rawQuery('SELECT COUNT(*) AS c FROM users');
    final c = Sqflite.firstIntValue(res) ?? 0;
    return c;
  }

  Future<void> resetAndSeed() async {
    final database = await db;
    await database.delete('users');
    await database.insert('users', const User(username: 'boss', password: 'admin', role: 'boss').toMap());
    await database.insert('users', const User(username: 'mario', password: '1234', role: 'employee').toMap());
    await database.insert('users', const User(username: 'anna', password: 'abcd', role: 'employee').toMap());
  }
}
