import 'package:flutter/foundation.dart';

enum UserRole { employee, boss }

class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  UserRole? _role;
  String? _employeeName;

  UserRole? get role => _role;
  String? get employeeName => _employeeName;
  bool get isLoggedIn => _role != null;
  bool get isEmployee => _role == UserRole.employee;
  bool get isBoss => _role == UserRole.boss;

  void loginEmployee(String name) {
    _role = UserRole.employee;
    _employeeName = name.trim();
    notifyListeners();
  }

  void loginBoss() {
    _role = UserRole.boss;
    _employeeName = null;
    notifyListeners();
  }

  void logout() {
    _role = null;
    _employeeName = null;
    notifyListeners();
  }
}